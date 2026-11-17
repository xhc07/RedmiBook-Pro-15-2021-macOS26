# 工具

> 返回主文档：[README.md](../README.md)

本目录分两部分：

| 目录/文件 | 用途 |
|---|---|
| `install-compat.sh` | 安装 `AppleIntelTGLCompat` 到 `/Library/Extensions` 并重建 AuxKC（带版本校验与备份） |
| `reinstall-graphics.sh` | 用官方 pkg 安装 WhateverXe Graphics（会同时装 Compat 0.8.0） |
| `verify.sh` | 安装后自检：版本、驱动、关键属性、显示、电池、音频、输入 |
| `set-dvmt.sh` | 读取/修改隐藏的 DVMT Pre-Allocated（默认 128 MB） |
| `diagnostics/` | **排查工具集**：睡眠采样、panic 摘要、ESP 修复、驱动状态快照、亮度/HID 工具 |
| `ai-install.sh` | 一键安装脚本（供 AI 或用户直接执行） |

## 推荐顺序

```bash
sudo ./Tools/reinstall-graphics.sh        # 1. 装 Graphics（含 Compat 0.8.0）
sudo ./Tools/install-compat.sh 0.8.1      # 2. 配对 Compat 到 0.8.1（对应 WhateverXe 0.8.2）
sudo reboot                               # 3. 重启
./Tools/verify.sh                         # 4. 自检
```

## 排查工具

见 [diagnostics/README.md](diagnostics/README.md)（含方法说明与每个工具的输出判读）。
