#!/bin/sh
# Regenerates every app icon from tool/make_icon.swift: the iOS AppIcon set
# (each size its Contents.json names) and the Android launcher mipmaps.
set -e
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
# opaque from the start (no alpha, as the App Store requires)
swift tool/make_icon.swift "$tmp/master.png" 1024

ios=ios/Runner/Assets.xcassets/AppIcon.appiconset
for file in "$ios"/Icon-App-*.png; do
  name=$(basename "$file" .png)          # Icon-App-83.5x83.5@2x
  pts=${name#Icon-App-}; pts=${pts%%x*}  # 83.5
  scale=${name##*@}; scale=${scale%x}    # 2
  px=$(echo "$pts * $scale" | bc | cut -d. -f1)
  # each size drawn at that size, not scaled down from 1024: crisper small icons
  swift tool/make_icon.swift "$file" "$px"
done

for pair in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  swift tool/make_icon.swift "android/app/src/main/res/mipmap-${pair%%:*}/ic_launcher.png" "${pair#*:}"
done
# the launch screen's mark: 96pt / 96dp, rounded
launch=ios/Runner/Assets.xcassets/LaunchImage.imageset
for scale in 1 2 3; do
  suffix=$([ "$scale" = 1 ] && echo "" || echo "@${scale}x")
  swift tool/make_icon.swift "$launch/LaunchImage$suffix.png" $((96 * scale)) mark
done
mkdir -p android/app/src/main/res/drawable-xxxhdpi
swift tool/make_icon.swift android/app/src/main/res/drawable-xxxhdpi/launch_mark.png 384 mark

rm -rf "$tmp"
echo "icons written"
