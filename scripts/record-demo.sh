#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
if [ "$#" -ne 1 ]; then
    echo 'Usage: scripts/record-demo.sh <new-output-directory>' >&2
    exit 1
fi
mkdir -p "$1"
capture_output="$(cd "$1" && pwd)"
if [ -e "$capture_output/genie-native.mp4" ]; then
    echo 'Use a new output directory; an existing recording will not be overwritten.' >&2
    exit 1
fi
swift build --disable-sandbox -c release --product GenieCADemo
binary_dir="$(swift build -c release --show-bin-path)"
capture_root="$(mktemp -d "${TMPDIR:-/tmp}/genie-demo.XXXXXX")"
demo_app="$capture_root/Genie-CoreAnimation Demo.app"
mkdir -p "$demo_app/Contents/MacOS" "$demo_app/Contents/Resources"
cp "$binary_dir/GenieCADemo" "$demo_app/Contents/MacOS/GenieCADemo"
cp -R "$binary_dir/GenieWarpMesh_GenieCADemo.bundle" "$demo_app/Contents/Resources/"
cat > "$demo_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.geniecoreanimation.demo</string>
<key>CFBundleName</key><string>Genie-CoreAnimation Demo</string>
<key>CFBundleExecutable</key><string>GenieCADemo</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$demo_app"
echo 'Select only the Genie-CoreAnimation window in the system recording picker.'
open -n -W --stdout "$capture_output/recording.log" --stderr "$capture_output/recording.err" "$demo_app" --args --record "$capture_output"
cat "$capture_output/recording.log"
test -s "$capture_output/genie-native.mp4"
test -s "$capture_output/capture.json"
