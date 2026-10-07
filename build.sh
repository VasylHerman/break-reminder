#!/bin/zsh
# Usage: ./build.sh [build|bundle|run|install]
set -euo pipefail
cd "$(dirname "$0")"

APP=BreakReminder
DIST=dist
BUNDLE="$DIST/$APP.app"

build() {
  swift build -c release
}

bundle() {
  build
  rm -rf "$BUNDLE"
  mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
  cp ".build/release/$APP" "$BUNDLE/Contents/MacOS/$APP"
  cp Support/Info.plist "$BUNDLE/Contents/Info.plist"
  # Ad-hoc signature: enough for Notification Center and launch-at-login on the local machine.
  codesign --force --sign - "$BUNDLE"
  echo "Bundle ready: $BUNDLE"
}

run() {
  bundle
  pkill -x "$APP" 2>/dev/null || true
  open "$BUNDLE"
}

install() {
  bundle
  pkill -x "$APP" 2>/dev/null || true
  rm -rf "/Applications/$APP.app"
  cp -R "$BUNDLE" /Applications/
  open "/Applications/$APP.app"
  echo "Installed to /Applications/$APP.app"
}

case "${1:-bundle}" in
  build)   build ;;
  bundle)  bundle ;;
  run)     run ;;
  install) install ;;
  *) echo "usage: $0 [build|bundle|run|install]" >&2; exit 1 ;;
esac
