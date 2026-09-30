#!/bin/bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
VERSION="${VERSION:-0.1.0}"
ARCH="${ARCH:-$(uname -m)}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO/dist/macos-$ARCH}"
NODE_ROOT="${NODE_ROOT:-}"
if [[ -z "$NODE_ROOT" || ! -x "$NODE_ROOT/bin/node" || ! -f "$NODE_ROOT/LICENSE" ]]; then
  printf '%s\n' 'NODE_ROOT must be a Node.js 24 distribution directory containing bin/node and LICENSE.' >&2
  exit 1
fi
if [[ "$ARCH" != arm64 && "$ARCH" != x86_64 ]]; then
  printf '%s\n' 'ARCH must be arm64 or x86_64.' >&2
  exit 1
fi
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf '%s\n' 'VERSION must contain three numeric components.' >&2
  exit 1
fi
if ! /usr/bin/lipo -verify_arch "$ARCH" "$NODE_ROOT/bin/node" >/dev/null 2>&1; then
  printf 'Bundled Node does not contain the requested architecture: %s\n' "$ARCH" >&2
  exit 1
fi
NODE_MAJOR="$("$NODE_ROOT/bin/node" -p 'Number(process.versions.node.split(".")[0])')"
if [[ "$NODE_MAJOR" != 24 ]]; then
  printf '%s\n' 'The prebuilt app requires a Node.js 24 distribution.' >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd -P)"
DEST="$OUTPUT_DIR/Codex Quota Widget.app"
if [[ -e "$DEST" ]]; then
  printf 'Output already exists; use an empty OUTPUT_DIR: %s\n' "$DEST" >&2
  exit 1
fi
WORK="$(mktemp -d "${TMPDIR:-/tmp}/codex-quota-build.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
APP="$WORK/Codex Quota Widget.app"
HELPER="$APP/Contents/Helpers/QuotaWidget.app"
SERVICE="$APP/Contents/Resources/service"
mkdir -p "$APP/Contents/MacOS" "$HELPER/Contents/MacOS" "$SERVICE/runtime" "$WORK/module-cache"
export CLANG_MODULE_CACHE_PATH="$WORK/module-cache"
export SWIFT_MODULE_CACHE_PATH="$WORK/module-cache"
SDK="${SDKROOT:-$(/usr/bin/xcrun --sdk macosx --show-sdk-path)}"
if [[ -z "${SDKROOT:-}" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk; fi
SWIFT_ARGS=(-parse-as-library -O -target "$ARCH-apple-macosx13.0" -sdk "$SDK" -module-cache-path "$WORK/module-cache" -framework AppKit)
/usr/bin/xcrun swiftc "${SWIFT_ARGS[@]}" "$REPO/macos/NativeSupport.swift" "$REPO/macos/DockLauncher.swift" -o "$APP/Contents/MacOS/Launch"
/usr/bin/xcrun swiftc "${SWIFT_ARGS[@]}" -framework WebKit "$REPO/macos/NativeSupport.swift" "$REPO/macos/MacWidget.swift" -o "$HELPER/Contents/MacOS/CodexQuota"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Launch</string>
<key>CFBundleIdentifier</key><string>local.codex.weeklymonitor.launcher</string>
<key>CFBundleName</key><string>Codex Quota Widget</string>
<key>CFBundleDisplayName</key><string>Codex Quota Widget</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>CFBundleIconFile</key><string>CodexQuota.icns</string>
<key>LSMinimumSystemVersion</key><string>13.5</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST
cat > "$HELPER/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CodexQuota</string>
<key>CFBundleIdentifier</key><string>local.codex.weeklymonitor</string>
<key>CFBundleName</key><string>Codex Quota Widget Helper</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>13.5</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST

# Copy runtime inputs explicitly; source-only material and credentials do not ship.
cp "$REPO"/macos/*.mjs "$SERVICE/"
cp -R "$REPO/macos/public" "$SERVICE/public"
cp "$REPO/macos/Start.command" "$REPO/macos/Stop.command" "$SERVICE/"
cp "$NODE_ROOT/bin/node" "$SERVICE/runtime/node"
cp "$NODE_ROOT/LICENSE" "$SERVICE/runtime/LICENSE"
cp "$REPO/LICENSE" "$REPO/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/"
chmod +x "$SERVICE/Start.command" "$SERVICE/Stop.command" "$SERVICE/runtime/node"

"$APP/Contents/MacOS/Launch" --icon-png "$WORK/CodexQuota.png"
/usr/bin/sips -s format icns "$WORK/CodexQuota.png" --out "$APP/Contents/Resources/CodexQuota.icns" >/dev/null
/usr/bin/plutil -lint "$APP/Contents/Info.plist" "$HELPER/Contents/Info.plist" >/dev/null
# Local integrity signing only. This is not Developer ID signing or notarization.
/usr/bin/codesign --force --sign - "$SERVICE/runtime/node"
/usr/bin/codesign --force --sign - "$HELPER"
/usr/bin/codesign --force --sign - "$APP"
/usr/bin/codesign --verify --deep --strict "$APP"

/usr/bin/ditto "$APP" "$DEST"
printf '%s\n' "$DEST"
