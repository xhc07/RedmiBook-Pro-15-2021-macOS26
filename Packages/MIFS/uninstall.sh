#!/bin/bash
# 卸载 Fn 热键的系统侧组件
set -u
[ "$(id -u)" = "0" ] || { echo "请用 sudo 运行"; exit 1; }
launchctl bootout "gui/$(id -u)/org.mifs.mifskeysd" 2>/dev/null || true
rm -f /usr/local/bin/mifskeysd /Library/LaunchAgents/org.mifs.mifskeysd.plist
echo "✓ 已卸载（EFI 里的 SSDT-KEYS / MIFSKeys.kext 需另行移除）"
