package com.example.happy_flutter

import io.sentry.SentryEvent
import io.sentry.SentryOptions
import io.sentry.protocol.SentryException
import io.sentry.protocol.SentryThread
import java.util.concurrent.atomic.AtomicLong

/**
 * Installs a Sentry `beforeSend` that strips the payload from ANR-shaped events
 * so the serialized envelope stays under GlitchTip's 5 MiB decompressed intake
 * limit. Real devices produce 5+ MiB ANR envelopes because the Android SDK
 * captures the full thread dump (every thread's stacktrace), the breadcrumb
 * buffer, the debug-meta image list, and the SDK/packages/integrations maps.
 *
 * Detection: an event whose `exceptions` list contains a `SentryException`
 * whose `type` equals "ApplicationNotResponding" — the canonical ANR marker
 * produced by `sentry-android-core` (`AnrV2Integration` / `AnrIntegration`).
 *
 * Shrink strategy (in order), applied only to ANR events:
 *   1. drop breadcrumbs
 *   2. drop every thread's stacktrace (keep id/name/state/main/current)
 *   3. drop every exception's stacktrace (keep type/value/module/threadId)
 *   4. drop debugMeta (debug images)
 *   5. drop sdk (name/version/integrations/packages)
 *
 * Non-ANR events are returned untouched so the regular capture path is
 * unaffected.
 */
internal object AnrBodyShrinker {
    private const val ANR_EXCEPTION_TYPE = "ApplicationNotResponding"

    private val processedCount = AtomicLong(0)
    private val shrunkCount = AtomicLong(0)

    fun install(options: SentryOptions) {
        val previous = options.beforeSend
        options.beforeSend = SentryOptions.BeforeSendCallback { event, hint ->
            val next = previous?.execute(event, hint)
            if (next == null) {
                // A previous beforeSend dropped the event — respect that.
                null
            } else {
                shrinkIfAnr(next)
                next
            }
        }
    }

    /** Visible for tests. Returns true iff the event was an ANR that we shrank. */
    fun shrinkIfAnr(event: SentryEvent?): Boolean {
        if (event == null) return false
        if (!isAnrEvent(event)) return false

        processedCount.incrementAndGet()
        shrink(event)
        shrunkCount.incrementAndGet()
        return true
    }

    fun isAnrEvent(event: SentryEvent): Boolean {
        val exceptions = event.exceptions ?: return false
        for (exception in exceptions) {
            if (exception.type == ANR_EXCEPTION_TYPE) return true
        }
        return false
    }

    private fun shrink(event: SentryEvent) {
        // 1. Breadcrumbs — biggest single bloat source on a real device.
        event.breadcrumbs = null

        // 2. Thread stacktraces — keep the thread metadata, drop the frames.
        val threads = event.threads
        if (threads != null) {
            for (thread in threads) {
                stripThreadStacktrace(thread)
            }
        }

        // 3. Exception stacktraces — the ANR marker itself stays intact.
        val exceptions = event.exceptions
        if (exceptions != null) {
            for (exception in exceptions) {
                stripExceptionStacktrace(exception)
            }
        }

        // 4. Debug images (debugMeta) — needed for symbolication, but ANR
        //    frames point at JVM bytecode that's already on the device.
        event.debugMeta = null

        // 5. SDK metadata — redundant; the event already has
        //    event.origin/event.environment tags from SentryFlutterPlugin.
        event.sdk = null
    }

    private fun stripThreadStacktrace(thread: SentryThread) {
        thread.stacktrace = null
    }

    private fun stripExceptionStacktrace(exception: SentryException) {
        exception.stacktrace = null
    }
}
