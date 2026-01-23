#!/bin/sh

# This script fixes the "Invalid Bundle" errors during App Store upload
# caused by missing MinimumOSVersion in third-party frameworks.

echo "🔧 Fixing frameworks in ${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"

cd "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"

for framework in *.framework; do
    plist="${framework}/Info.plist"
    if [ -f "$plist" ]; then
        echo "Processing $framework..."
        
        # 1. Force Set MinimumOSVersion
        # Try to Set (if exists), otherwise Add
        /usr/libexec/PlistBuddy -c "Set :MinimumOSVersion ${IPHONEOS_DEPLOYMENT_TARGET}" "$plist" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :MinimumOSVersion string ${IPHONEOS_DEPLOYMENT_TARGET}" "$plist"
        
        echo "  ✅ Set MinimumOSVersion to ${IPHONEOS_DEPLOYMENT_TARGET}"
        
        # 2. Re-sign the framework
        # Modifying the plist breaks the signature, so we must re-sign.
        if [ -n "${EXPANDED_CODE_SIGN_IDENTITY}" ]; then
            echo "  ✍️ Re-signing with ${EXPANDED_CODE_SIGN_IDENTITY}..."
            /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --preserve-metadata=identifier,entitlements "$framework"
        fi
    fi
done

echo "✨ Framework fix complete."
