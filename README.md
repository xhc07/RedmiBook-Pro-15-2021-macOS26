# RedmiBook Pro 15 2021 · macOS 26 (Tahoe) 黑苹果配置

> 小米 RedmiBook Pro 15 2021（TIMI TM2017，i5-11300H / Iris Xe）在 macOS 26.7.3 上的可用配置、
> 驱动与源码改动。基于社区同机型 EFI + WhateverXe 原生 Tiger Lake 驱动整合，
> 并补充了电池适配器、Fn 亮度键、亮度下限等改动。
>
> **English**: OpenCore configuration, drivers and source patches for running macOS 26 (Tahoe)
> on the Xiaomi RedmiBook Pro 15 2021 (i5-11300H, Iris Xe 8086:9A49). Based on the community
> same-model EFI and the WhateverXe native Tiger Lake driver.

---

## 1. 机器规格

| 项目 | 值 |
|---|---|
| 机型 | 小米 RedmiBook Pro 15 2021（TIMI TM2017） |
| BIOS | Insyde `RMATG5B0P0D0D` |
| CPU | Intel Core i5-11300H（Tiger Lake-H35，4C8T） |
| 核显 | Intel Iris Xe Graphics，`8086:9A49`（TGL GT2） |
| 屏幕 | 天马 TL156MDMP01，3200×2000，30 位色，**内置 eDP（DDI A）**，HiDPI 1600×1000 @ 90 Hz |
| 内存 / 硬盘 | 16 GB / 512 GB NVMe（本配置在**外置 USB SSD** 上验证） |
| 无线 | Intel AX201（Wi-Fi 6 + 蓝牙 5.1） |
| 音频 | ALC 系列（`alcid=38`）+ Intel SST DMIC（**不可用**，见 §6） |
| 目标系统 | macOS 26.7.3（25G342） |
| SMBIOS | `MacBookPro16,2` |

## 2. 功能状态

| 功能 | 状态 | 实现方式 |
|---|---|---|
| 开机 / 显示（3200×2000 @90 Hz） | ✅ | WhateverXe 0.8.2 + 补丁 02（keep）+ 补丁 04（retrain） |
| GPU 加速（Metal 2） | ✅ | `AppleIntelTGLGraphics` 16.0.0 + Compat 0.8.1（AuxKC） |
| 亮度调节（滑块 / HUD） | ✅ | `SSDT-PNLF` + 补丁 03 + **亮度下限 6.25%**（本仓库改动） |
| 显示器睡眠 / 唤醒 | ✅ | `-wex-tgl-edp-softsleep`，唤醒只做 partial modeset |
| **系统睡眠（S3）** | ❌ | 唤醒后显示无法恢复 → 看门狗 panic，详见 [docs/05](docs/05-睡眠调查.md) |
| 电池电量 / 充电状态 | ✅ | `SSDT-ADPX`（发布 `ACPI0003`）+ `SMCBatteryManager` |
| **Fn+F4 / Fn+F5（亮度）** | ✅ | `SSDT-BRTN` + `BrightnessKeys`，实测每档 ±128 |
| **Fn+F6（投屏）** | ✅ | `Packages/MIFS`：SSDT-KEYS + MIFSKeys.kext + 守护进程 |
| **Fn+F7（截图）** | ✅ | 同上（区域截图到剪贴板） |
| **Fn+F8（任务视图）** | ✅ | 同上（Mission Control） |
| 键盘 / 触摸板 / 手势 | ✅ | VoodooPS2 2.3.8 + VoodooI2C 2.9.1（已打补丁） |
| 音频输出 / 输入口 | ✅ | `SimpleHDA` 1.0.0 + `AppleALC` 1.9.8（`alcid=38`，需 `keepsyms=1`） |
| **内置麦克风（DMIC）** | ❌ | macOS 无 SOF/DSP 栈，见 [docs/08](docs/08-已知问题.md) |
| Wi-Fi / 蓝牙 | ✅ | `AirportItlwm` 2.4.0 / IntelBluetooth 2.5.x |
| USB / 外置硬盘 | ✅ | USBToolBox + UTBDefault + XHCI-unsupported |
| 摄像头 | ✅ | 原生 UVC |
| 合盖 | ⚠️ | 已设 `disablesleep 1`：合盖不睡，避免误触发 S3 |

