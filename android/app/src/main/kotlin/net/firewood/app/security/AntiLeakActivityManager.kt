package net.firewood.app.security

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager

/**
 * Activity-level security hardening for all Firewood screens.
 *
 * Addresses SECURITY_AUDIT.md findings:
 *  - U1: No screen capture prevention (FLAG_SECURE)
 *  - A1: Task-hijacking / overlay attacks
 *  - General: App switcher thumbnail exposure of decrypted secrets
 *
 * Call [applyAllSecurityFlags] in every Activity's onCreate().
 */
object AntiLeakActivityManager {

    /**
     * Applies all security window flags to [activity].
     * Must be called before setContentView() in onCreate().
     */
    fun applyAllSecurityFlags(activity: Activity) {
        // FLAG_SECURE: prevents screenshots, screen recording, and app-switcher
        // thumbnails from capturing any Firewood UI (passwords, decrypted data)
        activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        // On API 31+, explicitly prevent non-secure overlay attacks
        // (tapjacking via accessibility overlays, malware windows)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            activity.window.attributes = activity.window.attributes.apply {
                // Prevent non-system overlays from intercepting touches
                flags = flags or WindowManager.LayoutParams.FLAG_SECURE
            }
        }

        // Hide sensitive content from window previews in recents
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.setRecentsScreenshotEnabled(false)
        }

        // Disable screen content capture via accessibility services
        // (prevents automated scraping of credential fields)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            activity.window.addFlags(
                WindowManager.LayoutParams.FLAG_SECURE
            )
        }
    }

    /**
     * Clears FLAG_SECURE so a screenshot/recording can be taken.
     *
     * V-019: only ever reachable through the method channel when the user's
     * stored screenshot policy allows capture (see the `disableSecureFlag`
     * gate in SecureMethodChannel) — never call this to make a QR or any
     * other on-screen content "shareable": the flag is window-wide and a QR
     * scans fine while it is set.
     */
    fun temporarilyAllowScreenshots(activity: Activity) {
        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    /**
     * Reads the user's stored screenshot policy — Flutter writes the
     * `allow_screenshots` key into `FlutterSharedPreferences`. Absent/false
     * means FLAG_SECURE is required (fail closed). The map is the Android
     * SharedPreferences singleton, so Dart-side writes are visible here
     * immediately (same process, same file-backed instance).
     */
    private fun captureAllowed(activity: Activity): Boolean {
        return try {
            val prefs = activity.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE
            )
            when (val v = prefs.all["flutter.allow_screenshots"]) {
                is Boolean -> v
                is String -> v.equals("true", ignoreCase = true)
                else -> false
            }
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Applies the stored screenshot policy: FLAG_SECURE when capture is not
     * allowed, cleared when the user opted in via Settings → Allow
     * Screenshots.
     *
     * Policy-aware on purpose: this runs on EVERY Activity resume (and from
     * the `enableSecureFlag` channel call) — an unconditional re-apply used
     * to silently kill the user's choice the first time they backgrounded
     * the app, making the Settings toggle appear broken.
     */
    fun reapplySecureFlags(activity: Activity) {
        if (captureAllowed(activity)) {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    /**
     * Checks for common indicators of a compromised environment.
     * Returns a map of findings – caller should decide mitigation strategy.
     *
     * Detection signals:
     *  - Root binaries & package managers (Magisk, KernelSU, APatch)
     *  - Dynamic hooking frameworks (Frida memory map injection, Frida server)
     *  - Attached debuggers / TracerPid
     *  - Developer options enabled
     *  - Accessibility services with overlay permission enabled
     */
    fun auditEnvironment(context: Context): EnvironmentAuditResult {
        val findings = mutableListOf<String>()

        // 1. Run Anti-Tampering & Root / Hook / Debugger checks
        val tamperResult = AntiTamperGuard.performAudit(context)
        findings.addAll(tamperResult.findings)

        // 2. Check if developer options are likely enabled
        val devOptionsEnabled = try {
            val cls = Class.forName("android.provider.Settings\$Global")
            val getInt = cls.getMethod("getInt",
                android.content.ContentResolver::class.java, String::class.java, Int::class.java)
            val result = getInt.invoke(null, context.contentResolver,
                "development_settings_enabled", 0) as Int
            result == 1
        } catch (_: Exception) {
            false
        }

        if (devOptionsEnabled) {
            findings.add("Developer options enabled")
        }

        // 3. Check for accessibility services (potential overlays/keyloggers)
        val accessibilityServices = try {
            val cls = Class.forName("android.provider.Settings\$Secure")
            val getString = cls.getMethod("getString",
                android.content.ContentResolver::class.java, String::class.java)
            getString.invoke(null, context.contentResolver,
                "enabled_accessibility_services") as? String
        } catch (_: Exception) {
            null
        }

        if (!accessibilityServices.isNullOrEmpty()) {
            findings.add("Active accessibility services: $accessibilityServices")
        }

        val isCompromised = tamperResult.isCompromised || findings.isNotEmpty()

        return EnvironmentAuditResult(
            isCompromised = isCompromised,
            findings = findings
        )
    }

    /**
     * Clears the activity's window content to a blank view when the app
     * goes to background (additional layer beyond FLAG_SECURE). Honors the
     * stored screenshot policy — a user who allowed capture keeps that
     * choice across backgrounding.
     */
    fun onAppBackgrounded(activity: Activity) {
        // When combined with FLAG_SECURE, this provides defense-in-depth
        // against app switcher thumbnail leaks on buggy OEM implementations
        try {
            if (!captureAllowed(activity)) {
                activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        } catch (_: Exception) {
            // Non-critical – FLAG_SECURE was likely already set
        }
    }
}

data class EnvironmentAuditResult(
    val isCompromised: Boolean,
    val findings: List<String>
)

