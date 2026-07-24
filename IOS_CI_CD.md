# Salom AI iOS delivery

The repository supports both GitHub Actions and Xcode Cloud. Neither workflow
stores a private key, certificate, provisioning profile, or password in Git.

## GitHub Actions → TestFlight

Workflow: `.github/workflows/ios-testflight.yml`

Every iOS change first compiles on a clean macOS runner. TestFlight upload is
intentionally disabled until signing is configured, so an ordinary push cannot
create a broken release.

The workflow also rejects known injected Xcode build-phase signatures before
resolving packages or compiling, and verifies that the iOS mini-app surface has
not regressed to WebKit. Build numbers use the GitHub run number without editing
the checked-out project.

Create the `app-store-connect` GitHub environment, add these secrets to the
`Shohruhmirzo05/Salom-AI-Mobile` repository, then set repository variable
`IOS_TESTFLIGHT_ENABLED=true`:

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_P8` — the complete `.p8` text
- `IOS_DISTRIBUTION_CERTIFICATE_BASE64`
- `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64` — `com.fera-tech.salom-ai`
- `IOS_NOTIFICATION_PROVISIONING_PROFILE_BASE64` —
  `com.fera-tech.salom-ai.OneSignalNotificationExtension`

The API key needs App Manager access. Keep required reviewers enabled on the
`app-store-connect` environment if every main push should require approval.

## Xcode Cloud

The `ci_scripts` directory is ready for Xcode Cloud and uses its build number.
The remaining enrollment is a one-time Apple operation:

1. Xcode → Product → Xcode Cloud → Create Workflow.
2. Select `Salom-Ai-iOS`, Release configuration and App Store Connect/TestFlight.
3. Connect the `Shohruhmirzo05/Salom-AI-Mobile` GitHub repository.
4. Trigger on changes under `Salom-Ai-iOS/**`; keep pull requests build-only.
5. Enable automatic signing for both the app and OneSignal extension.

Xcode Cloud owns its signing assets inside App Store Connect; GitHub Actions
uses the separately scoped GitHub environment secrets above.
