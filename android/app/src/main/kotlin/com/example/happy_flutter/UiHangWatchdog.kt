package com.example.happy_flutter

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.sentry.Sentry
import io.sentry.SentryLevel
import java.util.concurrent.atomic.AtomicBoolean

object UiHangWatchdog {
    private const val HEARTBEAT_MS = 1_000L
    private const val HANG_THRESHOLD_MS = 5_000L
    private const val REPORT_COOLDOWN_MS = 60_000L
    private const val MAIN_STACK_LIMIT = 24

    private val started = AtomicBoolean(false)
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var lastHeartbeatMs = SystemClock.uptimeMillis()

    @Volatile
    private var reportedCurrentHang = false

    @Volatile
    private var lastReportMs = 0L

    fun start() {
        if (!started.compareAndSet(false, true)) return
        mainHandler.post { heartbeat() }

        Thread({ watch() }, "happy-ui-hang-watchdog").apply {
            isDaemon = true
            start()
        }
    }

    private fun heartbeat() {
        lastHeartbeatMs = SystemClock.uptimeMillis()
        reportedCurrentHang = false
        mainHandler.postDelayed({ heartbeat() }, HEARTBEAT_MS)
    }

    private fun watch() {
        while (true) {
            Thread.sleep(HEARTBEAT_MS)

            val now = SystemClock.uptimeMillis()
            val blockedMs = now - lastHeartbeatMs
            if (blockedMs < HANG_THRESHOLD_MS) {
                reportedCurrentHang = false
                continue
            }
            if (reportedCurrentHang) continue
            if (now - lastReportMs < REPORT_COOLDOWN_MS) continue

            reportedCurrentHang = true
            lastReportMs = now
            reportHang(blockedMs)
        }
    }

    private fun reportHang(blockedMs: Long) {
        val mainThread = Looper.getMainLooper().thread
        val stack = mainThread.stackTrace
            .take(MAIN_STACK_LIMIT)
            .joinToString("\n") { it.toString() }

        Sentry.withScope { scope ->
            scope.setTag("watchdog.type", "ui_hang")
            scope.setTag("watchdog.thread", mainThread.name)
            scope.setTag("watchdog.thread_state", mainThread.state.name)
            scope.setExtra("blocked_ms", blockedMs)
            scope.setExtra("threshold_ms", HANG_THRESHOLD_MS)
            scope.setExtra("main_stack_top", stack)
            Sentry.captureMessage(
                "Android UI thread hang detected",
                SentryLevel.WARNING,
            )
        }
    }
}
