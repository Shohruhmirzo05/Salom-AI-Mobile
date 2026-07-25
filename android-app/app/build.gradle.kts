import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// ---------------------------------------------------------------------------
// Single source of truth for everything that identifies this shell.
// Changing anything here means a new Play release, so keep it minimal: the
// start URL points at the site root and lets the React router pick the
// destination (see web/src/pages/App.tsx `target=apps`).
// ---------------------------------------------------------------------------
val webOrigin = "https://salom-ai.uz"
val apiBase = "https://api.salom-ai.uz"
val startPath = "/?source=android&target=apps"

// The audience the backend already accepts for Google ID tokens
// (Salom-AI/backend/app/config.py GOOGLE_CLIENT_IDS). Android's Credential
// Manager mints tokens with `aud` = this *server* client ID, not the Android
// one — which is why native sign-in needs no backend change.
val googleServerClientId =
    "347718573096-iqp1uj4ido18qgfguqrlh00vil3qafcc.apps.googleusercontent.com"

// Resolved from, in order: -PONESIGNAL_APP_ID=..., local.properties, or the
// environment. local.properties is the one to use — it is gitignored and set
// once, so a release build cannot silently ship with push disabled because
// somebody forgot a command-line flag.
val localProperties = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val oneSignalAppId: String =
    (project.findProperty("ONESIGNAL_APP_ID") as String?)
        ?: localProperties.getProperty("ONESIGNAL_APP_ID")
        ?: System.getenv("ONESIGNAL_APP_ID")
        ?: ""

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) keystorePropertiesFile.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.feratech.salomai"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.feratech.salomai"
        minSdk = 24
        // Play requires API 36 for new apps and updates from 2026-08-31.
        targetSdk = 36
        // Starts at 10: the earlier Flutter and TWA shells used codes 1 and 2
        // locally, and Play burns a version code once uploaded to any track.
        versionCode = 10
        versionName = "1.0.0"

        buildConfigField("String", "WEB_ORIGIN", "\"$webOrigin\"")
        buildConfigField("String", "API_BASE", "\"$apiBase\"")
        buildConfigField("String", "START_URL", "\"$webOrigin$startPath\"")
        buildConfigField("String", "GOOGLE_SERVER_CLIENT_ID", "\"$googleServerClientId\"")
        buildConfigField("String", "ONESIGNAL_APP_ID", "\"$oneSignalAppId\"")

        resValue("string", "providerAuthority", "$applicationId.fileprovider")

        vectorDrawables.useSupportLibrary = true
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            if (hasReleaseKeystore) signingConfig = signingConfigs.getByName("release")
        }
        debug {
            // No applicationIdSuffix — debug and release share the package so the
            // debug build exercises the real Google Sign-In / App Links paths.
            isMinifyEnabled = false
        }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    lint {
        checkReleaseBuilds = false
        // Not actionable: every newer androidx release requires compileSdk 37,
        // which AGP 8.11.1 rejects. Revisit when both move together (see the
        // comment on the dependency block).
        disable += "GradleDependency"
        // The pre-API-26 square icon is a designed, full-bleed mark on its own
        // dark backdrop; adaptive icons handle masking from API 26 up.
        disable += "IconLauncherShape"
        warningsAsErrors = false
        abortOnError = true
    }

    dependenciesInfo {
        includeInApk = false
    }
}

dependencies {
    // Versions are pinned to the newest releases that still compile against
    // API 36. Anything newer (androidx.core 1.19+, activity 1.13+) demands
    // compileSdk 37, which AGP 8.11.1 does not support. Bump both together, not
    // one at a time.
    implementation("androidx.appcompat:appcompat:1.7.1")
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("androidx.activity:activity-ktx:1.10.1")
    implementation("androidx.webkit:webkit:1.13.0")
    // Custom Tabs for genuinely external links (blog outlinks, partner sites).
    implementation("androidx.browser:browser:1.8.0")

    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")

    // Native Google Sign-In. Required because Google blocks its OAuth pages
    // inside embedded WebViews (disallowed_useragent).
    implementation("androidx.credentials:credentials:1.5.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.5.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")

    implementation("com.onesignal:OneSignal:5.9.7")
}

gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any {
        it.name.contains("Release") && (it.name.startsWith("assemble") || it.name.startsWith("bundle"))
    }
    if (buildsRelease && !hasReleaseKeystore) {
        throw GradleException(
            "Release build requested but android-app/key.properties is missing.\n" +
                "Run ./tools/create-keystore.sh (once), or see README.md § Signing."
        )
    }
    // A warning, not an error: shipping v1 without push is a legitimate choice.
    // But shipping it *by accident* is not, so make it impossible to miss.
    if (buildsRelease && oneSignalAppId.isBlank()) {
        logger.warn(
            "\n" + "=".repeat(78) +
                "\n  RELEASE BUILD WITH PUSH DISABLED" +
                "\n  No ONESIGNAL_APP_ID found. Notifications will not work in this build." +
                "\n  Add  ONESIGNAL_APP_ID=<uuid>  to android-app/local.properties." +
                "\n" + "=".repeat(78) + "\n"
        )
    }
}
