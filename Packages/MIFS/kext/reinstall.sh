#!/bin/bash
set -u
WS="/Users/xionghuanchen/Documents/deepseek-harness/default-workspace"
for d in $(diskutil list 2>/dev/null | awk '/EFI EFI/ && $0 ~ /209\.7 MB/ {print $NF}'); do
  diskutil unmount force "$d" 2>/dev/null; fsck_msdos -fy "/dev/r${d}" >/dev/null 2>&1
  diskutil mount "$d" >/dev/null 2>&1
  MP=$(diskutil info "$d" | awk -F': *' '/Mount Point/ {print $2}')
  [ -n "$MP" ] && [ -f "$MP/EFI/OC/config.plist" ] || continue
  rm -rf "$MP/EFI/OC/Kexts/MIFSKeys.kext"
  cp -R "$WS/mifs/MIFSKeys.kext" "$MP/EFI/OC/Kexts/MIFSKeys.kext"
  echo "  ✓ 已更新 kext"
  echo -n "    IONameMatch: "; /usr/libexec/PlistBuddy -c "Print :IOKitPersonalities:MIFSKeys:IONameMatch" "$MP/EFI/OC/Kexts/MIFSKeys.kext/Contents/Info.plist"
  echo -n "    二进制 sha: "; shasum -a 256 "$MP/EFI/OC/Kexts/MIFSKeys.kext/Contents/MacOS/MIFSKeys" | cut -c1-16
  sync; diskutil unmount "$MP" >/dev/null 2>&1 && echo "  ✓ 已卸载"
  exit 0
done
echo "✗ 失败"; exit 1
