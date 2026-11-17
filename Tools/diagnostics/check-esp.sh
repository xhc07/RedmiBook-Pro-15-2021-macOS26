#!/bin/bash
# 挂载/修复 ESP（FAT32），并在需要时报告占用与异常文件
# 用法: sudo ./check-esp.sh [diskXsY]   （不填则自动找 200MB 的 EFI 分区）
set -u
[ "$EUID" -eq 0 ] || { echo "需要 root"; exit 1; }
ESP="${1:-$(diskutil list 2>/dev/null | awk '/EFI EFI/ && $0 ~ /209\.7 MB/ {print $NF}' | head -1)}"
[ -n "$ESP" ] || { echo "✗ 找不到 EFI 分区"; exit 1; }
echo "目标: $ESP"
diskutil unmount force "$ESP" 2>/dev/null
fsck_msdos -fy "/dev/r${ESP}" 2>&1 | tail -3
diskutil mount "$ESP" >/dev/null 2>&1
MP=$(diskutil info "$ESP" | awk -F': *' '/Mount Point/ {print $2}')
[ -n "$MP" ] || { echo "✗ 挂载失败（可能需要多次 fsck）"; exit 1; }
echo "挂载点: $MP"
echo "占用: $(du -sh "$MP/EFI" 2>/dev/null | cut -f1) / 可用 $(df -h "$MP" | awk 'NR==2{print $4}')"
for junk in .Spotlight-V100 .Trashes .fseventsd .metadata_never_index; do
  [ -e "$MP/$junk" ] && echo "  ⚠ 存在 $junk"
done
[ -f "$MP/EFI/OC/config.plist" ] && echo "  ✓ config.plist 存在（$(plutil -lint "$MP/EFI/OC/config.plist" >/dev/null 2>&1 && echo 合法 || echo 非法)）"
