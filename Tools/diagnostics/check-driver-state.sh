#!/bin/bash
# 导出与 WhateverXe / eDP / 亮度 / 电池 / 输入相关的运行时状态，便于对比不同配置
echo "=== kext 版本 ==="
kmutil showloaded 2>/dev/null | grep -iE 'WhateverXe|TGLCompat|TGLGraphics|SMCBattery' | awk '{print "  "$8" "$9}'
echo "=== 关键属性 ==="
for k in TGLEDPKept TGLEDPKeepReady TGLSoftSleepReady TGLEDPExtCapMasked \
         TGLPanelPowerPropertyGuard TGLEDPRetrained TGLRenderWakeLifetimeTrial; do
  v=$(ioreg -l -w0 2>/dev/null | grep -oE "\"$k\" = [^,}]*" | head -1)
  printf "  %-32s %s\n" "$k" "${v:-（无）}"
done
echo "=== 显示 ==="
system_profiler SPDisplaysDataType 2>/dev/null | grep -E 'Resolution|Looks like|Metal' | sed 's/^/  /'
echo "=== 背光 ==="
ioreg -rc AppleBacklightDisplay -l -w0 2>/dev/null | grep -oE '"brightness"=\{[^}]*\}' | head -1 | sed 's/^/  /'
echo "=== 电池/适配器 ==="
pmset -g batt 2>/dev/null | head -2 | sed 's/^/  /'
echo "=== 输入 ==="
echo -n "  触摸板 HID 设备: "; ioreg -l -w0 2>/dev/null | grep -c 'VoodooI2CHIDDevice'
echo -n "  键盘设备: "; ioreg -l -w0 2>/dev/null | grep -c 'ApplePS2Keyboard'
echo "=== 电源策略 ==="
pmset -g 2>/dev/null | grep -E 'SleepDisabled|^ *sleep|hibernatemode|standby|powernap' | sed 's/^/  /'
