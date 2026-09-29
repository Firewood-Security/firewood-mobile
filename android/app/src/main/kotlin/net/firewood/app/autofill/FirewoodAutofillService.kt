package net.firewood.app.autofill

import android.os.Build
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.Dataset
import android.service.autofill.FillCallback
import android.service.autofill.FillContext
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.widget.RemoteViews
import androidx.annotation.RequiresApi
import net.firewood.app.R

/**
 * FirewoodAutofillService
 *
 * Security-first autofill implementation:
 * - NEVER exposes credentials in the system dropdown
 * - Responds with a single "🔒 Open Firewood Vault" suggestion
 * - That suggestion launches [FirewoodAutofillPickerActivity] via PendingIntent
 * - The activity authenticates (biometric / device credential), shows a credential picker,
 *   and returns the chosen credential to the framework via setResult()
 *
 * This preserves the vault's master-password security model completely.
 */
@RequiresApi(Build.VERSION_CODES.O)
class FirewoodAutofillService : AutofillService() {

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback,
    ) {
        try {
            val fillContexts: List<FillContext> = request.fillContexts
            val latestStructure = fillContexts.lastOrNull()?.structure ?: run {
                callback.onSuccess(null)
                return
            }

            // Parse the view hierarchy to find username/password fields
            val parser = AutofillStructureParser(latestStructure)
            parser.parse()

            val usernameId  = parser.usernameAutofillId
            val passwordId  = parser.passwordAutofillId
            val webDomain   = parser.webDomain
            val packageName = parser.packageName

            // Never autofill Firewood itself (e.g. master password or unlock screen)
            if (packageName == applicationContext.packageName) {
                callback.onSuccess(null)
                return
            }

            // Nothing fillable found — do not show anything
            if (usernameId == null && passwordId == null) {
                callback.onSuccess(null)
                return
            }

            // If vault has no mirror yet, silently skip. V-007: the mirror key is
            // user-auth-bound, so it cannot be decrypted before any authentication —
            // existence of the mirror file is enough here; the picker authenticates
            // before it ever reads entries.
            val hasCredentials = AutofillSecureStore.hasMirrorData(applicationContext)
            if (!hasCredentials) {
                callback.onSuccess(null)
                return
            }

            // Build the locked "Open Firewood" presentation
            val presPackage = applicationContext.packageName
            val lockedPresentation = RemoteViews(presPackage, R.layout.autofill_locked_item)

            // Build the authentication PendingIntent → launches the picker activity
            val pendingIntent = FirewoodAutofillPickerActivity.buildPendingIntent(
                context       = applicationContext,
                usernameId    = usernameId,
                passwordId    = passwordId,
                webDomain     = webDomain,
                packageName   = packageName,
                isAndroidApp  = parser.isAndroidApp,
            )

            // A Dataset with authentication: tapping it opens Firewood instead of filling
            // directly. It deliberately carries NO values — the real username/password
            // only exists in the reply dataset returned by the picker activity, after
            // the user has authenticated and picked an entry.
            // Android requires at least one field associated with the Dataset.Builder.
            val authDatasetBuilder = Dataset.Builder(lockedPresentation)
                .setAuthentication(pendingIntent.intentSender)

            if (usernameId != null) {
                authDatasetBuilder.setValue(usernameId, null, lockedPresentation)
            }
            if (passwordId != null) {
                authDatasetBuilder.setValue(passwordId, null, lockedPresentation)
            }

            val authDataset = authDatasetBuilder.build()

            val response = FillResponse.Builder()
                .addDataset(authDataset)
                .build()

            callback.onSuccess(response)
        } catch (t: Throwable) {
            android.util.Log.e("FirewoodAutofill", "Error handling onFillRequest", t)
            callback.onSuccess(null)
        }
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        // Save is intentionally handled inside the main Firewood app
        callback.onSuccess()
    }
}
