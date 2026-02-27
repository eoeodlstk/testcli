#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET_DIR="$ROOT_DIR/assets/OrchestrationCLI.iconset"
ICNS_OUT="$ROOT_DIR/assets/orchestration-cli.icns"

mkdir -p "$ICONSET_DIR"

# Create a simple gradient background PNGs using sips-compatible base from AppleScript/JXA rendering via qlmanage fallback.
TMP_PNG="$ROOT_DIR/assets/icon-1024.png"

TMP_PNG="$TMP_PNG" osascript -l JavaScript <<'JXA'
ObjC.import('Cocoa');
ObjC.import('stdlib');
const size = 1024;
const rect = $.NSMakeRect(0,0,size,size);
const image = $.NSImage.alloc.initWithSize($.NSMakeSize(size,size));
image.lockFocus;

const color1 = $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.17,0.37,0.95,1.0);
const color2 = $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.41,0.13,0.92,1.0);
const grad = $.NSGradient.alloc.initWithStartingColorEndingColor(color1, color2);
grad.drawInRectAngle(rect, 45);

const rocket = "🚀";
const attrs = $.NSMutableDictionary.alloc.init;
attrs.setObjectForKey($.NSFont.systemFontOfSizeWeight(500, $.NSFontWeightBold), $.NSFontAttributeName);
attrs.setObjectForKey($.NSColor.whiteColor, $.NSForegroundColorAttributeName);

const str = $.NSString.stringWithString(rocket);
const textSize = str.sizeWithAttributes(attrs);
const point = $.NSMakePoint((size-textSize.width)/2, (size-textSize.height)/2 - 30);
str.drawAtPointWithAttributes(point, attrs);

image.unlockFocus;
const tiff = image.TIFFRepresentation;
const rep = $.NSBitmapImageRep.imageRepWithData(tiff);
const png = rep.representationUsingTypeProperties($.NSBitmapImageFileTypePNG, $({}));
const outPath = $.getenv('TMP_PNG');
png.writeToFileAtomically($.NSString.stringWithUTF8String(outPath), true);
JXA

# Export iconset sizes
for sz in 16 32 64 128 256 512; do
  sips -z "$sz" "$sz" "$TMP_PNG" --out "$ICONSET_DIR/icon_${sz}x${sz}.png" >/dev/null
  sips -z $((sz*2)) $((sz*2)) "$TMP_PNG" --out "$ICONSET_DIR/icon_${sz}x${sz}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$ICNS_OUT"
rm -rf "$ICONSET_DIR"

echo "[OK] Default icon created: $ICNS_OUT"
