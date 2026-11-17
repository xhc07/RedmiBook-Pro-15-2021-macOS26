# 版本记录

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
