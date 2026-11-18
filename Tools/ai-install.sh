#!/bin/bash
# ============================================================================
# RedmiBook Pro 15 2021 · macOS 26 一键安装脚本
# 供 AI 助手或用户直接执行：sudo ./Tools/ai-install.sh
#
# 它做四件事：
#   1) 检查前置条件（macOS 版本 / EFI 是否就位 / DVMT 是否 128MB）
#   2) 安装 WhateverXe Graphics（Apple 原厂 kext + Compat）
#   3) 按 EFI 里的 WhateverXe 版本自动配对 Compat，并重建 AuxKC
#   4) 设置推荐的电源策略（可跳过）并自检
#
# 用法:
#   sudo ./Tools/ai-install.sh              # 交互确认
#   sudo ./Tools/ai-install.sh --yes        # 全自动
#   sudo ./Tools/ai-install.sh --yes --no-pmset   # 不改电源策略
# ============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
YES=0; DO_PMSET=1
for a in "$@"; do
  case "$a" in
    --yes|-y) YES=1;;
    --no-pmset) DO_PMSET=0;;
    *) echo "未知参数: $a"; exit 1;;
  esac
done

log(){ printf '%s\n' "$*"; }
die(){ printf '✗ %s\n' "$*" >&2; exit 1; }
ask(){ [ "$YES" -eq 1 ] && return 0; read -r -p "$1 [y/N] " x; [ "$x" = y ] || [ "$x" = Y ]; }

[ "$EUID" -eq 0 ] || die "请用 root 运行：sudo $0"

log "=============================================="
log " RedmiBook Pro 15 2021 · macOS 26 安装助手"
log "=============================================="

# ---------- 1. 前置检查 ----------
log ""
log "[1/6] 前置检查"

OSVER=$(sw_vers -productVersion 2>/dev/null || echo unknown)
log "  macOS: $OSVER"
case "$OSVER" in
  26.*) log "  ✓ 目标版本（macOS 26）";;
  *)    log "  ⚠ 本项目只在 macOS 26.7.3 验证过，继续可能有差异";;
esac

SIP=$(csrutil status 2>/dev/null | grep -oE 'enabled|disabled' | head -1)
log "  SIP: ${SIP:-unknown}"

[ -d "$ROOT/EFI/OC" ] || die "找不到 $ROOT/EFI/OC —— 请确认脚本在仓库的 Tools/ 下"
[ -f "$ROOT/EFI/OC/config.plist" ] || die "找不到 EFI/OC/config.plist"

# EFI 里 WhateverXe 版本
WXV=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$ROOT/EFI/OC/Kexts/WhateverXe.kext/Contents/Info.plist" 2>/dev/null || echo "")
log "  EFI WhateverXe: ${WXV:-未找到}"
[ -n "$WXV" ] || die "EFI 里没有 WhateverXe.kext"

# 序列号检查
SER=$(/usr/libexec/PlistBuddy -c "Print :PlatformInfo:Generic:SystemSerialNumber" "$ROOT/EFI/OC/config.plist" 2>/dev/null || echo "")
if [ -z "$SER" ]; then
  log "  ⚠ EFI 里的序列号是空的（仓库故意清空）"
  log "    → 安装前请用 GenSMBIOS/OCAT 生成 MacBookPro16,2 的序列号填入，否则 Apple 服务异常"
  ask "    仍然继续？" || die "已取消"
else
  log "  ✓ 序列号已填写"
fi

# DVMT 检查
log ""
log "[1.5/7] DVMT 检查（需要 128 MB）"
DVMTOK=0
if PLIST=$(nvram -x 72C5E28C-7783-43A1-8767-FAD73FCCAFA4:SaSetup 2>/dev/null); then
  TMP=$(mktemp); printf '%s' "$PLIST" > "$TMP.plist"
  if RAW=$(plutil -extract 72C5E28C-7783-43A1-8767-FAD73FCCAFA4:SaSetup raw -o - "$TMP.plist" 2>/dev/null); then
    printf '%s' "$RAW" | base64 -D > "$TMP.bin" 2>/dev/null
    V=$(xxd -s 0x84 -l1 -p "$TMP.bin" 2>/dev/null)
    case "$V" in
      04) log "  ✓ DVMT = 128 MB"; DVMTOK=1;;
      fe|02|03|05) log "  ⚠ DVMT 当前 0x$V（非 128MB），核显可能无法加速";;
      *)  log "  ? DVMT 字节 0x$V（无法识别，可能是不同 BIOS）";;
    esac
  fi
  rm -f "$TMP" "$TMP.plist" "$TMP.bin" 2>/dev/null
