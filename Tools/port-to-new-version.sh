#!/bin/bash
# 将本仓库的 4 个 eDP 补丁 + 亮度补丁移植到指定 WhateverXe 版本并编译
# 用法: ./Tools/port-to-new-version.sh 0.8.4 [--build-only]
set -uo pipefail
VER="${1:?用法: $0 <版本号，如 0.8.4>}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
WS="${WEX_WORKSPACE:-$HOME/wex-port}"
SRC="$WS/WhateverXe-$VER"
PATCHES="$HERE/Patches"

mkdir -p "$WS"
if [ ! -d "$SRC" ]; then
  echo "== 克隆 $VER =="
  git clone -q --branch "$VER" --depth 1 https://github.com/b00t0x/WhateverXe.git "$SRC" || {
    echo "✗ 克隆失败（检查网络/代理）"; exit 1; }
fi
cd "$SRC" || exit 1
git checkout -q -- . 2>/dev/null; git clean -fdq 2>/dev/null

echo "== 应用第三方 eDP 补丁 =="
for f in "$PATCHES"/third-party/0*.patch; do
  n=$(basename "$f")
  if patch -p1 --forward --fuzz=3 --no-backup-if-mismatch < "$f" >/dev/null 2>&1; then
    echo "  ✓ $n"
  else
    echo "  ⚠ $n 有冲突（.rej 已生成，需手工处理）"
  fi
done

echo "== 应用我们的补丁 =="
if patch -p1 --forward --fuzz=3 --no-backup-if-mismatch < "$PATCHES/ours/WhateverXe-tgl-brightness-and-softsleep.patch" >/dev/null 2>&1; then
  echo "  ✓ ours/WhateverXe-tgl-brightness-and-softsleep.patch"
else
  echo "  ⚠ ours 补丁有冲突（.rej 已生成）"
fi

echo "== 检查关键标记 =="
for m in TGLPanelCycle TGLEDPKept tglEDPKeptMiscBpc TGLEDPExtCapMasked; do
  printf "  %-22s %s 处\n" "$m" "$(grep -rc "$m" WhateverXe/kern_xe.cpp 2>/dev/null)"
done

echo "== 构建环境 =="
ln -sfn "${MACKERNELSDK:-$HERE/Tools/deps/MacKernelSDK}" MacKernelSDK
ln -sfn "${LILU_KEXT:-$HERE/Tools/deps/Lilu.kext}" Lilu.kext
[ -d MacKernelSDK/Headers ] || { echo "✗ 缺少 MacKernelSDK（设置 MACKERNELSDK 指向它）"; exit 1; }
[ -d Lilu.kext/Contents/Resources/Headers ] || { echo "✗ 缺少 Lilu.kext（设置 LILU_KEXT 指向它）"; exit 1; }

echo "== 编译 =="
python3 tools/build.py --release 2>&1 | tail -5
echo
echo "产物: $SRC/build/WhateverXe.kext"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" build/WhateverXe.kext/Contents/Info.plist 2>/dev/null | sed 's/^/  版本: /'
