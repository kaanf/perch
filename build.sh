#!/bin/bash
# Builds build/Perch.app.
#
#   ./build.sh                     sign with Kaan Firat's Developer ID certificate
#   IDENTITY="…" ./build.sh        sign with another certificate
#   IDENTITY=- ./build.sh          ad-hoc signing
#   CONFIGURATION=debug ./build.sh a debug build, with the mock tv:
#                                  open build/Perch.app --args --mock-tv playing --open
#
# A stable signing identity matters: the pairing keys live in the keychain, and
# macOS asks for the login password again whenever the signature changes.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Perch.app"
CONTENTS="$APP/Contents"
IDENTITY="${IDENTITY:-Developer ID Application: Kaan Firat (SGWP227GBQ)}"
CONFIGURATION="${CONFIGURATION:-release}"

# macOS grants local network access to the exact binary. Replace it under a
# running Perch and that copy is cut off from the tv for good, so quit it first.
pkill -x Perch 2>/dev/null || true

rm -rf build
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

echo "→ Perch"
swift build -c "$CONFIGURATION" --product Perch
cp "$(swift build -c "$CONFIGURATION" --show-bin-path)/Perch" "$CONTENTS/MacOS/Perch"
cp Resources/Info.plist "$CONTENTS/Info.plist"
cp Resources/AppIcon.icns "$CONTENTS/Resources/AppIcon.icns"

if [[ "$IDENTITY" != "-" ]] && ! security find-identity -v -p codesigning | grep -qF "\"$IDENTITY\""; then
    echo "warning: signing identity \"$IDENTITY\" not found, signing ad-hoc" >&2
    IDENTITY="-"
fi
SIGN_FLAGS=(--force --sign "$IDENTITY")
if [[ "$IDENTITY" == "Developer ID Application:"* ]]; then
    SIGN_FLAGS+=(--options runtime --timestamp)
fi

echo "→ codesign ($IDENTITY)"
xattr -cr "$APP"
codesign "${SIGN_FLAGS[@]}" "$APP"

echo "Built $APP — run with: open $APP"
