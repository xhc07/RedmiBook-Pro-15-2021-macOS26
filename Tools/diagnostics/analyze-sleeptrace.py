#!/usr/bin/env python3
"""分析 sleeptrace.sh 的日志：找出时间跳变（= 系统真正挂起的时间段）"""
import re, sys
path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/sleeptrace.log"
lines = [l for l in open(path, errors="ignore") if re.match(r"\d\d:\d\d:\d\d", l)]
prev, gaps = None, []
for l in lines:
    m = re.match(r"(\d\d):(\d\d):(\d\d)", l)
    t = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + int(m.group(3))
    if prev is not None:
        d = (t - prev) % 86400
        if d > 3:
            gaps.append((prev, t, d))
    prev = t
print(f"样本数: {len(lines)}")
if not gaps:
    print("无时间跳变 → 采样连续，系统未真正挂起（卡在睡眠过渡）")
for a, b, d in gaps:
    fmt = lambda s: f"{s//3600:02d}:{s%3600//60:02d}:{s%60:02d}"
    print(f"  跳变 {fmt(a)} → {fmt(b)}  间隔 {d}s  {'← 真实挂起' if d >= 20 else '← 短暂卡顿'}")
if lines:
    print("末 3 行:")
    for l in lines[-3:]:
        print("  " + l.rstrip())
