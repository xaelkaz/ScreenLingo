#!/bin/zsh

set -euo pipefail

ROOT_DIR="${0:A:h:h}"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$ROOT_DIR/dist/GameLingo.app"
CONTENTS_DIR="$APP_DIR/Contents"

mkdir -p "$BUILD_DIR/ModuleCache"
mkdir -p "$BUILD_DIR/Home"

HOME="$BUILD_DIR/Home" \
    CLANG_MODULE_CACHE_PATH="$BUILD_DIR/ModuleCache" \
    swift build --disable-sandbox --package-path "$ROOT_DIR" -c release \
        --product GameLingo -debug-info-format none

rm -rf "$APP_DIR"
mkdir -p "$ROOT_DIR/dist"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$BUILD_DIR/release/GameLingo" "$CONTENTS_DIR/MacOS/GameLingo"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

codesign --force --sign - --identifier "com.xbernikov.GameLingo" "$APP_DIR"

echo "$APP_DIR"
