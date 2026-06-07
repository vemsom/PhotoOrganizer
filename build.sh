#!/bin/bash
# Bygger PhotoOrganizer.app direkt med swiftc – ingen Xcode behövs.
# Resultat: PhotoOrganizer.app i projektets rot.

set -e

cd "$(dirname "$0")"
ROOT="$(pwd)"
APP_NAME="PhotoOrganizer"
APP_BUNDLE="$ROOT/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
SRC_DIR="$ROOT/$APP_NAME"

echo "==> Rensar tidigare build"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

echo "==> Kompilerar Swift-källkod"
SWIFT_FILES=$(find "$SRC_DIR" -name "*.swift" -type f)

SDK_PATH="$(xcrun --show-sdk-path --sdk macosx 2>/dev/null || echo "")"
if [ -z "$SDK_PATH" ]; then
  echo "FEL: kan inte hitta macOS SDK"
  exit 1
fi

swiftc \
  -sdk "$SDK_PATH" \
  -target arm64-apple-macos13.0 \
  -O \
  -parse-as-library \
  -module-name "$APP_NAME" \
  -o "$MACOS_DIR/$APP_NAME" \
  $SWIFT_FILES

echo "==> Kopierar ikon"
cp "$SRC_DIR/icon.icns" "$RESOURCES_DIR/"

echo "==> Skriver Info.plist"
cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>PhotoOrganizer</string>
    <key>CFBundleDisplayName</key>
    <string>PhotoOrganizer</string>
    <key>CFBundleIdentifier</key>
    <string>se.fredrik.PhotoOrganizer</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>PhotoOrganizer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>CFBundleIconFile</key>
    <string>icon</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.photography</string>
</dict>
</plist>
PLIST

echo "==> Kopierar dnglab till Resources"
cp "$SRC_DIR/Resources/dnglab" "$RESOURCES_DIR/dnglab"
chmod +x "$RESOURCES_DIR/dnglab"

echo "==> Ad-hoc-signerar bundlen"
# Signera dnglab först, sedan hela appen
codesign --force --sign - "$RESOURCES_DIR/dnglab"
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "✓ Klart!"
echo "  App:   $APP_BUNDLE"
echo "  Kör:   open '$APP_BUNDLE'"
