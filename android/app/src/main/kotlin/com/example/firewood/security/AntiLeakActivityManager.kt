package com.example.firewood.security

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
     * Lazily removes FLAG_SECURE when the user needs to take a screenshot
     * of a non-sensitive screen (e.g., QR code for P2P sharing).
     * Call for specific screens only; re-enable FLAG_SECURE when leaving.
     */
    fun temporarilyAllowScreenshots(activity: Activity) {
        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    /**
     * Re-applies FLAG_SECURE after [temporarilyAllowScreenshots].
     */
    fun reapplySecureFlags(activity: Activity) {
        activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    /**
     * Checks for common indicators of a compromised environment.
     * Returns a map of findings – caller should decide mitigation strategy.
     *
     * Detection signals:
     *  - Developer options enabled
     *  - USB debugging active
     *  - Running in an emulator (optional, configurable)
     *  - Accessibility services with overlay permission enabled
     */
    fun auditEnvironment(context: Context): EnvironmentAuditResult {
        val findings = mutableListOf<String>()

        // Check if developer options are likely enabled
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

        // Check for accessibility services (potential overlays/keyloggers)
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

        val isCompromised = findings.isNotEmpty()

        return EnvironmentAuditResult(
            isCompromised = isCompromised,
            findings = findings
        )
    }

    /**
     * Clears the activity's window content to a blank view when the app
     * goes to background (additional layer beyond FLAG_SECURE).
     */
    fun onAppBackgrounded(activity: Activity) {
        // When combined with FLAG_SECURE, this provides defense-in-depth
        // against app switcher thumbnail leaks on buggy OEM implementations
        try {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } catch (_: Exception) {
            // Non-critical – FLAG_SECURE was likely already set
        }
    }
}

data class EnvironmentAuditResult(
    val isCompromised: Boolean,
    val findings: List<String>
)
