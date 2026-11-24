#!/usr/bin/env bash
# Gera todos os ícones da Ronic MacToWindows a partir de branding/make-icons.swift.
# Rode no macOS:  ./branding/make-icons.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/branding/out"
rm -rf "$OUT"
swift "$ROOT/branding/make-icons.swift" "$OUT"

# README / GitHub
cp "$OUT/logo-512.png" "$ROOT/branding/logo.png"

# macOS (.icns)
ICONSET="$ROOT/build/RonicMacToWindows.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  cp "$OUT/logo-$s.png" "$ICONSET/icon_${s}x${s}.png"
  d=$((s * 2)); cp "$OUT/logo-$d.png" "$ICONSET/icon_${s}x${s}@2x.png"
done
iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"
echo "OK"