## 3. 快速开始

```bash
# 0. 前置：BIOS 里把 DVMT 改为 128 MB（隐藏项，脚本见 Tools/set-dvmt.sh）
# 1. 准备 OpenCore 1.0.x + 本仓库 EFI/
# 2. 生成你自己的 SMBIOS（MacBookPro16,2），填进 EFI/OC/config.plist
# 3. 安装 WhateverXe Graphics（会把 Compat 0.8.0 装进 /Library/Extensions）
sudo ./Tools/reinstall-graphics.sh
# 4. 让 Compat 与 EFI 里的 WhateverXe 版本配对（0.8.2 ↔ 0.8.1）
sudo ./Tools/install-compat.sh 0.8.1
# 5. 重启，然后自检
./Tools/verify.sh
```

详细步骤见 [docs/01-安装指南.md](docs/01-安装指南.md)。

### 3.1 两个 EFI 版本

| 版本 | 启动参数差异 | 用途 |
|---|---|---|
| **`EFI/`**（日常版） | 无 `-v`、无 `debug=0x100` | 日常使用：启动快、不滚屏 |
| **`EFI-debug/`**（调试版） | 追加 `-v debug=0x100` | 排查问题：滚动打印内核/kext 日志，panic 信息更全 |

两者 **kext、ACPI、其余 config 完全一致**，只有启动参数不同；日志内容对报 bug 很有用。
详见 [EFI/README.md](EFI/README.md)、[EFI-debug/README.md](EFI-debug/README.md)。

### 3.3 Fn 热键的系统侧安装（v0.3.0 起）

`Fn+F6/F7/F8` 需要**两个系统文件**（EFI 部分已含在 `EFI/` 里，无需额外操作）：

```bash
# 1) 安装守护进程
sudo cp Packages/MIFS/daemon/mifskeysd /usr/local/bin/
sudo chmod 755 /usr/local/bin/mifskeysd

# 2) 安装开机自启
sudo cp Packages/MIFS/daemon/org.mifs.mifskeysd.plist /Library/LaunchAgents/
sudo chown root:wheel /Library/LaunchAgents/org.mifs.mifskeysd.plist
sudo chmod 644 /Library/LaunchAgents/org.mifs.mifskeysd.plist

# 3) 启动（或重启后自动启动）
launchctl bootstrap gui/$(id -u) /Library/LaunchAgents/org.mifs.mifskeysd.plist
```

**首次按 F7（截图）时**，系统会弹窗要求给 `mifskeysd` **屏幕录制**权限，允许即可。

验证：

```bash
ioreg -l -c MIFSKeys | grep -E 'EventCount|LastEvent|MIFSKeysReady'
pgrep -fl mifskeysd
tail -f /tmp/mifskeysd.log      # 按键时出现 "event N"
```

> 为什么需要守护进程：截图/任务视图/显示器设置都是**用户态功能**，内核里没有对应 API。
> 亮度键不需要守护进程，因为 macOS 有内核级的显示亮度机制。
> 详见 [Packages/MIFS/README.md](Packages/MIFS/README.md)。

### 3.4 安装后必做：清理旧驱动残留

如果你之前装过别的核显驱动（如 nmx/IrisXe），NVRAM 里可能残留亮度变量，会导致**开机亮度自动跳高**：

```bash
# 检查
nvram nmintelfb-brightness
# 删除（若存在）
sudo nvram -d nmintelfb-brightness
```

> 这不是改 EFI、系统或驱动，只是**清掉旧驱动写在 NVRAM 里的脏数据**。
> 详见 [docs/08 §6.5](docs/08-已知问题.md)。

### 3.1.1 关于 Release 压缩包的解压

Release 附件的 zip 里含**中文文件名**（`docs/` 下的文档）。不同工具表现不同：

| 工具 | 结果 |
|---|---|
| macOS Finder 双击 / `ditto -x -k` | ✅ 正常 |
| macOS 命令行 `unzip` | ⚠️ 部分版本会**跳过中文名文件**（docs 目录缺失） |
| 7-Zip / WinRAR / Keka | ✅ 正常 |
| Windows 资源管理器自带解压 | ⚠️ 可能乱码 |

**推荐**：用 7-Zip、Keka 或直接 `git clone`（最稳）。

