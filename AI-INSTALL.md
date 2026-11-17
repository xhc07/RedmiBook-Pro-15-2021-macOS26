# 写给 AI 的一键安装说明

> 返回主文档：[README.md](README.md)

本文件用于把整个项目**直接丢给 AI 助手**，让它按固定流程安装。
你也可以自己照着做——脚本就是给人用的。

---

## 一、给 AI 的提示词（复制以下整段）

```
你在协助安装一台 小米 RedmiBook Pro 15 2021（i5-11300H / Iris Xe 8086:9A49）的 macOS 26 黑苹果配置。
项目已下载到本地，根目录包含 EFI/、EFI-debug/、Drivers/、Tools/、docs/。

请严格按以下顺序执行，每步失败就停下并向我报告，不要跳步、不要自行发明步骤：

1. 读取 README.md 与 docs/01-安装指南.md，确认我对机器状态的理解。
2. 运行 `sudo ./Tools/ai-install.sh`（交互式），或在明确确认后运行 `sudo ./Tools/ai-install.sh --yes`。
3. 脚本会：检查 macOS 版本 / EFI 是否就位 / DVMT 是否为 128MB → 安装 WhateverXe Graphics →
   按 EFI 里 WhateverXe 的版本自动配对 AppleIntelTGLCompat → 重建 AuxKC → 设置电源策略 → 自检。
4. 若脚本提示「序列号为空」：**先停下**，让我用 GenSMBIOS/OCAT 生成 MacBookPro16,2 的
   SystemSerialNumber / MLB / SystemUUID / ROM 并填入 EFI/OC/config.plist。
5. 若提示 DVMT 不是 128MB：执行 `sudo ./Tools/set-dvmt.sh 128`，然后让我重启。
6. 安装完成后让我重启，重启后再运行 `./Tools/verify.sh`，把输出贴给你核对：
   - WhateverXe 与 Compat 版本是否配对（0.8.2 ↔ 0.8.1）
   - 分辨率是否 3200x2000、Metal 2 是否可用
   - TGLEDPKept=5、TGLEDPExtCapMasked>0
   - 电池是否有充放电状态、触摸板是否可用
7. 任何异常：先查 docs/08-已知问题.md，再用 Tools/diagnostics/ 下的工具收集信息；
   不要自行修改 EFI 的 kext 或 ACPI（除非我明确要求）。

重要约束：
- 不要修改内置硬盘上的 Windows 分区，ESP 只写 EFI/ 目录。
- 不要删除 boot-args 里的 keepsyms=1（会导致没有声音）。
- 不要启用系统睡眠（本机 S3 唤醒会 panic，见 docs/05）。
- 任何破坏性操作前先备份（脚本已内置 /tmp 备份，但请额外确认）。
```

---

## 二、脚本用法

```bash
# 交互式（推荐首次使用）
sudo ./Tools/ai-install.sh

# 全自动（已确认过环境）
sudo ./Tools/ai-install.sh --yes

# 不动电源策略（例如你想自己保留睡眠）
sudo ./Tools/ai-install.sh --yes --no-pmset
```

## 三、它会做什么

| 步骤 | 内容 | 是否可跳过 |
|---|---|---|
| 1 | 检查 macOS 版本、EFI 就位、序列号是否填写、DVMT 是否 128MB | 只读 |
| 2 | 安装 `Drivers/WhateverXe-Graphics-0.4.1.pkg`（Apple 原厂 kext + Compat 0.8.0） | 交互可跳过 |
| 3 | 读取 `EFI/OC/Kexts/WhateverXe.kext` 版本，自动选 Compat（0.8.2→0.8.1，0.8.0→0.8.0），重建 AuxKC 并校验 | 失败自动保留原 AuxKC |
| 4 | 设置电源策略（禁止睡眠） | `--no-pmset` 或交互跳过 |
| 5 | 运行 `Tools/verify.sh` 自检并打印结果 | 只读 |

## 四、它**不会**做什么

- ❌ 不会修改你的序列号（需要你自己生成）
- ❌ 不会分区、不会安装 macOS 本体（请自行制作安装盘）
- ❌ 不会动内置硬盘上的 Windows / 其它分区
- ❌ 不会覆盖你的 EFI（只读取 `EFI/` 做版本判断）
- ❌ 不会联网下载任何东西（所有依赖都在仓库里）

## 五、前置条件

| 项目 | 要求 |
|---|---|
| 系统 | 已安装 macOS 26（脚本主要做「装驱动 + 配对 + 自检」） |
| EFI | 已把本仓库 `EFI/` 放到 ESP 并能启动 |
| 序列号 | 已在 `EFI/OC/config.plist` 填好（仓库里是空的） |
| DVMT | 128 MB（脚本会检查，并提供一键修改） |

## 六、失败回退

| 失败点 | 现象 | 回退 |
|---|---|---|
| DVMT 修改失败 | 脚本提示 | `Tools/set-dvmt.sh show` 确认，或 BIOS 里 F9 恢复默认 |
| Graphics 安装失败 | `installer` 报错 | 重跑；或手动双击 pkg 安装 |
| AuxKC 重建失败 | 脚本报「版本不符」 | 原 AuxKC 未被替换，系统仍可启动；用 `Tools/install-compat.sh` 重试 |
| 装完黑屏 | 开机无显示 | 用 `EFI-debug/` 换入 ESP 看日志；或从 U 盘启动恢复备份 EFI |

## 七、两个 EFI 版本

| 版本 | 启动参数 | 用途 |
|---|---|---|
| `EFI/` | 无 `-v`、无 `debug=0x100` | **日常使用**（启动快、不滚屏） |
| `EFI-debug/` | 追加 `-v debug=0x100` | 排查问题（看开机日志、panic 信息更全） |

两者除上述参数外**完全一致**。详见 [EFI/README.md](EFI/README.md) 与 [EFI-debug/README.md](EFI-debug/README.md)。
