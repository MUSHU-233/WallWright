#!/bin/bash
# 改版本号。会同时更新两个地方，避免它们不一致：
#   1. Resources/Info.plist      —— 打包后 App 实际读取的值（唯一有效的来源）
#   2. 工程的 MARKETING_VERSION   —— Xcode "General" 页面显示的版本，本项目不用它，但同步一下免得看着困惑
#
# 用法：
#   ./scripts/set_version.sh 1.1        # 版本 1.1，build 号自动 +1
#   ./scripts/set_version.sh 1.1 3      # 版本 1.1，build 号指定为 3
set -euo pipefail

cd "$(dirname "$0")/.."

if [ $# -lt 1 ]; then
    echo "用法: ./scripts/set_version.sh <版本号> [build号]"
    echo "例如: ./scripts/set_version.sh 1.1"
    exit 1
fi

VERSION="$1"
PLIST="Resources/Info.plist"
PBX="WallWright.xcodeproj/project.pbxproj"
SED=/usr/bin/sed

[ -f "$PLIST" ] || { echo "✗ 找不到 $PLIST"; exit 1; }

# build 号：显式给了就用，否则在原来的基础上 +1
if [ $# -ge 2 ]; then
    BUILD="$2"
else
    OLD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST" 2>/dev/null || echo 0)
    BUILD=$(( OLD + 1 ))
fi

# 用 sed 只替换值，不动文件其它格式（PlistBuddy 会把整个文件重排成 tab 缩进）
tmp=$(mktemp)
$SED -E "/<key>CFBundleShortVersionString<\/key>/{n;s|<string>[^<]*</string>|<string>${VERSION}</string>|;}" "$PLIST" > "$tmp"
cat "$tmp" > "$PLIST"
$SED -E "/<key>CFBundleVersion<\/key>/{n;s|<string>[^<]*</string>|<string>${BUILD}</string>|;}" "$PLIST" > "$tmp"
cat "$tmp" > "$PLIST"
rm -f "$tmp"

if [ -f "$PBX" ]; then
    tmp=$(mktemp)
    $SED -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = ${VERSION};/g;s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = ${BUILD};/g" "$PBX" > "$tmp"
    cat "$tmp" > "$PBX"
    rm -f "$tmp"
fi

echo "✓ 版本已更新：$VERSION (build $BUILD)"
echo "  下一步：./scripts/build.sh 重新打包，或在 Xcode 里 ⌘R"