`v0.3.0` 起的 zip **由 7-Zip 打包**（`-tzip -mcu=on`，强制 UTF-8 文件名），
`unzip` / 7-Zip / Finder / WinRAR 均可正确解压；更早的 `v0.1.0/v0.2.0/v0.2.1`
建议优先用 `git clone` + `git checkout <tag>`。

**7-Zip 命令行（macOS）**：<https://github.com/ip7z/7zip/releases>（下载 `7zXXXX-mac.tar.xz`，
解包得到 `7zz`）。本仓库的打包脚本 [Tools/pack-release.sh](Tools/pack-release.sh) 就依赖它。

### 3.2 一键安装（交给 AI 或直接跑）

```bash
sudo ./Tools/ai-install.sh          # 交互式
sudo ./Tools/ai-install.sh --yes    # 全自动
```

脚本会：检查环境 → 装 Graphics → 按 EFI 版本自动配对 Compat → 重建 AuxKC → 电源策略 → 自检。
提示词与完整说明见 [AI-INSTALL.md](AI-INSTALL.md)。

## 4. 目录结构

```
EFI/                 最终 EFI（日常版：无 -v，序列号已清空）      → EFI/README.md
EFI-debug/           调试版 EFI（-v + debug=0x100）              → EFI-debug/README.md
  OC/ACPI/           8 个 SSDT（含本仓库新增 SSDT-ADPX / SSDT-BRTN）
  OC/Kexts/          25 个 kext
ACPI/                本仓库新增 SSDT 的源码（.dsl）与产物（.aml）
Patches/ours/        我们对 WhateverXe 的源码改动（亮度下限 + softsleep 背光修复）
Patches/third-party/ 同机型社区的 4 个 eDP 补丁（含出处与 SHA256） → Patches/README.md
Drivers/             WhateverXe Graphics 0.4.1 安装包 + Compat 0.8.0 / 0.8.1
Tools/               安装、自检、一键安装脚本                      → Tools/README.md
Tools/diagnostics/   排查工具（采样器 / panic / ESP / 背光 / HID）  → Tools/diagnostics/README.md
Packages/MIFS/       **Fn+F6/F7/F8 热键**组件（SSDT + kext + 守护进程 + 安装） → Packages/MIFS/README.md
docs/                安装、功能、实现、失败尝试、睡眠调查、亮度调优、参考资料、已知问题
AI-INSTALL.md        给 AI 的一键安装说明（可直接粘贴给助手）      → AI-INSTALL.md
LICENSES/            第三方许可证说明
```

## 5. 我们改了什么

| 改动 | 原因 | 详见 |
|---|---|---|
| `SSDT-ADPX`（发布 `ACPI0003`） | `SMCBatteryManager` 需要同时找到电池与适配器才会启动，否则直接放弃 | [docs/03](docs/03-实现说明.md) |
| `SSDT-BRTN`（接管 `_Q15/_Q16`） | EC 层亮度键不会经过 PS2/HID，只能在 ACPI 里转发 | [docs/03](docs/03-实现说明.md) |
| 亮度下限 6.25% | 原驱动把亮度滑到底会直接黑屏 | [docs/06](docs/06-亮度调优.md) |
| softsleep 背光修复 | 唤醒时 `PP_CONTROL bit0` 未就绪导致背光永不恢复 | [docs/03](docs/03-实现说明.md) |
| 系统睡眠调查 | 结论：本机不可用（驱动层），已彻底记录 | [docs/05](docs/05-睡眠调查.md) |
| **Fn+F6/F7/F8 热键**（`Packages/MIFS`） | EC 查询在厂商 SSDT 里，需自建 SSDT + kext + 守护进程桥接 | [Packages/MIFS](Packages/MIFS/README.md) |

## 6. 已知问题

