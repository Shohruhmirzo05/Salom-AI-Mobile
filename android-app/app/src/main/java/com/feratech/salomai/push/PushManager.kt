package com.feratech.salomai.push

import android.content.Context
import android.util.Log
import com.feratech.salomai.BuildConfig
import com.onesignal.OneSignal
import com.onesignal.debug.LogLevel

/**
 * Native push via the OneSignal Android SDK.
 *
 * The web app subscribes to *web* push through the OneSignal JS SDK. That path is
 * deliberately not used here: a native subscription survives Chrome being
 * disabled, gets real Android notification channels, and is the same mechanism
 * the iOS app already uses.
 *
 * Everything is a no-op until an app id is supplied at build time
 * (`-PONESIGNAL_APP_ID=...`), so the app builds and runs without one.
 */
object PushManager {

    private const val TAG = "PushManager"

    val isConfigured: Boolean get() = BuildConfig.ONESIGNAL_APP_ID.isNotBlank()

    private var initialised = false

    fun init(context: Context, debug: Boolean) {
        if (!isConfigured || initialised) return
        initialised = true
        if (debug) OneSignal.Debug.logLevel = LogLevel.WARN
        OneSignal.initWithContext(context.applicationContext, BuildConfig.ONESIGNAL_APP_ID)
    }

    /**
     * Asks for POST_NOTIFICATIONS. Called only *after* the user is signed in —
     * prompting a logged-out first-run user is the fastest way to get denied
     * permanently, and Android 13+ gives you one shot.
     */
    suspend fun requestPermission(): Boolean {
        if (!isConfigured) return false
        return runCatching { OneSignal.Notifications.requestPermission(false) }
            .onFailure { Log.w(TAG, "requestPermission failed", it) }
            .getOrDefault(false)
    }

    /** Ties this device to the Salom AI account so backend campaigns can target it. */
    fun login(userId: Long) {
        if (!isConfigured) return
        runCatching { OneSignal.login(userId.toString()) }
            .onFailure { Log.w(TAG, "login failed", it) }
    }

    fun logout() {
        if (!isConfigured) return
        runCatching { OneSignal.logout() }.onFailure { Log.w(TAG, "logout failed", it) }
    }

    /** The subscription id to hand to `POST /notifications/device`. */
    fun subscriptionId(): String? {
        if (!isConfigured) return null
        return runCatching { OneSignal.User.pushSubscription.id }
            .getOrNull()
            ?.takeIf { it.isNotBlank() }
    }

    fun hasPermission(): Boolean =
        isConfigured && runCatching { OneSignal.Notifications.permission }.getOrDefault(false)
}
