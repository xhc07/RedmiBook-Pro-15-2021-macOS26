#!/bin/bash
# 安装 AppleIntelTGLCompat 到 /Library/Extensions 并重建 AuxKC
# 用法: sudo ./install-compat.sh [0.8.1|0.8.0]
# 用途: WhateverXe 与 Compat 版本必须配对（0.8.2↔0.8.1，0.8.0↔0.8.0）
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "需要 root：sudo $0 $*"; exit 1; }
VER="${1:-0.8.1}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$HERE/Drivers/Compat/AppleIntelTGLCompat-${VER}.kext"
[ -d "$SRC" ] || { echo "✗ 找不到 $SRC"; exit 1; }

echo "== 备份 =="
BK="/tmp/compat-backup-$(date +%Y%m%d-%H%M)"
mkdir -p "$BK"
cp -R /Library/Extensions/AppleIntelTGLCompat.kext "$BK/" 2>/dev/null || true
cp /Library/KernelCollections/AuxiliaryKernelExtensions.kc "$BK/" 2>/dev/null || true
echo "  备份到 $BK"

echo "== 安装 Compat $VER =="
rm -rf /Library/Extensions/AppleIntelTGLCompat.kext
cp -R "$SRC" /Library/Extensions/AppleIntelTGLCompat.kext
chown -R root:wheel /Library/Extensions/AppleIntelTGLCompat.kext
chmod -R go-w,a+rX /Library/Extensions/AppleIntelTGLCompat.kext

echo "== 重建 AuxKC（约 30-60 秒）=="
NEW=/Library/KernelCollections/AuxiliaryKernelExtensions.kc.new
rm -f "$NEW"
kmutil create -n aux --volume-root / --allow-missing-kdk \
  --kernel /System/Library/Kernels/kernel \
  -B /System/Library/KernelCollections/BootKernelExtensions.kc \
  -S /System/Library/KernelCollections/SystemKernelExtensions.kc \
  --repository /Library/Extensions -A "$NEW" -z
GOT=$(kmutil inspect -a x86_64 -A "$NEW" 2>/dev/null | awk '/org.b00t0x.AppleIntelTGLCompat/{print $2}')
echo "  新 AuxKC 中的 Compat 版本: ${GOT:-?}"
[ "$GOT" = "$VER" ] || { echo "✗ 版本不符，保留原 AuxKC 不动"; rm -f "$NEW"; exit 1; }
mv -f /Library/KernelCollections/AuxiliaryKernelExtensions.kc "$BK/AuxiliaryKernelExtensions.kc.old"
mv -f "$NEW" /Library/KernelCollections/AuxiliaryKernelExtensions.kc
chown root:wheel /Library/KernelCollections/AuxiliaryKernelExtensions.kc
chmod 644 /Library/KernelCollections/AuxiliaryKernelExtensions.kc
sync
echo "✓ 完成，请重启"
