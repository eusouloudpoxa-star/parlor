#!/bin/bash
# Builds Parlor and exports an IPA.
# Signing:
#   - Leave teamID as YOUR_TEAM_ID to get an unsigned IPA you sign with
#     Sideloadly/AltStore using a free Apple ID (7-day cert, re-sign on expiry).
#   - Or set your teamID in exportOptions.plist for a signed development IPA.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not found — installing via Homebrew."
  brew install xcodegen
fi

xcodegen

xcodebuild -project Parlor.xcodeproj -scheme Parlor -configuration Release \
  -archivePath build/Parlor.xcarchive \
  archive \
  CODE_SIGNING_ALLOWED=NO

TEAM_ID=$(/usr/libexec/PlistBuddy -c "Print :teamID" exportOptions.plist)

if [ "$TEAM_ID" = "YOUR_TEAM_ID" ]; then
  echo "teamID not set — building unsigned IPA."
  rm -rf build/Payload
  mkdir -p build/Payload
  cp -R "build/Parlor.xcarchive/Products/Applications/Parlor.app" build/Payload/
  (cd build && zip -qry Parlor-unsigned.ipa Payload)
  echo "Done: build/Parlor-unsigned.ipa — sign with Sideloadly or AltStore (free Apple ID)."
else
  xcodebuild -exportArchive \
    -archivePath build/Parlor.xcarchive \
    -exportPath build/export \
    -exportOptionsPlist exportOptions.plist
  echo "Done: build/export/Parlor.ipa"
fi
