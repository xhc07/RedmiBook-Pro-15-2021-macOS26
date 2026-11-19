#!/bin/bash
# 合盖状态采样器：记录 AppleClamshellState 变化（用于验证 MIFSLid 等）
# 用法: ./lidwatch.sh [时长秒数，默认 90]
DUR="${1:-90}"
N=$(( DUR * 2 ))
OUT="/tmp/lidwatch-$(date +%Y%m%d-%H%M%S).log"
echo "采样 $DUR 秒，输出: $OUT"
echo "请在期间合上盖子再打开"
: > "$OUT"
prev=""
for i in $(seq 1 $N); do
  S=$(ioreg -l -w0 -n IOPMrootDomain 2>/dev/null | grep -oE '"AppleClamshellState" = [A-Za-z]+' | head -1 | awk '{print $3}')
  L=$(ioreg -rc AppleACPILid -l -w0 2>/dev/null | grep -oE '"LidOpen" = [A-Za-z]+' | head -1 | awk '{print $3}')
  line="$(date '+%H:%M:%S')  clamshell=${S:-?}  lidOpen=${L:-?}"
  echo "$line" >> "$OUT"
  [ "${S:-?}" != "$prev" ] && echo "  $line" && prev="${S:-?}"
  sleep 0.5
done
echo "完成，结果: $OUT"
