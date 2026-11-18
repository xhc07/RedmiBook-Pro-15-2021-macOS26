# MIFS —— Fn+F6 / F7 / F8 热键支持

> 让 RedmiBook Pro 15 2021 的 **Fn+F6（投屏）/ F7（截图）/ F8（任务视图）** 在 macOS 下可用。

## 原理

```
按 F6/F7/F8
  └─ EC 发出查询字节（_Q2B / _Q66 / _Q08）
       └─ 厂商 SSDT 第 21 张里定义为 WMID.QV20(1/2/3)
            └─ 我们用 ACPI Patch 把它改名为 XQxx，自建 SSDT 重定义：
                 _Q2B → Notify(\_SB.HKEY, 1)
                 _Q66 → Notify(\_SB.HKEY, 2)
                 _Q08 → Notify(\_SB.HKEY, 3)
                      └─ MIFSKeys.kext 匹配 HKEY（_HID = MIFS0001）
                           └─ 收到 ACPI 通知 → 写 IORegistry 属性 EventCount/LastEvent
                                └─ mifskeysd 读取 → 触发 macOS 动作
```

**与 WhateverXe 无关**，互不依赖。

## 组件

| 文件 | 作用 |
|---|---|
| `acpi/SSDT-KEYS.dsl` | 建 `HKEY` 设备 + 三个 `_Qxx` 重定义 |
| `acpi/SSDT-KEYS.aml` | 编译产物（275 字节） |
| `kext/MIFSKeys.cpp` | kext 源码（接收 ACPI 通知） |
| `kext/Info.plist` | kext 的 IOKit 匹配（`IONameMatch = MIFS0001`） |
| `kext/build-kext.sh` | 编译脚本（复用 MacKernelSDK） |
| `daemon/mifskeysd.c` | 守护进程源码 |
| `daemon/mifskeysd` | 编译产物 |
| `daemon/org.mifs.mifskeysd.plist` | LaunchAgent（开机自启） |

## 动作映射

| code | 键 | 动作 | 实现 |
|---|---|---|---|
| 1 | Fn+F6 | 打开显示器设置（投屏入口） | `open x-apple.systempreferences:com.apple.Displays-Settings.extension` |
| 2 | Fn+F7 | 区域截图到剪贴板 | `screencapture -i -c` |
| 3 | Fn+F8 | Mission Control | `open -a "/System/Applications/Mission Control.app"` |

## 安装

1. **ACPI**：把 `acpi/SSDT-KEYS.aml` 放进 `EFI/OC/ACPI/`，并在 `config.plist` 加：
   - `ACPI > Add`：`SSDT-KEYS.aml`
   - `ACPI > Patch` ×3：`_Q2B→XQ2B`、`_Q66→XQ66`、`_Q08→XQ08`
     （**必须限定** `TableSignature=SSDT`、`OemTableId=XMCC1806`、`Count=1`）
2. **Kext**：`MIFSKeys.kext` 放进 `EFI/OC/Kexts/`，`Kernel > Add` 加条目
3. **守护进程**：
   ```bash
   sudo cp daemon/mifskeysd /usr/local/bin/
   sudo cp daemon/org.mifs.mifskeysd.plist /Library/LaunchAgents/
   sudo chown root:wheel /Library/LaunchAgents/org.mifs.mifskeysd.plist
   ```
4. 重启

## 验证

```bash
# kext 是否匹配上
ioreg -l -c MIFSKeys | grep -E 'EventCount|LastEvent|MIFSKeysReady'
# 守护进程
pgrep -fl mifskeysd
tail -f /tmp/mifskeysd.log     # 按键时应出现 "event N"
```

## 已知注意

1. **开机时 EventCount 可能已有若干次**（固件初始化会发这些查询），守护进程首次读取时作为基线，不会误触发
2. **守护进程每 100ms 轮询一次** IORegistry 属性（CPU ≈ 0.01%）；未来可换 IODataQueue 做到零轮询
3. `screencapture` 首次使用需要授予**屏幕录制**权限
4. 截图/任务视图/显示器设置都是用户态功能，所以必须有用户态桥接进程（亮度不需要，因为 macOS 有内核级亮度机制）

## 技术要点（避坑）

| 坑 | 说明 |
|---|---|
| kext 必须 `registerService()` | 否则不进 IORegistry，用户态匹配不到 |
| 必须 `KMOD_EXPLICIT_DECL` | 否则缺 `_kmod_info`，内核拒绝加载 |
| `IONameMatch` 用 `_HID` 值 | macOS 把 `_HID`（`MIFS0001`）当作设备 name，不是 ACPI 名字 `HKEY` |
| ACPI 补丁要限定表 | 不限定会误伤其它 SSDT 的同名 `_Qxx` |
| ACPI 通知码方向 | `0x86` = 增强亮度、`0x87` = 降低（测试时踩过坑） |

## 试错过程（避免重复走）

| 阶段 | 尝试 | 结果 |
|---|---|---|
| 1 | HID 抓取（过滤/全量两轮） | ❌ 无事件，无厂商页 |
| 2 | Windows 直读 EC RAM `0xFE0B0300` | ❌ 与热键无关 |
| 3 | 在 DSDT 里找 `_Qxx` | ❌ 只有电池/盖子 |
| 4 | 取证官方 OSD（驱动 + 用户态） | 🔍 内核只写注册表，用户态走 WMI |
| 5 | 分析 35 张 ACPI 表 | ✅ **SSDT 21** 找到 `WMID` + 三个 `_Qxx` |
| 6 | 编码测试 v1（全发 0x87） | ❌ 都变暗，无法区分（方向错） |
| 7 | 编码测试 v2（0x86/0x87 混用） | ✅ 映射确认 |
| 8 | ACPI Debug dump 方案 | ❌ 开机卡死（日志洪峰） |
| 9 | kext 首次编译 | ⚠️ 缺 `_kmod_info` → 拒绝加载 |
| 10 | kext 加载后不匹配 | ⚠️ 缺 `registerService()` + 匹配名错 |
| 11 | 修正后 | ✅ 全部可用 |
