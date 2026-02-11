#!/usr/bin/env bash
# install-app.sh — Build Pulse with logo icon and install to /Applications
# Usage: ./Scripts/install-app.sh

set -e
cd "$(dirname "$0")/.."
NAME=Pulse
APP_NAME=${NAME}.app
RELEASE=.build/release

echo "Building…"
swift build -c release

echo "Generating app icon…"
./Scripts/generate-icon.sh

echo "Creating .app bundle…"
rm -rf "${RELEASE}/${APP_NAME}"
mkdir -p "${RELEASE}/${APP_NAME}/Contents/MacOS"
mkdir -p "${RELEASE}/${APP_NAME}/Contents/Resources"
cp "${RELEASE}/${NAME}" "${RELEASE}/${APP_NAME}/Contents/MacOS/"
cp Sources/Pulse/Resources/logo.svg "${RELEASE}/${APP_NAME}/Contents/Resources/"
cp .build/AppIcon.icns "${RELEASE}/${APP_NAME}/Contents/Resources/"

cat > "${RELEASE}/${APP_NAME}/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>Pulse</string>
	<key>CFBundleIdentifier</key><string>com.pulse.app</string>
	<key>CFBundleName</key><string>Pulse</string>
	<key>CFBundleDisplayName</key><string>Pulse</string>
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

echo "Installing to /Applications…"
rm -rf "/Applications/${APP_NAME}"
cp -R "${RELEASE}/${APP_NAME}" /Applications/

# Ad-hoc sign (remove entitlements to avoid signing issues for local install)
rm -f "/Applications/${APP_NAME}/Contents/Pulse.entitlements" 2>/dev/null
codesign -s - --force "/Applications/${APP_NAME}" 2>/dev/null || true

echo "Done. Open /Applications/Pulse.app"
