package com.example.happy_flutter

import io.sentry.SentryEvent
import io.sentry.SentryLevel
import io.sentry.protocol.Breadcrumb
import io.sentry.protocol.DebugMeta
import io.sentry.protocol.SdkVersion
import io.sentry.protocol.SentryException
import io.sentry.protocol.SentryStackTrace
import io.sentry.protocol.SentryStackFrame
import io.sentry.protocol.SentryThread
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Contract tests for [AnrBodyShrinker].
 *
 * Goal: pin the exact shrink rules so future changes to the shrinker don't
 * silently re-introduce a payload that exceeds GlitchTip's 5 MiB intake limit.
 */
class AnrBodyShrinkerTest {

    @Test
    fun `ANR event is detected by ApplicationNotResponding exception type`() {
        val event = sentryEvent(anrException())
        assertTrue(AnrBodyShrinker.isAnrEvent(event))
    }

    @Test
    fun `non-ANR event with regular exception is not detected`() {
        val regularException = SentryException().apply { type = "NullPointerException" }
        val event = sentryEvent(regularException)
        assertFalse(AnrBodyShrinker.isAnrEvent(event))
    }

    @Test
    fun `event with no exceptions is not detected as ANR`() {
        val event = SentryEvent()
        assertFalse(AnrBodyShrinker.isAnrEvent(event))
    }

    @Test
    fun `shrinking an ANR event strips breadcrumbs, thread and exception stacktraces, debugMeta and sdk`() {
        val event = sentryEvent(
            anrException().apply { stacktrace = bigStacktrace() },
        ).apply {
            breadcrumbs = listOf(
                Breadcrumb().apply { message = "tap"; category = "ui" },
                Breadcrumb().apply { message = "fetch"; category = "http" },
            )
            threads = listOf(
                SentryThread().apply {
                    id = 1L
                    name = "main"
                    isMain = true
                    stacktrace = bigStacktrace()
                },
                SentryThread().apply {
                    id = 2L
                    name = "DefaultDispatcher-worker-1"
                    stacktrace = bigStacktrace()
                },
            )
            debugMeta = DebugMeta()
            sdk = SdkVersion().apply {
                name = "sentry.java.android.flutter"
                version = "8.41.0"
            }
        }

        val shrunk = AnrBodyShrinker.shrinkIfAnr(event)
        assertTrue(shrunk)

        // 1. Breadcrumbs stripped.
        assertNull(event.breadcrumbs)

        // 2. Thread stacktraces stripped, thread metadata preserved.
        val threads = event.threads
        assertNotNull(threads)
        assertEquals(2, threads!!.size)
        for (thread in threads) {
            assertNull(thread.stacktrace)
        }
        // Thread metadata that we use for triage stays intact.
        val main = threads[0]
        assertEquals("main", main.name)
        assertEquals(java.lang.Boolean.TRUE, main.isMain)
        assertEquals(1L, main.id)

        // 3. Exception stacktrace stripped, ANR marker stays.
        val exceptions = event.exceptions
        assertNotNull(exceptions)
        assertEquals(1, exceptions!!.size)
        assertEquals("ApplicationNotResponding", exceptions[0].type)
        assertNull(exceptions[0].stacktrace)

        // 4. DebugMeta stripped.
        assertNull(event.debugMeta)

        // 5. SDK metadata stripped.
        assertNull(event.sdk)
    }

    @Test
    fun `shrinking a non-ANR event leaves it untouched`() {
        val regular = SentryException().apply {
            type = "NullPointerException"
            stacktrace = bigStacktrace()
            value = "boom"
        }
        val event = sentryEvent(regular).apply {
            breadcrumbs = listOf(Breadcrumb().apply { message = "keep me" })
            threads = listOf(SentryThread().apply { id = 9L; name = "io-1"; stacktrace = bigStacktrace() })
            debugMeta = DebugMeta()
            sdk = SdkVersion().apply { name = "sentry.java.android.flutter" }
        }

        val shrunk = AnrBodyShrinker.shrinkIfAnr(event)
        assertFalse(shrunk)

        // Nothing should be touched.
        assertNotNull(event.breadcrumbs)
        assertEquals(1, event.breadcrumbs!!.size)
        assertNotNull(event.threads!![0].stacktrace)
        assertNotNull(event.exceptions!![0].stacktrace)
        assertNotNull(event.debugMeta)
        assertNotNull(event.sdk)
    }

    @Test
    fun `ANR with multiple exceptions strips all exception stacktraces`() {
        val event = SentryEvent().apply { level = SentryLevel.WARNING }
        event.exceptions = listOf(
            anrException().apply { stacktrace = bigStacktrace() },
            SentryException().apply {
                type = "RuntimeException"
                value = "wrapped"
                stacktrace = bigStacktrace()
            },
        )

        val shrunk = AnrBodyShrinker.shrinkIfAnr(event)
        assertTrue(shrunk)

        for (ex in event.exceptions!!) {
            assertNull(ex.stacktrace)
        }
    }

    @Test
    fun `null event is a no-op`() {
        assertFalse(AnrBodyShrinker.shrinkIfAnr(null))
    }

    // ── helpers ─────────────────────────────────────────────────────────

    private fun sentryEvent(vararg exceptions: SentryException): SentryEvent {
        val event = SentryEvent().apply { level = SentryLevel.WARNING }
        if (exceptions.isNotEmpty()) {
            event.exceptions = exceptions.toList()
        }
        return event
    }

    private fun anrException(): SentryException = SentryException().apply {
        type = "ApplicationNotResponding"
        value = "ANR detected on main thread"
        threadId = 1L
    }

    /**
     * Build a non-trivial stacktrace so the shrink decision is observable. 32
     * frames × 5 strings × ~80 chars ≈ 12 KiB — typical of a hot Android frame.
     */
    private fun bigStacktrace(): SentryStackTrace {
        val frames = (0 until 32).map { index ->
            SentryStackFrame().apply {
                module = "com.example.happy_flutter.SomeClass$index"
                function = "doWork$index"
                fileName = "SomeClass.kt"
                lineno = 100 + index
            }
        }
        return SentryStackTrace(frames)
    }
}
