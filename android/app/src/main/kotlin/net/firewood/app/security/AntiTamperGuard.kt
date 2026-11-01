package net.firewood.app.security

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Debug
import java.io.BufferedReader
import java.io.File
import java.io.FileReader
import java.io.InputStreamReader
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Anti-Tamper & Environment Integrity Guard for Firewood Mobile.
 *
 * Implements baseline and advanced defense-in-depth checks:
 *  - Root / privilege escalation binaries & packages (Magisk, KernelSU, APatch)
 *  - Dynamic hooking frameworks (Frida agent in memory, Xposed/LSPosed, Frida server ports)
 *  - Debugger attachment & process tracing (TracerPid, Debug.isDebuggerConnected)
 *  - Package debuggable flags
 */
object AntiTamperGuard {

    private val ROOT_PATHS = arrayOf(
        "/system/app/Superuser.apk",
        "/sbin/su",
        "/system/bin/su",
        "/system/xbin/su",
        "/data/local/xbin/su",
        "/data/local/bin/su",
        "/system/sd/xbin/su",
        "/system/bin/failsafe/su",
        "/data/local/su",
        "/data/adb/su",
        "/data/adb/magisk",
        "/data/adb/ksu",
        "/data/adb/ap"
    )

    private val SUSPICIOUS_LIBRARIES = arrayOf(
        "frida",
        "xposed",
        "substrate",
        "libgadget.so",
        "sandhook",
        "edxposed",
        "lsposed",
        "hook"
    )

    private val FRIDA_DEFAULT_PORTS = intArrayOf(27042, 27043)

    /**
     * Comprehensive tamper & environment audit.
     */
    fun performAudit(context: Context): TamperAuditResult {
        val findings = mutableListOf<String>()

        val isRooted = checkRootBinaries(findings) || checkBuildTags(findings) || checkSuExecution(findings)
        val isHooked = checkMemoryMapsForHooks(findings) || checkFridaPorts(findings)
        val isDebugger = checkDebugger(findings)
        val isDebuggable = checkDebuggableFlag(context, findings)

        val isCompromised = isRooted || isHooked || isDebugger

        return TamperAuditResult(
            isCompromised = isCompromised,
            isRooted = isRooted,
            isHooked = isHooked,
            isDebuggerAttached = isDebugger,
            isDebuggable = isDebuggable,
            findings = findings
        )
    }

    /**
     * Checks known root binary and manager paths.
     */
    fun checkRootBinaries(findings: MutableList<String>? = null): Boolean {
        for (path in ROOT_PATHS) {
            try {
                val file = File(path)
                if (file.exists()) {
                    findings?.add("Root artifact detected: $path")
                    return true
                }
            } catch (_: Exception) {}
        }
        return false
    }

    /**
     * Checks Build.TAGS for test-keys (custom or rooted ROM builds).
     */
    fun checkBuildTags(findings: MutableList<String>? = null): Boolean {
        val tags = Build.TAGS
        if (tags != null && tags.contains("test-keys")) {
            findings?.add("Custom OS build detected (test-keys)")
            return true
        }
        return false
    }

    /**
     * Attempts a non-interactive execution of 'which su' as fallback.
     */
    fun checkSuExecution(findings: MutableList<String>? = null): Boolean {
        var process: Process? = null
        return try {
            process = Runtime.getRuntime().exec(arrayOf("/system/xbin/which", "su"))
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val line = reader.readLine()
            if (line != null && line.trim().isNotEmpty()) {
                findings?.add("Active 'su' executable found in PATH")
                true
            } else {
                false
            }
        } catch (_: Exception) {
            false
        } finally {
            process?.destroy()
        }
    }

    /**
     * Scans /proc/self/maps to detect Frida or Xposed dynamic library injection in process RAM.
     */
    fun checkMemoryMapsForHooks(findings: MutableList<String>? = null): Boolean {
        return try {
            val mapsFile = File("/proc/self/maps")
            if (!mapsFile.exists()) return false

            BufferedReader(FileReader(mapsFile)).use { reader ->
                var line: String? = reader.readLine()
                while (line != null) {
                    val lower = line.lowercase()
                    for (lib in SUSPICIOUS_LIBRARIES) {
                        if (lower.contains(lib)) {
                            findings?.add("Dynamic hook library in memory: $lib")
                            return true
                        }
                    }
                    line = reader.readLine()
                }
            }
            false
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Checks if default Frida instrumentation server ports are active on localhost.
     */
    fun checkFridaPorts(findings: MutableList<String>? = null): Boolean {
        for (port in FRIDA_DEFAULT_PORTS) {
            try {
                Socket().use { socket ->
                    socket.connect(InetSocketAddress("127.0.0.1", port), 30)
                    findings?.add("Frida server listening on port $port")
                    return true
                }
            } catch (_: Exception) {
                // Closed/refused is expected and normal
            }
        }
        return false
    }

    /**
     * Detects attached Java debuggers and TracerPid in /proc/self/status.
     */
    fun checkDebugger(findings: MutableList<String>? = null): Boolean {
        if (Debug.isDebuggerConnected() || Debug.waitingForDebugger()) {
            findings?.add("Active debugger connected")
            return true
        }

        try {
            val statusFile = File("/proc/self/status")
            if (statusFile.exists()) {
                BufferedReader(FileReader(statusFile)).use { reader ->
                    var line: String? = reader.readLine()
                    while (line != null) {
                        if (line.startsWith("TracerPid:")) {
                            val pid = line.substring("TracerPid:".length).trim().toIntOrNull() ?: 0
                            if (pid > 0) {
                                findings?.add("Process is traced by PID: $pid")
                                return true
                            }
                            break
                        }
                        line = reader.readLine()
                    }
                }
            }
        } catch (_: Exception) {}

        return false
    }

    /**
     * Checks if application is flagged as debuggable.
     */
    fun checkDebuggableFlag(context: Context, findings: MutableList<String>? = null): Boolean {
        val isDebuggable = (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (isDebuggable) {
            findings?.add("Application is running with FLAG_DEBUGGABLE")
        }
        return isDebuggable
    }
}

data class TamperAuditResult(
    val isCompromised: Boolean,
    val isRooted: Boolean,
    val isHooked: Boolean,
    val isDebuggerAttached: Boolean,
    val isDebuggable: Boolean,
    val findings: List<String>
)
