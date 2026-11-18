#!/bin/bash
# 一键安装 Fn 热键的系统侧组件（守护进程 + LaunchAgent）
# 用法: sudo bash Packages/MIFS/install.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
[ "$(id -u)" = "0" ] || { echo "请用 sudo 运行"; exit 1; }

echo "== 1) 安装守护进程 =="
install -d /usr/local/bin
install -m 755 "$HERE/daemon/mifskeysd" /usr/local/bin/mifskeysd
echo "  ✓ /usr/local/bin/mifskeysd"

echo "== 2) 安装 LaunchAgent =="
install -d /Library/LaunchAgents
install -m 644 "$HERE/daemon/org.mifs.mifskeysd.plist" /Library/LaunchAgents/
chown root:wheel /Library/LaunchAgents/org.mifs.mifskeysd.plist
echo "  ✓ /Library/LaunchAgents/org.mifs.mifskeysd.plist"

echo "== 3) 启动 =="
launchctl bootout "gui/$(id -u)" /Library/LaunchAgents/org.mifs.mifskeysd.plist 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" /Library/LaunchAgents/org.mifs.mifskeysd.plist 2>/dev/null || \
  echo "  （当前会话加载失败，重启后会自动启动）"
sleep 1
launchctl print "gui/$(id -u)/org.mifs.mifskeysd" 2>/dev/null | grep -E 'state =' | head -1 | sed 's/^/  /' || true

echo
echo "完成。验证："
echo "  ioreg -l -c MIFSKeys | grep -E 'EventCount|LastEvent'"
echo "  tail -f /tmp/mifskeysd.log"
echo
echo "首次按 Fn+F7（截图）时，请在系统设置里授予 mifskeysd 屏幕录制权限。"
