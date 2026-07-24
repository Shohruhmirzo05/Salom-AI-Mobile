#!/bin/sh
set -eu

# Xcode Cloud provides a monotonically increasing CI_BUILD_NUMBER. The change
# stays inside the ephemeral CI checkout and is never committed to main.
if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  cd "$CI_PRIMARY_REPOSITORY_PATH/Salom-Ai-iOS"
  xcrun agvtool new-version -all "$CI_BUILD_NUMBER"
fi