else
  log "  ? 读不到 SaSetup 变量（可能是不同 BIOS）"
fi
if [ "$DVMTOK" -eq 0 ]; then
  if ask "  现在自动改成 128 MB 吗？（会写 UEFI 变量，重启生效）"; then
    "$ROOT/Tools/set-dvmt.sh" 128 || log "  ⚠ 设置失败，可稍后手动执行 Tools/set-dvmt.sh 128"
  fi
fi

# ---------- 2. 安装 Graphics ----------
log ""
log "[2/7] 安装 WhateverXe Graphics（Apple 原厂 kext + Compat）"
[ -f "$ROOT/Drivers/WhateverXe-Graphics-0.4.1.pkg" ] || die "缺少 Drivers/WhateverXe-Graphics-0.4.1.pkg"
if ask "  执行 installer -pkg Drivers/WhateverXe-Graphics-0.4.1.pkg ?"; then
  installer -pkg "$ROOT/Drivers/WhateverXe-Graphics-0.4.1.pkg" -target / || die "Graphics 安装失败"
  log "  ✓ 已安装"
else
  log "  - 跳过"
fi

# ---------- 3. 配对 Compat ----------
log ""
log "[3/7] 配对 AppleIntelTGLCompat"
case "$WXV" in
  0.8.2) WANT=0.8.1;;
  0.8.0) WANT=0.8.0;;
  *)     WANT=0.8.1; log "  ? 未知版本 $WXV，默认用 0.8.1";;
esac
log "  EFI WhateverXe $WXV → Compat $WANT"
"$ROOT/Tools/install-compat.sh" "$WANT" || die "Compat 安装/AuxKC 重建失败（原 AuxKC 未被替换）"

# ---------- 4. 电源策略 ----------
log ""
log "[4/7] 电源策略"
if [ "$DO_PMSET" -eq 1 ]; then
  if ask "  禁止系统睡眠（本机 S3 唤醒会 panic，详见 docs/05）？"; then
    pmset -a disablesleep 1 sleep 0 hibernatemode 0 standby 0 powernap 0 tcpkeepalive 0
    log "  ✓ 已禁止睡眠"
  else
    log "  - 跳过（若点睡眠后黑屏/重启，请自行执行上面的 pmset 命令）"
  fi
else
  log "  - 按参数跳过"
fi

# ---------- 4.5 清理旧驱动残留的 NVRAM 变量 ----------
log ""
log "[5/7] 清理旧驱动残留（避免开机亮度跳高）"
if nvram nmintelfb-brightness >/dev/null 2>&1; then
  log "  发现残留变量 nmintelfb-brightness（旧 nmx/IrisXe 驱动遗留）"
  if ask "  删除它？（不会影响系统，仅清除亮度残留）"; then
    nvram -d nmintelfb-brightness && log "  ✓ 已删除"
  else
    log "  - 跳过（可能导致开机亮度自动跳高）"
  fi
else
  log "  ✓ 无残留"
fi

# ---------- 5. 自检 ----------
log ""
log "[6/7] 自检"
"$ROOT/Tools/verify.sh" || true

log ""
log "=============================================="
log " 完成。请重启后再次运行 ./Tools/verify.sh 确认："
log "   - WhateverXe ${WXV} + AppleIntelTGLCompat ${WANT}"
log "   - Resolution 3200 x 2000 / Metal 2"
log "   - TGLEDPKept=5 / TGLEDPExtCapMasked>0"
log "   - 电池有充放电状态、触摸板可用"
log "=============================================="
