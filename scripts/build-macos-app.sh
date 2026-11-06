#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="OfflineImageGenerator"
APP_BUNDLE="${PROJECT_DIR}/build/${APP_NAME}.app"
ICON_SOURCE="${PROJECT_DIR}/Resources/AppIcon-1024.png"
ICONSET_DIR="${PROJECT_DIR}/build/AppIcon.iconset"
ICNS_PATH="${PROJECT_DIR}/Resources/AppIcon.icns"

echo "==> 1. Generating macOS .icns icon from ${ICON_SOURCE}..."
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Ensure PNG format for iconutil
sips -s format png -z 16 16     "$ICON_SOURCE" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
sips -s format png -z 32 32     "$ICON_SOURCE" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
sips -s format png -z 32 32     "$ICON_SOURCE" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
sips -s format png -z 64 64     "$ICON_SOURCE" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
sips -s format png -z 128 128   "$ICON_SOURCE" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
sips -s format png -z 256 256   "$ICON_SOURCE" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
sips -s format png -z 256 256   "$ICON_SOURCE" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
sips -s format png -z 512 512   "$ICON_SOURCE" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
sips -s format png -z 512 512   "$ICON_SOURCE" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
sips -s format png -z 1024 1024 "$ICON_SOURCE" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
rm -rf "$ICONSET_DIR"
echo "    Created ${ICNS_PATH}"

echo "==> 2. Locating Release binary for Apple Silicon (arm64-apple-macosx)..."
if [[ -f "${PROJECT_DIR}/.build/out/Products/Release/${APP_NAME}" ]]; then
    BIN_PATH="${PROJECT_DIR}/.build/out/Products/Release/${APP_NAME}"
elif [[ -f "${PROJECT_DIR}/.build/arm64-apple-macosx/release/${APP_NAME}" ]]; then
    BIN_PATH="${PROJECT_DIR}/.build/arm64-apple-macosx/release/${APP_NAME}"
else
    swift build -c release --arch arm64
    BIN_PATH="$(swift build -c release --arch arm64 --show-bin-path)/${APP_NAME}"
fi

echo "==> 3. Packaging ${APP_BUNDLE}..."
rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "$BIN_PATH" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "$ICNS_PATH" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

cat > "${APP_BUNDLE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Image Generator</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.OfflineImageGenerator</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Image Generator</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

echo "==> 4. Signing ${APP_BUNDLE} (ad-hoc for local Apple Silicon execution)..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Done! Native Apple Silicon app bundle ready at:"
echo "    ${APP_BUNDLE}"
