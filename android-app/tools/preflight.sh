#!/usr/bin/env bash
#
# Pre-upload check. Run before every Play release:
#
#     ./tools/preflight.sh
#
# Catches the things that are invisible until it is too late — an unsigned or
# reused-versionCode bundle rejected after a 10-minute upload, push silently
# disabled, or a Google sign-in that works locally and fails for every Play user.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
BT="$(ls -d "$ANDROID_HOME"/build-tools/* 2>/dev/null | sort -V | tail -1)"

PASS=0; WARN=0; FAIL=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; WARN=$((WARN+1)); }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

echo
echo "Salom AI Android — release preflight"
echo "===================================="

# --- signing ------------------------------------------------------------------
echo
echo "Signing"
if [ -f key.properties ]; then
  ok "key.properties present"
  KS="$(grep '^storeFile=' key.properties | cut -d= -f2-)"
  if [ -f "$KS" ]; then ok "keystore exists: $KS"
  else bad "keystore missing: $KS"; fi
else
  bad "key.properties missing — run ./tools/create-keystore.sh"
fi

# --- version ------------------------------------------------------------------
echo
echo "Version"
VC=$(grep -E '^\s*versionCode = ' app/build.gradle.kts | grep -oE '[0-9]+' | head -1)
VN=$(grep -E '^\s*versionName = ' app/build.gradle.kts | cut -d'"' -f2)
ok "versionCode $VC / versionName $VN"
warn "versionCode must be HIGHER than anything ever uploaded to any Play track"

# --- config -------------------------------------------------------------------
echo
echo "Configuration"
OSID=$(grep -E '^ONESIGNAL_APP_ID=' local.properties 2>/dev/null | cut -d= -f2-)
if [ -n "${OSID:-}" ]; then ok "ONESIGNAL_APP_ID set — push enabled"
else warn "ONESIGNAL_APP_ID unset — this build ships WITHOUT push notifications"; fi

TSDK=$(grep -E '^\s*targetSdk = ' app/build.gradle.kts | grep -oE '[0-9]+' | head -1)
if [ "${TSDK:-0}" -ge 36 ]; then ok "targetSdk $TSDK (Play requires 36 from 2026-08-31)"
else bad "targetSdk $TSDK is below Play's minimum of 36"; fi

# --- build --------------------------------------------------------------------
echo
echo "Build"
if ./gradlew :app:lintDebug --no-daemon -q >/dev/null 2>&1; then ok "lint clean"
else bad "lint failed — run ./gradlew :app:lintDebug"; fi

if ./gradlew :app:bundleRelease --no-daemon -q >/dev/null 2>&1; then ok "bundleRelease succeeded"
else bad "bundleRelease failed"; fi

AAB=app/build/outputs/bundle/release/app-release.aab
if [ -f "$AAB" ]; then
  ok "AAB: $(du -h "$AAB" | cut -f1)"
  # Listed once into a variable on purpose: `unzip -l | grep -q` makes grep exit
  # on the first match, unzip dies of SIGPIPE, and `set -o pipefail` then reports
  # the whole pipeline as failed — a false negative on a file that is present.
  AAB_ENTRIES="$(unzip -l "$AAB")"
  if printf '%s' "$AAB_ENTRIES" | grep -q "obfuscation/proguard.map"; then
    ok "R8 mapping bundled (Play will deobfuscate crash reports)"
  else
    warn "no R8 mapping in the AAB — Play crash reports will be obfuscated"
  fi
  if printf '%s' "$AAB_ENTRIES" | grep -q "profiles/baseline.prof"; then
    ok "baseline profile bundled (faster cold start)"
  fi
else
  bad "no AAB produced"
fi

APK=app/build/outputs/apk/release/app-release.apk
if [ -f "$APK" ] && [ -n "$BT" ]; then
  if "$BT/apksigner" verify "$APK" >/dev/null 2>&1; then ok "release APK signature verifies"
  else bad "release APK is not correctly signed"; fi
fi

# --- things only the owner can finish ----------------------------------------
echo
echo "Owner checklist (cannot be verified from here)"
echo "  □ Android OAuth client in Google Cloud: package com.feratech.salomai"
echo "    with BOTH the upload-key SHA-1 and the Play App Signing SHA-1."
echo "    Missing the second one = Google sign-in fails for every Play user."
echo "  □ Play Console → App access: reviewer credentials (they cannot receive"
echo "    an Uzbek SMS or use the Telegram bot)."
echo "  □ Data safety: a PUBLIC account-deletion URL (/settings is behind auth)."
echo "  □ Screenshots: ./tools/capture-screenshots.sh <name> on a signed-in device."
echo "  □ Keystore + password backed up to 1Password."

echo
echo "===================================="
printf 'passed %d   warnings %d   failed %d\n\n' "$PASS" "$WARN" "$FAIL"
[ "$FAIL" -eq 0 ]
