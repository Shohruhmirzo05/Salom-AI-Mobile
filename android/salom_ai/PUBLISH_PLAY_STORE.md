# Salom AI — Android Play Store Publishing Runbook

**Target package:** `com.feratech.salomai`
**Current version:** `1.0.0+1` (versionName=1.0.0, versionCode=1)

Build verified working as of this commit (debug + release APK + AAB compile cleanly).

---

## 0. One-time prerequisites

### 0.1 Generate the upload keystore (do this ONCE and keep it safe)

```bash
keytool -genkey -v \
  -keystore ~/salom-ai-upload.keystore \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias salom-ai
```

- Pick a strong **store password** and **key password** (can be the same).
- **BACK THIS FILE UP** to 1Password / a safe place. If you lose it, you cannot ship updates to the same app — Play Store will not let you publish a new app under the same applicationId.
- Print the SHA-1 (you'll need it for OAuth):
  ```bash
  keytool -list -v -keystore ~/salom-ai-upload.keystore -alias salom-ai
  ```

### 0.2 Wire the keystore for Gradle

Create `android/salom_ai/android/key.properties` (this file is gitignored — never commit):

```properties
storeFile=/Users/shohruh/salom-ai-upload.keystore
storePassword=YOUR_STORE_PASSWORD
keyAlias=salom-ai
keyPassword=YOUR_KEY_PASSWORD
```

Confirm `.gitignore` excludes it:
```bash
cd android/salom_ai/android
echo "key.properties" >> .gitignore
echo "*.keystore" >> .gitignore
```

### 0.3 Google Cloud Console — Android OAuth client

The applicationId changed from `com.example.salom_ai` → `com.feratech.salomai`. Update Google Cloud Console:

1. Go to https://console.cloud.google.com → APIs & Services → Credentials
2. Edit (or create) the Android OAuth 2.0 client:
   - **Package name:** `com.feratech.salomai`
   - **SHA-1:** the release SHA-1 from step 0.1, AND the debug SHA-1 (`98:AE:C8:A1:F0:09:7E:AD:9B:B1:E6:09:AD:35:4A:2E:6C:82:C6:0B`) so dev builds still work
3. Save.

### 0.4 Firebase / google-services.json

`google_sign_in` works without Firebase, but if you want Firebase Crashlytics / Analytics later, you'll need:
1. Create a Firebase project (can reuse iOS project)
2. Add an Android app with package `com.feratech.salomai`
3. Download `google-services.json` → drop into `android/salom_ai/android/app/`
4. Add the Google Services Gradle plugin (only if/when you add Crashlytics)

**Not required for v1.0.0 launch.** Skip if you don't need Firebase.

### 0.5 OneSignal — confirm app ID

Current code uses `4bf70eb4-54f5-4479-8ef4-70e262dc6d2b` (matches your iOS app). Two options:
- **Reuse iOS app ID** (current default). Works, but you can't target Android-only campaigns.
- **Create a separate "Salom AI Android" app in OneSignal** and pass its ID via:
  ```bash
  flutter build appbundle --release --dart-define=ONESIGNAL_APP_ID=<new-uuid>
  ```

---

## 1. Build the release artifact

```bash
cd /Users/shohruh/Documents/Personal/Untitled/Salom-AI-Mobile/android/salom_ai

# 1. Pull deps + clean caches
flutter clean
flutter pub get

# 2. Build the Android App Bundle (this is what Play Store wants)
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab  (~53 MB)
```

If keystore is wired correctly via `key.properties`, the AAB is signed with your upload key.

Verify signing:
```bash
~/Library/Android/sdk/build-tools/<latest>/apksigner verify --verbose build/app/outputs/bundle/release/app-release.aab 2>&1 | head -5
# or use jarsigner -verify
```

---

## 2. Play Console — first-time app setup

If you don't have a Google Play Developer account: https://play.google.com/console — **$25 one-time fee**.

1. **Create app**
   - App name: Salom AI
   - Default language: O'zbek (uz) — or English depending on your audience
   - App or game: App
   - Free or paid: Free (you handle subs via your own Payme/Click + future Google Play Billing)
   - Declarations: agree to policies

2. **Set up your app — sidebar checklist**
   - Privacy policy URL → `https://salom-ai.uz/privacy-policy`
   - App access → "All functionality available without restrictions" (or provide a test login if you keep some screens auth-gated)
   - Ads → No
   - Content rating → fill out the questionnaire (text/voice/no violence → likely Everyone)
   - Target audience → 13+ (Uzbek voice assistant)
   - Data safety → fill out (you collect: name, email, phone, audio for transcription, app interactions). All processed on your servers, not shared with third parties.
   - News app → No
   - COVID-19 contact tracing → No
   - Government app → No

3. **Store listing**
   - **Short description (≤80 chars):** "Salom AI — o'zbek tilidagi sun'iy intellekt yordamchingiz."
   - **Full description (≤4000 chars):** write a paragraph + bullet points of features (Uzbek chat, voice, image generation, multi-language)
   - **App icon:** 512x512 PNG
   - **Feature graphic:** 1024x500 PNG (banner for Play Store listing)
   - **Phone screenshots:** at least 2, max 8 — 1080x1920 typical. Take from a real device or emulator.
   - **(Optional) Tablet screenshots** if you want tablet visibility

4. **Production setup → Countries / regions**: pick where to release (Uzbekistan + diaspora).

---

## 3. First upload — Internal testing track

Don't go straight to production. Use **Internal testing** first (no review delay, instant install).

1. Play Console → Testing → **Internal testing** → Create new release
2. Upload `app-release.aab`
3. Release name: `1.0.0` (or `1.0.0 (1)`)
4. Release notes (Uzbek):
   ```
   Birinchi versiya. Chat, ovozli suhbat, va rasm yaratish funksiyalari.
   ```
5. Add internal testers — your Gmail + a few colleagues — to a tester list (email addresses).
6. Save → **Review release** → **Start rollout to Internal testing**.

You'll get an opt-in URL. Open it on Android device → install via Play Store → smoke test:
- Google sign-in works (if SHA-1 was correct)
- Phone OTP works (you'll get the real SMS or the dev bypass `+998996508589`)
- Chat streaming works
- Voice connects, transcribes Uzbek, replies with audio
- Backgrounding the app and reopening: voice reconnects
- Phone call mid-voice-session: pauses gracefully

---

## 4. Promote → Closed testing → Production

After 24-48h of internal testing:
1. Play Console → Testing → **Closed testing** → reuse the AAB (no re-upload needed if you're promoting)
2. Add a wider tester list (or use Google Group)
3. After another soak (3-7 days): **Production** rollout
4. **Staged rollout: start at 10%**, monitor crash-free rate on Play Console → Quality → Android vitals. Bump to 50% then 100% over a few days.

---

## 5. Updating the app later

For every new release:

1. Bump version in `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2   # versionName 1.0.1, versionCode 2 (must increment)
   ```
2. Build: `flutter build appbundle --release`
3. Upload AAB in Play Console → new release on whichever track
4. Write release notes (per language).

---

## 6. Known issues / future work

These are **NOT blockers for v1.0** but should be done in upcoming versions:

| Item | Severity | Notes |
|---|---|---|
| Native Click/Payme card flow | medium | Currently opens external checkout URL — works but UX is suboptimal. iOS has the full inline card sheet. Implementing on Android is a multi-day task. |
| Apple Sign-In | none | Android app intentionally doesn't expose this — already hidden in UI. |
| `flutter_markdown` deprecated | low | Will need migration to a successor package in 6-12 months. |
| 143 `info`-level lints | low | Mostly `withOpacity` → `.withValues(alpha:)` migrations. No functional impact. |
| Default Flutter launcher icon | medium | Replace `android/app/src/main/res/mipmap-*` with your Salom AI brand icon before production release. Use `flutter_launcher_icons` package or generate via Android Studio's Asset Studio. |
| App startup splash | medium | Currently uses default Flutter splash. Add a branded splash via the `flutter_native_splash` package or `windowSplashScreen*` in styles.xml. |
| Tablet screenshots | low | Only required if you want tablet visibility on Play Store. |

---

## 7. Rollback plan

If a release breaks production:
1. Play Console → Production → **Halt rollout** (instant — stops new installs from getting the broken version)
2. Cut a `1.0.x` hotfix (increment versionCode)
3. Upload AAB → staged rollout again

For really catastrophic releases, you can also **revert** to a prior release in the same track from Play Console (rolls existing installs back over the next ~24h).

---

## 8. What's in this build (for your reference)

- **Backend:** points to `https://api.salom-ai.uz` (production).
- **Realtime voice:** uses the production WS `/ws/voice/yandex/realtime` with iOS-parity reliability fixes (15s dual ping, mid-call language switching, lifecycle-aware reconnect, audio interruption observer, exponential backoff).
- **Push:** OneSignal initialized with `4bf70eb4-54f5-4479-8ef4-70e262dc6d2b` (same as iOS). External user id is set automatically post-login.
- **Auth:** Phone OTP (Uzbek `+998` default) + Google Sign-In. Apple is hidden on Android.
- **Chat:** streaming, attachments, image generation, message regeneration on the last assistant turn.
- **Subscription:** Plans list + paywall opens external checkout URL (Payme/Click).

---

## 9. Quick-reference commands

```bash
# Sanity check before building
flutter analyze | grep -E "^[[:space:]]*error"   # should print nothing

# Local dev (debug install on connected device)
flutter run --release

# Build for distribution
flutter build appbundle --release

# Sign verification (replace <ver> with your SDK build-tools version)
~/Library/Android/sdk/build-tools/<ver>/bundletool verify build/app/outputs/bundle/release/app-release.aab

# See real device on which versionCode is currently installed
adb shell dumpsys package com.feratech.salomai | grep versionCode
```

---

If you hit anything during upload (signing mismatch, manifest rejection, etc.) paste the Play Console error message back here and I'll fix it.
