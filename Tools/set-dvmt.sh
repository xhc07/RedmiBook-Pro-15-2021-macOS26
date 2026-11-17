#!/bin/bash
# 读取/修改隐藏的 DVMT Pre-Allocated（Insyde BIOS，SaSetup 偏移 0x84）
# 参考: macOS-for-RedmiBook-Pro-15-2021 的同名脚本
# 用法: sudo ./set-dvmt.sh show | 128 | 96 | 64 | 60
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "需要 root"; exit 1; }
V="72C5E28C-7783-43A1-8767-FAD73FCCAFA4:SaSetup"
OFF=$((0x84)); SIZE=$((0x430))
cur=$(mktemp); nvram -x "$V" > /tmp/sas.plist 2>/dev/null || { echo "✗ 读不到 SaSetup 变量"; exit 1; }
plutil -extract "$V" raw -o - /tmp/sas.plist | base64 -D > "$cur"
[ "$(stat -f %z "$cur")" -eq $SIZE ] || { echo "✗ 变量大小不是 0x430，BIOS 版本不符，停止"; exit 1; }
val=$(xxd -s $OFF -l1 -p "$cur")
case "${1:-show}" in
  show) echo "DVMT 字节 = 0x$val  (fe=60M 02=64M 03=96M 04=128M 05=160M)";;
  60|64|96|128|160)
    declare -A m=([60]=fe [64]=02 [96]=03 [128]=04 [160]=05)
    new="${m[$1]}"; cp "$cur" /tmp/sas.bak
    printf "\\x$new" | dd of="$cur" bs=1 seek=$OFF conv=notrunc status=none
    hex=$(xxd -p -c1 "$cur" | sed 's/^/%/' | tr -d '\n')
    nvram "$V=$hex"
    echo "✓ 已写入 0x$new（原 0x$val），重启生效";;
  *) echo "用法: $0 show|60|64|96|128|160"; exit 1;;
esac
