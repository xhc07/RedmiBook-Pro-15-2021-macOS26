# WhateverXe 0.8.6 + 内屏 eDP 修复（本机验证配方）

> 本目录记录：为什么必须用 0.8.6 + `-wex-edp-fix-training`，以及如何复现我们验证过的构建。
> 补丁**不是我们写的**，作者是 qqaoshi888；我们只做编译与硬件验证。

## 1. 背景

WhateverXe **0.8.4 / 0.8.5 / 0.8.6** 在 Tiger Lake-H35（`8086:9A49`）笔记本上，
macOS 接管固件显示时内屏会黑（外接屏正常）。本机实测日志：

```
[IGFB][ERROR][PORT] Unsupported DDI            (约 20 次)
[IGFB][ERROR][LINK_TRAINING] Phase 2 of link training failed
          - notifying AGDC to take display offline
```

**加上 `-wex-edp-fix-training` 后 `Phase 2` 失败次数从 5 变成 0，内屏恢复正常。**

## 2. 修复来源

| 项目 | 值 |
|---|---|
| 仓库 | `qqaoshi888/WhateverXe`（上游 fork） |
| 分支 | `lyndon-0.8.6` |
| 提交 | **`ec5cd885`** — "add -wex-edp-fix-training" |
| 日期 | 2026-11-26 |
| 涉及文件 | `kern_tgl_edp_training.cpp`（新，+253）、`kern_tgl_edp_training.hpp`（新，+46）、`kern_xe.cpp`（+14）、`kern_xe.hpp`（+4） |
| 本地补丁 | [`patches/wex-0.8.6-edp-fix-training.patch`](../../patches/wex-0.8.6-edp-fix-training.patch)（370 行） |

补丁做的事：
- `powerDomainRepair()`：修复 DDI / PG 电源域的陈旧状态
- `wrapLightUp()`：内屏点亮前的训练修补
- 由启动参数 `-wex-edp-fix-training` 开启（默认关闭）

## 3. 我们验证过的构建

| 项目 | 值 |
|---|---|
| 基线 | 0.8.6 + `ec5cd885` |
| `WhateverXe` 二进制 SHA-256 | `2eff78e35b689e1e…`（本仓库 EFI 里就是这一份） |
| 编译工具链 | `tools/build.py --release`，MacKernelSDK + Lilu 1.7.3 |
| Graphics | **0.4.5**（必须与 0.8.6 配套） |

## 4. 启动参数（本机验证）

日常（quiet）：
```
keepsyms=1 alcid=38 alcverbs=1 -allow3d -disablegfxfirmware
-wex-edp-fix-training -vi2c-force-polling
```

排查（debug）：在上面基础上加
```
-v debug=0x100 -wex-display-trace -wex-display13-trace
```

**不要加** `-wex-tgl-edp-keep`：0.8.6 里它会触发 boot-panel handoff，本机实测无帮助。

## 5. 验证结果

```
在线显示器数: 2
内屏: 3200x2000，UI 1600x1000 @ 90Hz，port 0，connector-type 0x02000000
外接: 3840x2160，UI 1920x1080 @ 60Hz，port 3，connector-type 0x00040000
Metal 2 ✓
```

日志：

| 指标 | 无修复 | 有修复 |
|---|---|---|
| `Phase 2 of link training failed` | 5 | **0** |
| `Unsupported DDI` | 20 | 20（仍打印，但不再致命） |
| 内屏 | 黑 | ✅ 正常 |

## 6. 如何复现编译

```bash
git clone --branch lyndon-0.8.6 https://github.com/qqaoshi888/WhateverXe.git wex
cd wex
# 让 build.py 找到 SDK 与 Lilu
ln -s /path/to/MacKernelSDK MacKernelSDK
ln -s /path/to/Lilu.kext Lilu.kext
python3 tools/build.py --release
# 产物：build/WhateverXe.kext  → 放进 EFI/OC/Kexts/
```

或直接对上游 0.8.6 应用补丁：

```bash
git clone --depth 1 --branch 0.8.6 https://github.com/b00t0x/WhateverXe.git wex
cd wex
git apply /path/to/patches/wex-0.8.6-edp-fix-training.patch
python3 tools/build.py --release
```

## 7. 归属与许可

- WhateverXe 版权：vit9696 / b00t0x，BSD 风格许可（见 `LICENSES/`）
- eDP 修复作者：**qqaoshi888**（提交 `ec5cd885`）
- 我们只做：编译、在本机（RedmiBook Pro 15 2021 / i5-11300H / 9A49）验证、并把结果反馈到上游 #208
- 相关 issue：https://github.com/b00t0x/WhateverXe/issues/208
