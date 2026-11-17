#!/bin/bash
# Fn 键探测：同时抓 HID 事件 + 亮度变化，结束后自动汇总
# 用法: ./fnprobe.sh [秒数]        默认 60 秒
#       ./fnprobe.sh 90
# 输出: /tmp/fnprobe_hid.log  /tmp/fnprobe_bright.log
set -u
DUR="${1:-60}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BIN="$ROOT/Tools/diagnostics/hidsniff"
[ -x "$BIN" ] || BIN="$(command -v hidsniff || true)"
[ -x "$BIN" ] || { echo "✗ 找不到 hidsniff（应在 Tools/diagnostics/ 下）"; exit 1; }

HIDLOG=/tmp/fnprobe_hid.log
BRLOG=/tmp/fnprobe_bright.log
: > "$HIDLOG"; : > "$BRLOG"

echo "== 抓取 ${DUR} 秒 =="
echo "   HID   → $HIDLOG"
echo "   亮度  → $BRLOG"
echo "   ▶ 现在开始按键；结束后按 Ctrl+C 或等自动结束"
echo

"$BIN" >> "$HIDLOG" 2>&1 &
HP=$!
(
  PREV=""
  END=$(( $(date +%s) + DUR ))
  while [ $(date +%s) -lt $END ]; do
    V=$(ioreg -rc AppleBacklightDisplay -l -w0 2>/dev/null \
        | grep -oE '"brightness"=\{"min"=[0-9]+,"max"=[0-9]+,"value"=[0-9]+' \
        | grep -oE '[0-9]+$' | head -1)
    [ -n "$V" ] && [ "$V" != "$PREV" ] && { echo "$(date '+%H:%M:%S') value=$V" >> "$BRLOG"; PREV="$V"; }
    sleep 0.3
  done
) &
BP=$!

trap 'kill $HP $BP 2>/dev/null; echo; echo "== 已停止 =="; exit 0' INT TERM
EXPECT=$(( $(date +%s) + DUR ))
while [ $(date +%s) -lt $EXPECT ]; do
  kill -0 $HP 2>/dev/null || break
  sleep 1
done
kill $HP $BP 2>/dev/null
wait $HP 2>/dev/null; wait $BP 2>/dev/null

echo
echo "================ 汇总 ================"
echo "--- HID 事件（按键类，已剔除坐标噪音）---"
grep -E 'PAGE=0x0C|PAGE=0x07 USAGE=0x00(3[0-9A-F]|4[0-9A-F])|PAGE=0xFF|PAGE=0x0B' "$HIDLOG" 2>/dev/null \
  | sed -E 's/ VALUE=[0-9]+//' | sort | uniq -c | sort -rn | head -25
echo
echo "--- 亮度变化 ---"
if [ -s "$BRLOG" ]; then cat "$BRLOG"; else echo "  （无变化）"; fi
echo
echo "--- 厂商自定义页（0xFF00+）---"
if grep -q 'PAGE=0xFF' "$HIDLOG" 2>/dev/null; then
  grep 'PAGE=0xFF' "$HIDLOG" | sed -E 's/ VALUE=[0-9]+//' | sort | uniq -c
else
  echo "  （无）→ 这些键不产生 HID 厂商事件"
fi
echo "======================================"
