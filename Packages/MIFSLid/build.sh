#!/bin/bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
xcrun clang -O2 -o mifslidd mifslidd.c -framework IOKit -framework CoreFoundation
echo "✓ 编译完成: $(ls -l mifslidd | awk '{print $5}') 字节"
