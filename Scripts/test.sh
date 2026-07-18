#!/bin/zsh

set -euo pipefail

ROOT_DIR="${0:A:h:h}"
mkdir -p "$ROOT_DIR/.build/ModuleCache"
mkdir -p "$ROOT_DIR/.build/Home"

HOME="$ROOT_DIR/.build/Home" \
    CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/ModuleCache" \
    swift run --disable-sandbox --package-path "$ROOT_DIR" ScreenLingoChecks
