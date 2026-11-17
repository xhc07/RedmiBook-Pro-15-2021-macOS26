#!/bin/bash
# 用官方 pkg 安装 WhateverXe Graphics（会同时装 Compat 0.8.0 并重建 AuxKC）
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "需要 root"; exit 1; }
PKG="$(cd "$(dirname "$0")/.." && pwd)/Drivers/WhateverXe-Graphics-0.4.1.pkg"
[ -f "$PKG" ] || { echo "✗ 找不到 $PKG"; exit 1; }
installer -pkg "$PKG" -target /
echo "✓ 已安装，请重启（注意：此 pkg 会把 Compat 装成 0.8.0）"
