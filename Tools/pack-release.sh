#!/bin/bash
# 用 7-Zip 打包发布 zip（确保中文文件名 UTF-8 正确）
# 用法: ./Tools/pack-release.sh <git-ref> [输出目录]
#   例: ./Tools/pack-release.sh v0.3.0 ~/Desktop/releases
set -euo pipefail
REF="${1:?用法: $0 <git-ref> [输出目录]}"
OUT="${2:-$HOME/Desktop/releases}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
NAME="RedmiBook-Pro-15-2021-macOS26"

# 找 7zz
ZZ=""
for c in 7zz /tmp/7z/7zz /usr/local/bin/7zz /opt/homebrew/bin/7zz; do
  [ -x "$c" ] && { ZZ="$c"; break; }
  command -v "$c" >/dev/null 2>&1 && { ZZ="$(command -v "$c")"; break; }
done
[ -n "$ZZ" ] || { echo "✗ 找不到 7zz（下载：https://github.com/ip7z/7zip/releases ）"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/$NAME"
echo "== 导出 $REF =="
( cd "$HERE" && git archive --format=tar "$REF" ) | tar -x -C "$WORK/$NAME"
VER="$(cd "$WORK/$NAME" && /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' EFI/OC/Kexts/WhateverXe.kext/Contents/Info.plist 2>/dev/null || echo unknown)"
ZIP="$OUT/$NAME-$REF.zip"
mkdir -p "$OUT"
rm -f "$ZIP"
echo "== 7-Zip 打包（UTF-8 文件名）=="
( cd "$WORK" && "$ZZ" a -tzip -mcu=on "$ZIP" "$NAME" >/dev/null )
echo "  ✓ $ZIP"
ls -lh "$ZIP" | awk '{print "  大小: "$5}'

echo "== 验证 =="
TMPV="$(mktemp -d)"
( cd "$TMPV" && "$ZZ" x -y . >/dev/null 2>&1 <<< "" ) || true
( cd "$TMPV" && "$ZZ" x -y "$ZIP" >/dev/null 2>&1 )
N=$(ls -1 "$TMPV/$NAME/docs/" 2>/dev/null | wc -l | tr -d ' ')
echo "  docs 文件数: $N"
echo "  WhateverXe: $VER"
[ "$N" -ge 8 ] || { echo "  ✗ 解压校验失败"; exit 1; }
rm -rf "$TMPV"
