#!/bin/bash
# 安装合盖关屏守护进程
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
[ "$(id -u)" = "0" ] || { echo "请用 sudo 运行"; exit 1; }
install -d /usr/local/bin
install -m 755 "$HERE/mifslidd" /usr/local/bin/mifslidd
install -m 644 "$HERE/org.mifs.mifslidd.plist" /Library/LaunchAgents/
chown root:wheel /Library/LaunchAgents/org.mifs.mifslidd.plist
U=$(stat -f%u /dev/console)
launchctl bootout "gui/$U" /Library/LaunchAgents/org.mifs.mifslidd.plist 2>/dev/null || true
launchctl bootstrap "gui/$U" /Library/LaunchAgents/org.mifs.mifslidd.plist
sleep 1
cat /tmp/mifslidd.log 2>/dev/null | tail -2
echo "✓ 已安装"
