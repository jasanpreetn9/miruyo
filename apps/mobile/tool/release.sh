#!/bin/sh
# Builds the App Store upload (.ipa): checks first, then a release build with
# the AniList client id baked in, obfuscated, with its debug symbols kept for
# reading crash reports.
#   tool/release.sh [build-number]
# The version name comes from pubspec.yaml; every upload needs a new build
# number (default: the one in pubspec.yaml).
set -e
cd "$(dirname "$0")/.."

config=config/anilist.json
if ! grep -q '"ANILIST_CLIENT_ID": *"[0-9]' "$config" 2>/dev/null; then
  echo "No AniList client id in $config (see config/anilist.example.json): a build without it can't log in." >&2
  exit 1
fi

tool/format.sh --output=none --set-exit-if-changed
flutter analyze
flutter test

version=$(sed -n 's/^version: *//p' pubspec.yaml)
build=${1:-${version#*+}}
symbols="symbols/${version%+*}+$build"

rm -rf build/ios/ipa
flutter build ipa --release \
  --dart-define-from-file="$config" \
  --build-number="$build" \
  --obfuscate --split-debug-info="$symbols"

# flutter build ipa can archive yet fail to export (no distribution
# certificate: the free personal team can't make App Store builds)
if ! ls build/ios/ipa/*.ipa >/dev/null 2>&1; then
  echo "The archive built, but no .ipa was exported. App Store builds need the paid Apple Developer team selected in Xcode (see PUBLISHING.md)." >&2
  exit 1
fi
echo
echo "Built build/ios/ipa/*.ipa (${version%+*} build $build); symbols in $symbols."
echo "Upload it with Transporter, or Xcode → Organizer → Distribute App."
