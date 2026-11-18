#!/bin/bash
# 外接屏（HDMI / Type-C DP）音频诊断
# 用法：接上外接屏后运行 ./displayaudio.sh
OUT="/tmp/displayaudio-$(date +%Y%m%d-%H%M%S).txt"
exec > >(tee "$OUT") 2>&1

echo "=== 0. 基本信息 ==="
date
system_profiler SPDisplaysDataType 2>/dev/null | grep -E 'Resolution|UI Looks like|Display Type|Mirror|Online|Connection Type|Television'

echo
echo "=== 1. 系统音频设备（关键：是否出现 HDMI/DP 输出）==="
system_profiler SPAudioDataType 2>/dev/null

echo
echo "=== 2. HDA 控制器与 codec 数量 ==="
echo -n "  AppleHDAController 实例: "; ioreg -l -w0 | grep -c 'class AppleHDAController'
echo -n "  IOHDACodecDevice 实例: "; ioreg -l -w0 | grep -c 'class IOHDACodecDevice'
echo -n "  AppleHDADriver 实例: "; ioreg -l -w0 | grep -c 'class AppleHDADriver'
echo -n "  AppleHDAHDMI_DPDriver 实例: "; ioreg -l -w0 | grep -c 'AppleHDAHDMI_DPDriver'
echo -n "  AppleHDAEngineOutputDP 实例: "; ioreg -l -w0 | grep -c 'AppleHDAEngineOutputDP'

echo
echo "=== 3. hda-gfx 属性（iGPU / HDA 必须一致）==="
ioreg -l -w0 | grep -E '"hda-gfx"' | head -10

echo
echo "=== 4. 显示连接器（framebuffer port）==="
ioreg -rc AppleIntelFramebuffer -l -w0 2>/dev/null | grep -E 'class AppleIntelFramebuffer|port-number|connector-type|display-type|IOFBCurrentPixelClock' | head -40

echo
echo "=== 5. 显示设备与音频端点 ==="
ioreg -rc IODisplayConnect -l -w0 2>/dev/null | grep -E 'IODisplayPrefsKey|DisplayProductID|DisplayVendorID' | head -10
ioreg -l -w0 | grep -iE 'AppleHDAUserClient|IOAudioEngine|AppleHDACodecGeneric' | head -10

echo
echo "=== 6. 最近 5 分钟 HDA 相关日志 ==="
log show --last 5m 2>/dev/null | grep -iE 'AppleHDA|HDAudio|hdmi|displayport.*audio|IOHDACodec' | head -30

echo
echo "=== 7. 内核里的 HDA 设备树 ==="
ioreg -rc AppleHDAController -l -w0 2>/dev/null | grep -E 'class |IOHDACodecDevice|IOHDACodecFunction|codec-address' | head -20

echo
echo "输出已保存到: $OUT"
