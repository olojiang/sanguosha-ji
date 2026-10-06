#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
dist_dir="$project_dir/dist"
app_dir="$project_dir/dist/三国杀 Ji.app"
staging_dir=""
icon_source="$project_dir/Resources/AppIcon.png"

cd "$project_dir"
swift build -c release --product SanguoshaJi
codesign --verify --strict "$project_dir/.build/release/SanguoshaJi"
staging_dir="$(mktemp -d "$project_dir/.build/package.XXXXXX")"
trap '[[ -z "$staging_dir" ]] || rm -rf "$staging_dir"' EXIT
staged_app="$staging_dir/三国杀 Ji.app"
contents_dir="$staged_app/Contents"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$project_dir/.build/release/SanguoshaJi" "$contents_dir/MacOS/SanguoshaJi"
cp "$project_dir/Sources/SanguoshaApp/Resources/CardArt.png" "$contents_dir/Resources/CardArt.png"
cat > "$contents_dir/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>SanguoshaJi</string>
    <key>CFBundleIdentifier</key><string>local.codex.sanguosha-ji</string>
    <key>CFBundleName</key><string>三国杀 Ji</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST
iconset_dir="$project_dir/.build/AppIcon.iconset"
rm -rf "$iconset_dir"
mkdir -p "$iconset_dir" "$contents_dir/Resources"
for size in 16 32 128 256 512; do
    doubled=$((size * 2))
    sips -z "$size" "$size" "$icon_source" --out "$iconset_dir/icon_${size}x${size}.png" >/dev/null
    sips -z "$doubled" "$doubled" "$icon_source" --out "$iconset_dir/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil --convert icns --output "$contents_dir/Resources/AppIcon.icns" "$iconset_dir"
plutil -replace CFBundleIconFile -string AppIcon "$contents_dir/Info.plist"
codesign --force --sign - --timestamp=none "$staged_app"
codesign --verify --deep --strict "$staged_app"
# Never overwrite a running executable in place; macOS can kill it after its
# signed code pages stop matching the on-disk binary.
mkdir -p "$dist_dir" "$project_dir/.build/package-backups"
backup_app="$project_dir/.build/package-backups/三国杀 Ji-$(date +%s)-$$.app"
if [[ -e "$app_dir" ]]; then mv "$app_dir" "$backup_app"; fi
mv "$staged_app" "$app_dir"
rmdir "$(dirname "$staged_app")"
staging_dir=""
if ! pgrep -x SanguoshaJi >/dev/null 2>&1; then rm -rf "$backup_app"; fi
echo "Created $app_dir"
