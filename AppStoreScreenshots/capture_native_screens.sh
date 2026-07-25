#!/bin/zsh
set -euo pipefail

SIMULATOR_ID="EB66F906-7FA1-44CD-992B-F62A29039622"
BUNDLE_ID="com.fera-tech.salom-ai"
OUTPUT_DIR="/Users/shohruh/Documents/Personal/Untitled/Salom-AI-Mobile/AppStoreScreenshots/raw"

capture() {
  local name="$1"
  local theme="$2"
  shift 2

  xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID" --args \
    -preferredThemeMode "$theme" \
    -preferredLanguageCode uz \
    "$@" >/dev/null
  sleep 3
  xcrun simctl io "$SIMULATOR_ID" screenshot "$OUTPUT_DIR/$name.png" >/dev/null
}

capture "01-chat-search" dark -SALOM_QA_CHAT search
capture "02-image-reference-composer" dark -SALOM_QA_CHAT ready
capture "03-chat-work-document" light -SALOM_QA_CHAT work
capture "04-apps-hub" dark -SALOM_QA_SURFACE apps
capture "05-dtm-tests" dark -SALOM_QA_SURFACE dtm
capture "06-presentations" light -SALOM_QA_SURFACE presentations
capture "07-referats" light -SALOM_QA_SURFACE referats
capture "08-work-documents" dark -SALOM_QA_SURFACE ish-document
capture "09-voice-chat" dark -SALOM_QA_SURFACE realtime-preview
capture "10-government-guide" light -SALOM_QA_SURFACE miniapp:government-guide
capture "11-salary-calculator" light -SALOM_QA_SURFACE miniapp:salary-employment
capture "12-teacher-assistant" dark -SALOM_QA_SURFACE miniapp:teacher-assistant
capture "13-document-explainer" dark -SALOM_QA_SURFACE miniapp:document-explainer
capture "14-marketplace-seller" dark -SALOM_QA_SURFACE miniapp:marketplace-seller
capture "15-family-budget" light -SALOM_QA_SURFACE miniapp:money-planner
