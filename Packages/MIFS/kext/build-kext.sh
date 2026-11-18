#!/bin/bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
SDK=/Users/xionghuanchen/Documents/deepseek-harness/default-workspace/wex-rebuild/MacKernelSDK
cd "$HERE"
echo "== compile =="
xcrun clang++ -arch x86_64 -std=c++17 -O2 -mkernel -fapple-kext \
  -fno-exceptions -fno-rtti -fno-stack-protector -fno-builtin \
  -fno-asynchronous-unwind-tables -mno-red-zone -nostdinc \
  -DKERNEL -DKERNEL_PRIVATE -D__APPLE__ -D__MACH__ \
  -I"$SDK/Headers" -mmacosx-version-min=10.15 \
  -Wno-unused-parameter -c MIFSKeys.cpp -o MIFSKeys.o
echo "== link =="
xcrun ld -arch x86_64 -kext -undefined dynamic_lookup -no_fixup_chains \
  -macos_version_min 10.15 -o MIFSKeys.kext/Contents/MacOS/MIFSKeys \
  MIFSKeys.o "$SDK/Library/x86_64/libkmod.a"
echo "== sign =="
codesign -s - --force MIFSKeys.kext 2>/dev/null || true
echo "== done =="
ls -l MIFSKeys.kext/Contents/MacOS/MIFSKeys
nm -a MIFSKeys.kext/Contents/MacOS/MIFSKeys | grep -c ' _kmod_info' | sed 's/^/kmod_info: /'
