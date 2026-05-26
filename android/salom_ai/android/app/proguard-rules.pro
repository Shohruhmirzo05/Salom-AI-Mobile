# =============================================
# Salom AI — ProGuard / R8 rules for release builds
# =============================================

# --- Flutter / Dart ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- Dio / OkHttp / Conscrypt / HTTP ---
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**

# --- Supabase / GoTrue / Realtime ---
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# --- OneSignal ---
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# --- Google Sign-In / Play Services ---
-keep class com.google.android.gms.** { *; }
-keep interface com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# --- AndroidX ---
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.**

# --- json_serializable / json_annotation generated code ---
-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses
-keep class * implements com.google.gson.TypedAdapter { *; }

# --- Audio: record + audioplayers ---
-keep class com.llfbandit.record.** { *; }
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn com.llfbandit.record.**
-dontwarn xyz.luan.audioplayers.**

# --- web_socket_channel / WebSocket ---
-keep class org.java_websocket.** { *; }
-dontwarn org.java_websocket.**

# --- General app code: keep enums + Parcelable + Serializable ---
-keepclassmembers enum * { *; }
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# --- Strip android.util.Log calls from release builds ---
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# --- Crash reporting: keep source file + line numbers in stack traces ---
-keepattributes SourceFile, LineNumberTable
-renamesourcefileattribute SourceFile
