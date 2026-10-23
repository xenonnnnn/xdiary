#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
BUILD_ROOT="$PROJECT_ROOT/.build/native"
APP_BUNDLE="$PROJECT_ROOT/dist/xdiary.app"
ICON_TEMP_ROOT="$BUILD_ROOT/xdiary-icon-temp"
STAGED_APP="$ICON_TEMP_ROOT/xdiary.app"
CONTENTS="$STAGED_APP/Contents"
ICON_CATALOG="$ICON_TEMP_ROOT/AppIcon.xcassets"
ICON_SET="$ICON_CATALOG/AppIcon.appiconset"

export CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_ROOT/module-cache"

rm -rf "$ICON_TEMP_ROOT"
mkdir -p "$BUILD_ROOT/module-cache"
trap 'rm -rf "$ICON_TEMP_ROOT"' EXIT

swift build \
  --package-path "$PROJECT_ROOT" \
  --disable-sandbox \
  --scratch-path "$BUILD_ROOT" \
  -c release

BIN_DIR="$(swift build \
  --package-path "$PROJECT_ROOT" \
  --scratch-path "$BUILD_ROOT" \
  -c release \
  --show-bin-path)"
NATIVE_BINARY="$BIN_DIR/xdiary"

if [[ ! -x "$NATIVE_BINARY" ]]; then
  print -u2 "Missing native executable: $NATIVE_BINARY"
  exit 1
fi

mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$ICON_SET"
install -m 755 "$NATIVE_BINARY" "$CONTENTS/MacOS/xdiary"
cp "$PROJECT_ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

swift "$PROJECT_ROOT/scripts/generate-native-icon.swift" "$ICON_TEMP_ROOT/AppIcon-1024.png"
cp "$PROJECT_ROOT/Resources/AppIcon.xcassets/AppIcon.appiconset/Contents.json" "$ICON_SET/Contents.json"

for entry in \
  "16 icon_16x16.png" \
  "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" \
  "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" \
  "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" \
  "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" \
  "1024 icon_512x512@2x.png"; do
  size="${entry%% *}"
  name="${entry#* }"
  sips -z "$size" "$size" "$ICON_TEMP_ROOT/AppIcon-1024.png" --out "$ICON_SET/$name" >/dev/null
done

xcrun actool "$ICON_CATALOG" \
  --compile "$CONTENTS/Resources" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$ICON_TEMP_ROOT/AppIcon-Partial.plist" \
  >/dev/null

codesign --force --deep --sign - --timestamp=none "$STAGED_APP" >/dev/null

mkdir -p "$PROJECT_ROOT/dist"
rm -rf "$APP_BUNDLE"
mv "$STAGED_APP" "$APP_BUNDLE"

print "Built $APP_BUNDLE"
