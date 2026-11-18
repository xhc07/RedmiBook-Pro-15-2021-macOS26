#!/bin/bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
SDK=/Users/xionghuanchen/Documents/deepseek-harness/default-workspace/wex-rebuild/MacKernelSDK
cd "$HERE"
xcrun clang++ -arch x86_64 -std=c++17 -O2 -mkernel -fapple-kext \
  -fno-exceptions -fno-rtti -fno-stack-protector -fno-builtin \
  -fno-asynchronous-unwind-tables -mno-red-zone -nostdinc \
  -DKERNEL -DKERNEL_PRIVATE -D__APPLE__ -D__MACH__ \
  -I"$SDK/Headers" -mmacosx-version-min=10.15 \
  -Wno-unused-parameter -c MIFSAudioProbe.cpp -o MIFSAudioProbe.o
xcrun ld -arch x86_64 -kext -undefined dynamic_lookup -no_fixup_chains \
  -macos_version_min 10.15 -o MIFSAudioProbe.kext/Contents/MacOS/MIFSAudioProbe \
  MIFSAudioProbe.o "$SDK/Library/x86_64/libkmod.a"
codesign -s - --force MIFSAudioProbe.kext 2>/dev/null || true
ls -l MIFSAudioProbe.kext/Contents/MacOS/MIFSAudioProbe | awk '{print "  二进制: "$5" 字节"}'