- **系统睡眠不可用**：睡着能醒，但唤醒后显示恢复失败 → WindowServer 看门狗 panic。已用 `disablesleep 1` 阻止误触发。
- **内置麦克风不可用**：无 SST/ADSP/DMIC 的 macOS 驱动栈；请用 USB 声卡或蓝牙耳机。
- **Fn 亮度键**：偶发无响应（EC 上报时序），可再按一次。
- **Fn+F6/F7/F8**：需要安装守护进程（见 §3.3）；首次用 F7 需授予屏幕录制权限。
- **开机亮度跳高**：旧驱动 NVRAM 残留导致，执行 `sudo nvram -d nmintelfb-brightness` 解决（见 §3.4）
- **合盖不黑屏**：`SleepDisabled=1` 导致系统不走合盖关屏路径，待修（见 [docs/08 §6.7](docs/08-已知问题.md)）
- **开机偶发 logd 看门狗报告**：非致命，可忽略（见 [docs/08 §6.6](docs/08-已知问题.md)）
- **外接屏热插拔可能卡死**：拔出外接显示器时偶发 WindowServer 卡死，待排查（见 [docs/08 §6.9](docs/08-已知问题.md)）
- **外接屏 HDR 会崩溃**：驱动层限制，请保持 SDR（见 [docs/08 §6.10](docs/08-已知问题.md)）
- **外接屏无声音**：HDMI/DP 音频驱动未挂载，待排查（见 [docs/08 §6.11](docs/08-已知问题.md)）
- **合盖不睡眠**：见上，合盖后会保持运行（注意散热）。

更多见 [docs/08-已知问题.md](docs/08-已知问题.md)。

## 7. 参考的项目

