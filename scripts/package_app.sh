#!/usr/bin/env bash
#
# package_app.sh — build and package the macOS release app.
#
# Output (in dist/):
#   <name>-<version>.app   the runnable app bundle
#   <name>-<version>.zip   zip for direct distribution
#   <name>-<version>.dmg   drag-to-Applications disk image
#
# Usage:
#   scripts/package_app.sh             # incremental release build + package
#   scripts/package_app.sh --clean     # flutter clean first (fixes stale caches)
#   scripts/package_app.sh --no-dmg    # skip the .dmg (zip + .app only)
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

CLEAN=false
MAKE_DMG=true
for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN=true ;;
    --no-dmg) MAKE_DMG=false ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

command -v flutter >/dev/null || { echo "ERROR: flutter not on PATH" >&2; exit 1; }

VERSION="$(sed -n 's/^version: *\([^+ ]*\).*/\1/p' pubspec.yaml | head -1)"
[ -n "$VERSION" ] || { echo "ERROR: could not read version from pubspec.yaml" >&2; exit 1; }

DIST_DIR="$PROJECT_ROOT/dist"
RELEASE_DIR="$PROJECT_ROOT/build/macos/Build/Products/Release"

build() {
  flutter build macos --release
}

if $CLEAN; then
  echo "==> flutter clean"
  flutter clean
  flutter pub get
fi

echo "==> Building release app (version $VERSION)"
if ! build; then
  # Xcode/SDK upgrades leave Release intermediates pointing at a removed
  # SDK (e.g. "cannot open file '...MacOSX26.4.sdk...'"). A stale-cache
  # wipe fixes it without a full `flutter clean`.
  echo "==> Build failed — clearing stale macOS build cache and retrying once"
  rm -rf "$PROJECT_ROOT/build/macos"
  build
fi

APP_PATH="$(find "$RELEASE_DIR" -maxdepth 1 -name '*.app' -print -quit)"
[ -n "$APP_PATH" ] || { echo "ERROR: no .app found in $RELEASE_DIR" >&2; exit 1; }

# Verify the bundle is a universal (x86_64 + arm64) binary so it runs on Intel
# Macs too. Any framework missing x86_64 (e.g. an arm64-only Dart native-asset)
# would crash on Intel — fail loudly rather than ship a broken build.
echo "==> Verifying universal (x86_64 + arm64) binaries"
NON_UNIVERSAL=""
while IFS= read -r bin; do
  if file "$bin" 2>/dev/null | grep -q "Mach-O"; then
    if ! lipo -archs "$bin" 2>/dev/null | grep -qw x86_64; then
      NON_UNIVERSAL="$NON_UNIVERSAL\n    $(lipo -archs "$bin" 2>/dev/null | tr -s ' ')  ${bin#$APP_PATH/}"
    fi
  fi
done < <(find "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Frameworks" \
           -type f \( -perm -111 -o -path "*.framework/*" -o -name "*.dylib" \) 2>/dev/null)
if [ -n "$NON_UNIVERSAL" ]; then
  echo "ERROR: these binaries are not universal (missing x86_64):" >&2
  printf "%b\n" "$NON_UNIVERSAL" >&2
  echo "  → the app will crash on Intel Macs. See dependency_overrides in pubspec.yaml." >&2
  exit 1
fi
echo "    All binaries are universal."

APP_BASENAME="$(basename "$APP_PATH" .app)"
PKG_NAME="${APP_BASENAME}-${VERSION}"

echo "==> Packaging $PKG_NAME"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# 1. The .app itself (preserves signatures/attrs via ditto).
ditto "$APP_PATH" "$DIST_DIR/$PKG_NAME.app"

# 2. Zip for direct distribution.
ditto -c -k --keepParent "$DIST_DIR/$PKG_NAME.app" "$DIST_DIR/$PKG_NAME.zip"

# 3. Drag-to-Applications DMG.
if $MAKE_DMG; then
  STAGING="$(mktemp -d)"
  trap 'rm -rf "$STAGING"' EXIT
  ditto "$APP_PATH" "$STAGING/$APP_BASENAME.app"
  ln -s /Applications "$STAGING/Applications"
  hdiutil create -quiet -volname "$APP_BASENAME" \
    -srcfolder "$STAGING" -ov -format UDZO \
    "$DIST_DIR/$PKG_NAME.dmg"
fi

echo
echo "==> Done. Artifacts in dist/:"
ls -lh "$DIST_DIR" | awk 'NR>1 {printf "    %s  %s\n", $5, $9}'
echo
echo "Run it:      open \"$DIST_DIR/$PKG_NAME.app\""
$MAKE_DMG && echo "Install it:  open \"$DIST_DIR/$PKG_NAME.dmg\"  (drag to Applications)"
