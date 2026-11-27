#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
VOLNAME="WallWright"
STAGE=".build/dmg-stage"
RW=".build/WallWright-rw.dmg"
OUT="dist/WallWright-$VERSION.dmg"
APP=".build/xcode/Build/Products/Release/WallWright.app"
MNT="/Volumes/$VOLNAME"

echo "▸ Release 编译 (v$VERSION)"
xcodebuild -project WallWright.xcodeproj -scheme WallWright \
    -configuration Release -derivedDataPath .build/xcode \
    OTHER_SWIFT_FLAGS="-disable-sandbox" build \
    | grep -E "error:|BUILD" || true

[ -d "$APP" ] || { echo "✗ 编译产物不存在"; exit 1; }

echo "▸ 准备暂存目录"
rm -rf "$STAGE" "$RW" "$OUT"
mkdir -p "$STAGE" dist
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "▸ 创建可读写镜像"
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE" -ov -format UDRW -fs HFS+ "$RW" >/dev/null

echo "▸ 挂载"
[ -d "$MNT" ] && hdiutil detach "$MNT" -force >/dev/null 2>&1 || true
hdiutil attach "$RW" -nobrowse >/dev/null

echo "▸ 排版（失败可忽略，仅影响图标位置）"
osascript <<EOF >/dev/null 2>&1 || echo "  (跳过：未获得 Finder 自动化权限)"
tell application "Finder"
    tell disk "$VOLNAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 180, 900, 540}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 110
        set position of item "WallWright.app" of container window to {130, 180}
        set position of item "Applications" of container window to {390, 180}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

echo "▸ 卸载并压缩"
hdiutil detach "$MNT" -force >/dev/null
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "${OUT%.dmg}" >/dev/null

echo "▸ 签名"
codesign --force --sign - "$OUT"

echo "▸ 验证"
hdiutil attach "$OUT" -nobrowse >/dev/null
ls -l "$MNT"
hdiutil detach "$MNT" -force >/dev/null

echo "✓ 完成：$OUT ($(du -h "$OUT" | cut -f1))"
