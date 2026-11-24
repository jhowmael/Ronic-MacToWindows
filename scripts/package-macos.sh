#!/usr/bin/env bash
# Empacota a Ronic MacToWindows:
#   dist/RonicMacToWindows.app
#   dist/RonicMacToWindows-macOS.zip   (pronto para anexar no GitHub Releases)
#
# Variáveis opcionais:
#   VERSION=1.1.0            versão gravada no Info.plist
#   UNIVERSAL=1              binário universal (arm64 + x86_64) — requer Xcode completo
#   SIGN_IDENTITY="Developer ID Application: Fulano (TEAMID)"   assinatura real (padrão: ad-hoc "-")
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.1.0}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
DIST="$ROOT/dist"
APP="$DIST/RonicMacToWindows.app"

echo "==> Ronic MacToWindows $VERSION"
rm -rf "$APP"
mkdir -p "$DIST"

# 1) Compila (release, otimizado)
SWIFT_ARGS=(-c release --package-path "$ROOT")
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  SWIFT_ARGS+=(--arch arm64 --arch x86_64)
fi
swift build "${SWIFT_ARGS[@]}"
BIN_DIR="$(swift build "${SWIFT_ARGS[@]}" --show-bin-path)"

# 2) Monta o bundle .app
echo "==> Montando $APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/RonicMacToWindows" "$APP/Contents/MacOS/RonicMacToWindows"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp -R "$ROOT/Resources/Layouts" "$APP/Contents/Resources/Layouts"   # layouts de pontuação estilo Windows
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$(date +%Y%m%d%H%M)" "$APP/Contents/Info.plist"
strip -x "$APP/Contents/MacOS/RonicMacToWindows" 2>/dev/null || true

# 3) Assinatura (ad-hoc por padrão)
echo "==> Assinando ($SIGN_IDENTITY)"
SIGN_FLAGS=(--force --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  SIGN_FLAGS+=(--options runtime --timestamp)
fi
codesign "${SIGN_FLAGS[@]}" "$APP"
codesign --verify --strict "$APP"

# 4) Zip para o GitHub Releases (ditto preserva assinatura e atributos)
ZIP="$DIST/RonicMacToWindows-macOS.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo
echo "Pronto:"
echo "  App: $APP"
echo "  Zip: $ZIP"
echo "Abra com: open \"$APP\""