| 项目 | 用途 |
|---|---|
| [WilliamAlexanda/macOS-for-RedmiBook-Pro-15-2021](https://github.com/WilliamAlexanda/macOS-for-RedmiBook-Pro-15-2021) | 同机型 EFI、4 个 eDP 补丁、DVMT 修改方案 |
| [b00t0x/WhateverXe](https://github.com/b00t0x/WhateverXe) | Tiger Lake 原生驱动（本仓库基于 0.8.2） |
| [WhateverXe Graphics 0.4.1](https://github.com/b00t0x/WhateverXe) | `AppleIntelTGLGraphics` / `Framebuffer` / `Compat` 安装包 |
| [acidanthera/OpenCorePkg](https://github.com/acidanthera/OpenCorePkg) | 引导 |
| [acidanthera/Lilu](https://github.com/acidanthera/Lilu) · [VirtualSMC](https://github.com/acidanthera/VirtualSMC) · [AppleALC](https://github.com/acidanthera/AppleALC) · [BrightnessKeys](https://github.com/acidanthera/BrightnessKeys) · [VoodooPS2](https://github.com/acidanthera/VoodooPS2) · [NVMeFix](https://github.com/acidanthera/NVMeFix) · [RestrictEvents](https://github.com/acidanthera/RestrictEvents) · [BlueToolFixup](https://github.com/acidanthera/BrcmPatchRAM) | 基础 kext |
| [VoodooI2C/VoodooI2C](https://github.com/VoodooI2C/VoodooI2C) | 触摸板 |
| [OpenIntelWireless](https://github.com/OpenIntelWireless)（AirportItlwm / IntelBluetoothFirmware） | 无线与蓝牙 |
| [USBToolBox](https://github.com/USBToolBox/kext) · [RehabMan/OS-X-USB-Inject-All](https://github.com/RehabMan/OS-X-USB-Inject-All) | USB 定制 |
| [laobamac/SimpleHDA](https://github.com/laobamac/SimpleHDA) | 在 Tahoe 上恢复 AppleHDA |
| [1Revenger1/ECEnabler](https://github.com/1Revenger1/ECEnabler) | EC 电池字段读取 |
| [dortania/OpenCore-Post-Install](https://github.com/dortania/OpenCore-Post-Install) | SSDT-GPRW / 睡眠排查思路 |

## 7.1 子文档索引

| 文档 | 内容 |
|---|---|
| [EFI/README.md](EFI/README.md) | 日常版 EFI 说明 |
| [EFI-debug/README.md](EFI-debug/README.md) | 调试版 EFI 说明（啰嗦模式） |
| [AI-INSTALL.md](AI-INSTALL.md) | 给 AI 的一键安装说明 + 提示词 |
| [Tools/README.md](Tools/README.md) | 安装/自检/一键安装脚本 |
| [Tools/diagnostics/README.md](Tools/diagnostics/README.md) | 排查工具与判读方法 |
| [Patches/README.md](Patches/README.md) | 我们的补丁与第三方补丁 |
| [docs/01-安装指南.md](docs/01-安装指南.md) | 完整安装步骤 |
| [docs/02-功能状态.md](docs/02-功能状态.md) | 功能可用性对照 |
| [docs/03-实现说明.md](docs/03-实现说明.md) | 每处改动的原理与代码 |
| [docs/04-失败与成功的尝试.md](docs/04-失败与成功的尝试.md) | 实验报告 |
| [docs/05-睡眠调查.md](docs/05-睡眠调查.md) | 睡眠问题完整调查 |
| [docs/06-亮度调优.md](docs/06-亮度调优.md) | 亮度曲线与下限 |
| [docs/07-参考资料与许可证.md](docs/07-参考资料与许可证.md) | 上游项目与版本 |
| [docs/08-已知问题.md](docs/08-已知问题.md) | 已知问题与处理 |
| [docs/09-EC热键抓取指南.md](docs/09-EC热键抓取指南.md) | 在 Windows 下抓取 EC 热键寄存器（Fn+F6/F7/F8）的方法 |
| [Packages/MIFS/README.md](Packages/MIFS/README.md) | **Fn+F6/F7/F8 热键组件**：原理、安装、避坑 |
| [docs/11-Fn键总览.md](docs/11-Fn键总览.md) | **Fn 键总览**：亮度键与热键的两种拦截模式对比 |
| [docs/10-Fn热键实现计划.md](docs/10-Fn热键实现计划.md) | Fn 热键的完整排查过程与实现记录 |
| [LICENSES/第三方许可证说明.md](LICENSES/第三方许可证说明.md) | 许可证分层 |
| [README §10](README.md#10-声明) | AI 生成声明、商标声明、非官方声明、使用范围、工具声明 |

## 8. 许可证

- 本仓库的**原创内容**（SSDT 源码、脚本、文档、我们对 WhateverXe 的补丁）：**MIT**（见 `LICENSE`）
- 第三方组件保留各自许可证，详见 [LICENSES/第三方许可证说明.md](LICENSES/第三方许可证说明.md)
- `Drivers/` 内的 Apple 原厂 kext（由 WhateverXe Graphics 安装包提供）**版权归 Apple**，仅作兼容性研究用途，请勿再分发
- 本仓库的 `EFI/` 中已清空序列号，**请自行生成**，不要使用他人序列号

## 9. 免责声明

本项目为个人单机实践记录，按现状提供，不保证适用于任何其他机器。刷写 BIOS、修改 UEFI 变量、
安装内核扩展均有风险，请自行备份并承担后果。**本项目仅供个人学习使用，禁止商业用途。**
使用者应自行确保其行为符合当地法律法规，**因使用本项目（含违反相关法律法规）所产生的一切后果由使用者自行承担**。

## 10. 声明

### 10.1 AI 辅助生成声明

- 本仓库的 `README.md` 与 `docs/` 下的文档，**由 DeepSeek 模型生成初稿**，经项目维护者实测校订后定稿。
- `Tools/diagnostics/` 中的部分诊断脚本、`Patches/ours/` 的补丁，以及睡眠/亮度/电池等问题的排查过程，
  **由 DSH（DeepSeek Harness）协助完成**。
- 所有配置改动、参数取值与结论，均在本机（1 台 RedmiBook Pro 15 2021）**实测验证**后才写入；
  未能验证的内容已明确标注为"未测试"或"推测"。
- AI 生成内容可能存在错误或过时信息，**请以你自己的实测结果为准**；发现错误欢迎提 Issue。

### 10.2 商标声明

- **Apple、macOS、MacBook Pro、Metal、Finder、Safari** 是 Apple Inc. 在美国及其他国家和地区注册的商标。
- **Intel、Intel Core、Iris Xe** 是 Intel Corporation 的商标。
- **Xiaomi、Redmi、RedmiBook** 是小米科技有限责任公司（Xiaomi Corporation）的商标。
- **Wi-Fi** 是 Wi-Fi Alliance 的商标；**Bluetooth** 是 Bluetooth SIG, Inc. 的商标。
- **DisplayPort / eDP** 是 VESA 的商标。
- 文中出现的其他商标、产品名称与公司名称，均归其各自所有者所有。

本文档仅在描述性意义上使用上述名称（说明兼容的硬件与系统），**不表示任何商标授权**。

### 10.3 非官方声明

本项目是**个人非官方项目**，与下列主体**均无隶属、合作或背书关系**：

- Apple Inc.
- Intel Corporation
- 小米科技有限责任公司
- 本仓库"参考的项目"中列出的任何上游作者

### 10.4 使用范围

- 本项目**仅供个人学习、研究与技术交流使用**。
- **禁止商业用途**：不得将本项目（含其中的第三方组件）用于任何盈利、售卖或再分发行为。
- 本仓库不提供 macOS 系统安装包。`Drivers/` 中第三方安装包内的 Apple 原厂组件版权归 Apple，
  请勿单独提取或另行分发。
- 请在遵守你所在地区法律法规的前提下使用本项目。
- 使用者应自行确保其使用行为符合当地法律法规；**因违反相关法律法规所产生的一切后果，由使用者自行承担，本项目作者不承担任何责任。**

### 10.5 使用的工具声明

| 工具 | 用途 | 授权 |
|---|---|---|
| [OpenCore](https://github.com/acidanthera/OpenCorePkg) | 引导器 | BSD-3-Clause |
| [OpenCore Configurator](https://github.com/ic005k/OCAuxiliaryTools) / ProperTree | 编辑 `config.plist` | 各自许可 |
| [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) | 生成 SMBIOS | MIT |
| [Hackintool](https://github.com/benbaker76/Hackintool) | 查看 PCI / 显示 / USB | GPL |
| `iasl`（[ACPICA](https://github.com/acpica/acpica)） | 编译 / 反编译 SSDT | Intel 开源许可（BSD 类） |
| `ioreg`、`kmutil`、`pmset`、`plutil`、`PlistBuddy`、`diskutil`、`fsck_msdos` | macOS 自带诊断与系统工具 | Apple 系统组件 |
| `python3`、`bash`、`xxd`、`base64`、`zip` | 脚本与打包 | 各自开源许可 |
| **DeepSeek**（模型）、**DSH / DeepSeek Harness**（智能体环境） | 文档生成、脚本编写、问题排查 | 见服务条款 |

> 上述工具仅用于**制作、配置与诊断**，不随本仓库分发（macOS 自带工具除外）。

## 11. 版本

| 版本 | 驱动 | 说明 |
|---|---|---|
| **v0.3.1**（当前） | WhateverXe **0.8.3** + Compat 0.8.1 | 修复开机亮度跳高（NVRAM 残留）；新增亮度记录器；含 v0.3.0 的 Fn 热键 |
| v0.3.0 | WhateverXe 0.8.3 + Compat 0.8.1 | Fn+F6/F7/F8 热键（MIFS）+ 显示睡眠修复 |
| v0.2.1 | WhateverXe 0.8.3 + Compat 0.8.1 | 修复显示睡眠唤醒后黑屏（背光不恢复）|
| v0.2.0 | WhateverXe 0.8.3 + Compat 0.8.1 | 跟随上游 0.8.3（显示睡眠有问题，请勿单独使用） |
| v0.1.0 | WhateverXe 0.8.2 + Compat 0.8.1 | 首个可用版本 |

详细变更见 [CHANGELOG.md](CHANGELOG.md)。升级驱动请用 `Tools/port-to-new-version.sh`。

### 11.1 如何回退到旧版本

每个 Release 的 **Source code (zip)** 就是该版本的**完整仓库快照**（含 EFI、驱动、工具、文档，不含任何新版本代码），
下载解压即可直接使用：

| 想回到 | 下载 |
|---|---|
| WhateverXe 0.8.2 | [v0.1.0](https://github.com/xhc07/RedmiBook-Pro-15-2021-macOS26/releases/tag/v0.1.0) 的 Source code (zip) |
| WhateverXe 0.8.3 | [v0.2.0](https://github.com/xhc07/RedmiBook-Pro-15-2021-macOS26/releases/tag/v0.2.0) 的 Source code (zip) |

或者用 git：

```bash
git clone https://github.com/xhc07/RedmiBook-Pro-15-2021-macOS26.git
cd RedmiBook-Pro-15-2021-macOS26
git checkout v0.1.0     # 回到 0.8.2 版本
```

> 注意：换回旧版 kext 后，`AppleIntelTGLCompat` 也要跟着换（0.8.2 ↔ Compat 0.8.1 是兼容的，0.8.3 也用 0.8.1），
> 并用 `Tools/install-compat.sh 0.8.1` 重建 AuxKC。
