package com.feratech.salomai.auth

import android.util.Log
import android.webkit.WebView
import com.feratech.salomai.net.SalomApi
import com.feratech.salomai.push.PushManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Keeps native state in sync with whoever is signed in inside the WebView.
 *
 * The web app is the single source of truth for sessions — it stores the JWT in
 * `localStorage` (see web/src/store/auth.ts). Rather than adding a JS bridge the
 * web team would have to maintain, this reads that value after every page load
 * and reacts when it changes.
 *
 * That means Telegram and Apple sign-in — which stay entirely inside the web app
 * — still end up registering the device for push, exactly like native Google
 * sign-in does. **No web-side change is required for any of it.**
 */
class SessionWatcher(
    private val scope: CoroutineScope,
    private val onSignedIn: suspend (userId: Long) -> Unit = {},
) {

    private var lastSeenToken: String? = null
    private var lastResolvedUserId: Long? = null

    /** Call from `onPageFinished` for our own origin. */
    fun syncFrom(webView: WebView) {
        webView.evaluateJavascript(READ_TOKEN_JS) { raw ->
            val token = unquote(raw)
            if (token == lastSeenToken) return@evaluateJavascript
            lastSeenToken = token

            if (token == null) {
                if (lastResolvedUserId != null) {
                    lastResolvedUserId = null
                    PushManager.logout()
                }
                return@evaluateJavascript
            }
            scope.launch { resolve(token) }
        }
    }

    /** Writes a natively-obtained session into the web app's storage. */
    fun inject(webView: WebView, session: SalomApi.Session, onDone: () -> Unit) {
        val js = """
            (function () {
              try {
                localStorage.setItem('access_token', ${session.accessToken.toJsString()});
                localStorage.setItem('refresh_token', ${session.refreshToken.toJsString()});
                localStorage.setItem('salom_returning', '1');
                return 'ok';
              } catch (e) { return 'err'; }
            })();
        """.trimIndent()
        webView.evaluateJavascript(js) { onDone() }
    }

    private suspend fun resolve(accessToken: String) {
        val userId = SalomApi.currentUserId(accessToken)
        if (userId == null) {
            Log.w(TAG, "Could not resolve user for the stored session")
            return
        }
        lastResolvedUserId = userId
        PushManager.login(userId)
        SalomApi.reportPlatform(accessToken)
        onSignedIn(userId)
        registerDeviceWhenReady(accessToken)
    }

    /**
     * The OneSignal subscription id is not available the instant permission is
     * granted — the SDK has to register with the server first. Poll briefly
     * instead of racing it.
     */
    private suspend fun registerDeviceWhenReady(accessToken: String) {
        if (!PushManager.isConfigured) return
        repeat(SUBSCRIPTION_POLL_ATTEMPTS) {
            PushManager.subscriptionId()?.let { id ->
                SalomApi.registerDevice(accessToken, id)
                return
            }
            delay(SUBSCRIPTION_POLL_INTERVAL_MS)
        }
        Log.w(TAG, "OneSignal subscription id never became available")
    }

    private fun unquote(raw: String?): String? {
        if (raw == null || raw == "null" || raw == "\"\"") return null
        // evaluateJavascript hands back a JSON-encoded value.
        return raw.trim('"')
            .replace("\\\"", "\"")
            .replace("\\\\", "\\")
            .takeIf { it.isNotBlank() }
    }

    private fun String.toJsString(): String =
        '"' + replace("\\", "\\\\").replace("\"", "\\\"") + '"'

    private companion object {
        const val TAG = "SessionWatcher"
        const val SUBSCRIPTION_POLL_ATTEMPTS = 10
        const val SUBSCRIPTION_POLL_INTERVAL_MS = 1_500L
        const val READ_TOKEN_JS = "(function(){try{return localStorage.getItem('access_token');}catch(e){return null;}})();"
    }
}
