#!/bin/bash
# 安装后自检：版本、驱动、关键属性、功能状态
echo "=== 1. kext 版本 ==="
kmutil showloaded 2>/dev/null | grep -iE 'WhateverXe|TGLCompat|TGLGraphics' | awk '{print "  "$8" "$9}'
echo
echo "=== 2. AuxKC 中的 Compat ==="
kmutil inspect -a x86_64 -A /Library/KernelCollections/AuxiliaryKernelExtensions.kc 2>/dev/null | grep -i Compat | sed 's/^/  /'
echo
echo "=== 3. 关键运行时属性（应全部出现）==="
for k in TGLEDPKept TGLEDPKeepReady TGLEDPExtCapMasked TGLPanelPowerPropertyGuard; do
  v=$(ioreg -l -w0 2>/dev/null | grep -oE "\"$k\" = [^,}]*" | head -1)
  printf "  %-28s %s\n" "$k" "${v:-缺失}"
done
echo
echo "=== 4. 显示与加速 ==="
system_profiler SPDisplaysDataType 2>/dev/null | grep -E 'Resolution|Looks like|Metal' | sed 's/^/  /'
echo
echo "=== 5. 电池与适配器 ==="
pmset -g batt 2>/dev/null | head -2 | sed 's/^/  /'
ioreg -c AppleSmartBattery -l -w0 2>/dev/null | grep -oE '"(ExternalConnected|IsCharging|CurrentCapacity|MaxCapacity)" = [^,}]*' | head -4 | sed 's/^/  /'
echo
echo "=== 6. 音频 / 亮度 / 输入 ==="
ioreg -l -w0 2>/dev/null | grep -c 'AppleHDAEngineOutput' | sed 's/^/  HDA 输出节点: /'
ioreg -rc AppleBacklightDisplay -l -w0 2>/dev/null | grep -oE '"brightness"=\{[^}]*\}' | head -1 | sed 's/^/  亮度: /'
ioreg -l -w0 2>/dev/null | grep -c 'VoodooI2CHIDDevice' | sed 's/^/  触摸板 HID 设备: /'
