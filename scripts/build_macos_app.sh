#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="OrchestrationCLI.app"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE="${ORCH_APP_ICON:-$ROOT_DIR/assets/orchestration-cli.icns}"
SIGN_IDENTITY="${ORCH_CODESIGN_IDENTITY:--}"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

if [[ ! -f "$ICON_SOURCE" ]]; then
  if [[ -x "$ROOT_DIR/scripts/generate_default_icon.sh" ]]; then
    "$ROOT_DIR/scripts/generate_default_icon.sh"
  fi
fi

if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$RES_DIR/AppIcon.icns"
fi

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>ko</string>
  <key>CFBundleExecutable</key>
  <string>orchestration-cli-launcher</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>ai.openclaw.orchestration-cli</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>OrchestrationCLI</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.1.0</string>
  <key>CFBundleVersion</key>
  <string>2</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Terminal 실행을 위해 Apple Events 권한이 필요합니다.</string>
</dict>
</plist>
PLIST

cat > "$MACOS_DIR/orchestration-cli-launcher" <<EOF
#!/usr/bin/env bash
set -euo pipefail
"$ROOT_DIR/scripts/macos_app_entry.sh"
EOF
chmod +x "$MACOS_DIR/orchestration-cli-launcher"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null 2>&1 || true
fi

echo "[OK] App created: $APP_DIR"
if [[ -f "$RES_DIR/AppIcon.icns" ]]; then
  echo "[OK] Icon applied: $RES_DIR/AppIcon.icns"
else
  echo "[WARN] Icon not found. Set ORCH_APP_ICON=/path/to/icon.icns"
fi
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "[OK] Signed with ad-hoc identity (-)"
else
  echo "[OK] Signed with identity: $SIGN_IDENTITY"
fi
echo "[TIP] Finder에서 dist/OrchestrationCLI.app 더블클릭으로 실행하세요."
