# Salom AI Android — Trusted Web Activity

This is the low-maintenance Android shell requested for Salom AI. Product,
mini-app, paywall and localization updates are delivered by `salom-ai.uz`
without a Play Store release. A new Android release is only needed for native
permissions, package metadata, icons or Play policy changes.

It uses the existing package name `com.feratech.salomai`, so it can replace the
unpublished/early Flutter shell when signed with the same upload key.

## One-time domain verification

Google Play Console → App integrity exposes the Play App Signing SHA-256
fingerprint. Replace the placeholder in `assetlinks.template.json`, publish it
as:

`https://salom-ai.uz/.well-known/assetlinks.json`

Do not publish a debug or guessed fingerprint. Until verification is live,
Chrome safely opens the same app with browser controls instead of a trusted
full-screen surface.

## Build

The project shares the existing Gradle 8.14 wrapper binary from the former
Flutter Android project. From this directory:

```sh
./gradlew :app:bundleRelease
```

The Play Store artifact is `app/build/outputs/bundle/release/app-release.aab`.
Use the same upload keystore as the existing `com.feratech.salomai` listing.

## Product constraints

- Authentication, payments, camera/file upload and push links remain web-owned.
- Sensitive government identifiers are never stored by this shell.
- Android back/deep links are handled by Chrome/TWA and the web router.
- The web manifest and Android shell start on the HTTPS root with
  `target=apps`; the React router then opens the mobile-first apps hub without
  asking nginx for a virtual SPA directory.
