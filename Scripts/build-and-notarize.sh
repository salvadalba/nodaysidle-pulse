#!/usr/bin/env bash
# build-and-notarize.sh — Build Pulse, sign with Developer ID, notarize, and package as DMG.
# Requires: Xcode, Apple Developer ID, notarytool configured (xcrun notarytool store-credentials).
# Usage: ./Scripts/build-and-notarize.sh

set -e
cd "$(dirname "$0")/.."
NAME=Pulse
APP_NAME=${NAME}.app
DMG_NAME=${NAME}.dmg
RELEASE=.build/release

echo "Building release binary…”
swift build -c release

echo "Generating app icon…"
./Scripts/generate-icon.sh 2>/dev/null || true

echo "Creating .app bundle…”
rm -rf "${RELEASE}/${APP_NAME}"
mkdir -p "${RELEASE}/${APP_NAME}/Contents/MacOS"
mkdir -p "${RELEASE}/${APP_NAME}/Contents/Resources"
cp "${RELEASE}/${NAME}" "${RELEASE}/${APP_NAME}/Contents/MacOS/"
cp Sources/Pulse/Resources/logo.svg "${RELEASE}/${APP_NAME}/Contents/Resources/" 2>/dev/null || true
[[ -f .build/AppIcon.icns ]] && cp .build/AppIcon.icns "${RELEASE}/${APP_NAME}/Contents/Resources/"
cp Sources/Pulse/Pulse.entitlements "${RELEASE}/${APP_NAME}/Contents/" 2>/dev/null || true

# Info.plist with icon
cat > "${RELEASE}/${APP_NAME}/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>Pulse</string>
	<key>CFBundleIdentifier</key><string>com.pulse.app</string>
	<key>CFBundleName</key><string>Pulse</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0.0</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>15.0</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>NSHighResolutionCapable</key><true/>
	<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

ENTITLEMENTS="${RELEASE}/${APP_NAME}/Contents/Pulse.entitlements"
if [[ ! -f "$ENTITLEMENTS" ]]; then
  echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>com.apple.security.app-sandbox</key><true/></dict></plist>' > "$ENTITLEMENTS"
fi

echo "Signing with Developer ID…"
codesign --force --deep --sign "Developer ID Application" --options runtime --entitlements "$ENTITLEMENTS" "${RELEASE}/${APP_NAME}"

echo "Creating DMG…"
rm -f "${RELEASE}/${DMG_NAME}"
hdiutil create -volname "${NAME}" -srcfolder "${RELEASE}/${APP_NAME}" -ov -format UDZO "${RELEASE}/${DMG_NAME}"

echo "Signing DMG…"
codesign --force --sign "Developer ID Application" "${RELEASE}/${DMG_NAME}"

echo "Submitting for notarization…"
# Use your notarytool keychain profile (e.g. xcrun notarytool store-credentials)
NOTARIZE_OUT=$(xcrun notarytool submit "${RELEASE}/${DMG_NAME}" --keychain-profile "notarytool" --wait 2>&1) || true
if echo "$NOTARIZE_OUT" | grep -q "status: Accepted"; then
  echo "Stapling notarization ticket…"
  xcrun stapler staple "${RELEASE}/${DMG_NAME}"
  echo "Done. DMG: ${RELEASE}/${DMG_NAME}"
else
  echo "Notarization may require manual setup (keychain profile, Apple ID). DMG created at: ${RELEASE}/${DMG_NAME}"
  echo "$NOTARIZE_OUT"
fi
