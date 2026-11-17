#!/bin/bash
# 睡眠状态采样器：每秒把系统电源/显示/GPU 状态写入日志，用于判断"系统是否真的挂起"
# 用法: sudo ./sleeptrace.sh [秒数] [日志路径]
#   默认 600 秒，写 /tmp/sleeptrace.log
# 原理: 系统真正进入 S3 时 CPU 停止调度，采样会中断 → 日志出现"时间跳变"
#       若能看到整个睡眠期间采样连续，说明系统根本没睡（卡在过渡阶段）
DUR="${1:-600}"; LOG="${2:-/tmp/sleeptrace.log}"
: > "$LOG"
echo "# start $(date '+%F %T')  dur=${DUR}s" >> "$LOG"
END=$(( $(date +%s) + DUR ))
while [ $(date +%s) -lt $END ]; do
  TS=$(date '+%H:%M:%S')
  DI=$(sysctl -n machdep.xcpm.deep_idle_count 2>/dev/null || echo NA)
  DW=$(ioreg -c IODisplayWrangler -d 1 2>/dev/null | grep -oE '"CurrentPowerState"=[0-9]+' | head -1 | cut -d= -f2)
  FB=$(ioreg -rc AppleIntelFramebuffer 2>/dev/null | grep -oE '"IOPowerManagement" = \{[^}]*\}' | head -1 | grep -oE '"CurrentPowerState"=[0-9]+' | head -1 | cut -d= -f2)
  WS=$(pgrep -x WindowServer | head -1)
  echo "$TS deep_idle=${DI:-NA} disp=${DW:-NA} fb=${FB:-NA} ws=${WS:-NA}" >> "$LOG"
  sleep 1
done
echo "# end $(date '+%F %T')" >> "$LOG"
