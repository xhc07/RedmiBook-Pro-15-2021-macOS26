# 版本记录

## v0.4.0 — 2026-11-27

**重大升级：WhateverXe 0.8.6 + 内屏 eDP 修复（0.8.4/0.8.5/0.8.6 内屏黑屏问题解决）**

- 问题：升级到 0.8.4/0.8.5/0.8.6 后，macOS 接管固件显示时**内屏黑屏**（外接屏正常）
- 证据：内核日志 `Unsupported DDI` ×20 → `Phase 2 of link training failed` → AGDC 下线显示
- 修复：采用 **qqaoshi888** 的 `lyndon-0.8.6` 分支提交 **`ec5cd885`**（`-wex-edp-fix-training`）
  - 新文件 `kern_tgl_edp_training.cpp/.hpp`（DDI/PG 电源域修复 + 点亮前训练修补）
  - 本仓库收录最小补丁：[`Patches/wex-0.8.6-edp-fix-training.patch`](Patches/wex-0.8.6-edp-fix-training.patch)
- 实测：`Phase 2` 失败 **5 → 0**，内屏 3200×2000@90Hz + 外接 4K@60Hz 同时正常，Metal 2
- 配方与复现步骤：[`Packages/WEX-0.8.6-edpfix/README.md`](Packages/WEX-0.8.6-edpfix/README.md)
- EFI / EFI-debug 均已更新到 **0.8.6 + eDP 修复**（日常版静默，调试版带 trace）
- 已反馈上游：https://github.com/b00t0x/WhateverXe/issues/208#issuecomment-7214567458
- 发布：https://github.com/xhc07/RedmiBook-Pro-15-2021-macOS26/releases/tag/v0.4.0
  （资产 `RedmiBook-Pro-15-2021-macOS26-v0.4.0.zip`，163.7 MB）

## v0.3.2 — 2026-11-19

**新增：合盖自动关屏**

- 问题：系统睡眠不可用 → `SleepDisabled=1` → 合盖后屏幕不黑
- 排查：对比 AMD 版（RedmiBook Pro 14/15S）后确认 **ACPI 层本机已完整**（`_Q80` 里已有 `Notify(LID0,0x80)` + `GLID`），缺的是驱动侧动作
- 方案：新增 `Packages/MIFSLid` 用户态守护进程，监听 `AppleClamshellState`，合盖 `pmset displaysleepnow`、开盖 `caffeinate -u -t 1`
- 实测：合盖屏幕熄灭、开盖亮起

**文档**

- `docs/08 §6.7` 标记为已解决
- `docs/08 §6.5.1` 补充麦克风走 Intel SST/SoundWire 的证据（与 AMD ACP 的差异）
- 新增 `Packages/MIFSLid/README.md`

## v0.3.1 — 2026-11-18

**修复：开机后亮度自动跳高**

- 现象：关机前调低亮度，开机后被自动调高（最多两次，目标约 0.88）
- 根因：NVRAM 残留旧驱动（nmx/IrisXe）的变量 `nmintelfb-brightness = 88`
- 修复：`sudo nvram -d nmintelfb-brightness`（安装脚本已自动化）
- 验证：连续三次重启，开机亮度精确等于关机前值，零跳变

**新增工具**

- `Tools/diagnostics/brightlogd`：亮度变化记录器（200ms 采样，写 `/var/log/brightness.log`）
- `Tools/ai-install.sh` 新增第 6 步：自动检测并清理残留 NVRAM 变量

**文档**

- `README` §3.4：安装后必做（清理旧驱动残留）
- `docs/04 §I`：亮度跳高的完整排查过程 + NVRAM 原理问答
- `docs/08 §6.5`：从「待查」改为「已解决」
- `docs/11`：Fn 键总览（亮度键 vs 热键的两种拦截模式）

## v0.3.0 — 2026-11-18

**新增：Fn+F6 / F7 / F8 热键支持（投屏 / 截图 / 任务视图）**

- 发现厂商 SSDT 第 21 张里定义了热键 EC 查询（`_Q2B/_Q66/_Q08` → `WMID.QV20(1/2/3)`）
- 证实 **macOS 会派发 SSDT 里的 `_Qxx`** → 用「改名 + 自建 SSDT 重定义」拦截
- 新增 `SSDT-KEYS`（建 `HKEY` 设备并转发通知）
- 新增 `MIFSKeys.kext`（接收通知，写 IORegistry）
- 新增 `mifskeysd`（用户态桥接，触发 macOS 动作）
- 实测：F6 打开显示器设置、F7 区域截图、F8 任务视图，全部可用

详见 `Packages/MIFS/README.md`、`docs/10-Fn热键实现计划.md`。

## v0.2.1 — 2026-11-18

**修复：显示睡眠唤醒后黑屏（背光不恢复）**

- 根因：补丁 02 的 softsleep 唤醒路径用 `pp & 1` 判断面板电源，唤醒早期该位尚未置位 → 不写背光使能位，且标志被无条件清零 → 背光永不恢复
- 修复：`on ? (pp|4U) : (pp&~4U)` 无条件置位，并在面板电源写入时补置 bit2（`Patches/ours/`）
- EFI 的 boot-args 增加 `-wex-tgl-edp-softsleep`（必须保留）
- 实测记录：`TGLSoftSleep1` `pp=0x67 → 0x63`（关背光）、`TGLSoftSleep2` `0x63 → 0x67`（**恢复背光**）

> 注意：不加 softsleep 会走完整链路重训，本机重训后 WindowServer 报 `Display not ready`，120 秒看门狗 panic。

## v0.2.0 — 2026-11-17

**驱动升级：WhateverXe 0.8.2 → 0.8.3**

- 迁移到 WhateverXe **0.8.3**（上游 2026-11-17 发布）
- 4 个同机型 eDP 补丁已重新移植到 0.8.3（`01` 中 DDI 冲突部分上游已重构，故只保留 `-wex-edp-fix-training` 面板循环修复）
- 我们的亮度下限补丁已重新应用到 0.8.3
- 搭配 `AppleIntelTGLCompat 0.8.1`（由 0.8.3 源码编译）并重建 AuxKC
- 0.8.3 上游修复：GPU 恢复失败导致重启卡住、未使用电源域关闭时的 IRQ 恢复、VBT/面板身份解析重构
- 新增 `Tools/port-to-new-version.sh`：一条命令把补丁移植到新版本

验证：`WhateverXe 0.8.3` + `Compat 0.8.1`，3200×2000@90Hz、Metal 2、电池充电状态、触摸板、亮度下限均正常；
`TGLEDPKept=5`、`TGLEDPExtCapMasked=4`。

## v0.1.0 — 2026-11-17

首个版本：基于 **WhateverXe 0.8.2**。

- EFI（日常 / 调试两版）、25 个 kext、8 个 SSDT
- 自建 `SSDT-ADPX`（电池适配器）、`SSDT-BRTN`（Fn 亮度键）
- 亮度下限 6.25% 补丁、softsleep 背光修复补丁
- `Tools/install-compat.sh`、`verify.sh`、`set-dvmt.sh`、`ai-install.sh`、`diagnostics/`
- 文档：安装、功能、实现、失败尝试、睡眠调查、亮度、参考、已知问题
