#!/bin/bash
set -u
[ "$(id -u)" = "0" ] || { echo "请用 sudo 运行"; exit 1; }
U=$(stat -f%u /dev/console)
launchctl bootout "gui/$U/org.mifs.mifslidd" 2>/dev/null || true
rm -f /usr/local/bin/mifslidd /Library/LaunchAgents/org.mifs.mifslidd.plist
echo "✓ 已卸载"
