package com.feratech.salomai

import android.app.Application
import com.feratech.salomai.push.PushManager

class SalomApp : Application() {
    override fun onCreate() {
        super.onCreate()
        // Must run before any activity so a notification tap can be routed even on
        // a cold start. No-ops when no OneSignal app id was supplied at build time.
        PushManager.init(this, BuildConfig.DEBUG)
    }
}
