# Anything reachable from JavaScript is invisible to R8's call graph.
-keepclassmembers class com.feratech.salomai.MainActivity$SurfaceBridge {
    @android.webkit.JavascriptInterface <methods>;
}
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Manifest-declared components.
-keep class com.feratech.salomai.SalomApp { *; }
-keep class com.feratech.salomai.MainActivity { *; }

# Credential Manager + Google ID resolve providers reflectively.
-keep class androidx.credentials.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** { *; }

# OneSignal registers receivers/services by name.
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**
