#!/bin/bash
# 提取最近的 panic / gpuRestart / spin 摘要（macOS 26 的 panic 是文本/RTF，用户常另存为 .rtf）
echo "=== 最近的诊断文件 ==="
ls -1t /Library/Logs/DiagnosticReports/*.panic /Library/Logs/DiagnosticReports/*.gpuRestart \
        /Library/Logs/DiagnosticReports/*.spin 2>/dev/null | head -5 | sed 's/^/  /'
echo
echo "=== 最新 panic 前 3 行 ==="
P=$(ls -1t /Library/Logs/DiagnosticReports/*.panic 2>/dev/null | head -1)
[ -n "$P" ] && head -3 "$P" | cut -c1-200 | sed 's/^/  /' || echo "  （无）"
echo
echo "=== 若是用户另存的 .rtf，这样读 ==="
echo '  textutil -convert txt -stdout /path/to/panic.rtf | head -5'
echo
echo "=== 最近的睡眠/唤醒记录 ==="
pmset -g log 2>/dev/null | grep -E 'Entering Sleep|Wake from|Display is turned' | tail -6 | sed 's/^/  /'
