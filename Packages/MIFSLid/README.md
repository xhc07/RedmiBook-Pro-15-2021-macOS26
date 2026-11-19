# MIFSLid —— 合盖关屏守护进程

> 解决"合上盖子屏幕不黑"的问题。

## 为什么需要它

本机系统睡眠在驱动层不可用（见 `docs/05`），必须 `SleepDisabled = 1`。
副作用是 macOS 不再走"合盖 → 关屏"路径：

```
pmset: SleepDisabled = 1
ioreg: AppleClamshellCausesSleep = No
```

**ACPI 层本身是完整的**（Dump 自本机 DSDT）：

```asl
Method (_Q80) {                       // 合盖 EC 查询
    LIDS = ECRD (RefOf (LSTE))
    ^^^GFX0.GLID (LIDS)               // 通知显卡驱动
    Notify (LID0, 0x80)               // 通知盖子状态变化
}
```

缺的是最后一步动作（驱动没处理 CLID），所以用用户态守护进程补上。

## 原理

```
每 500ms 读 IOPMrootDomain 的 AppleClamshellState
   合盖 → pmset displaysleepnow       （关屏）
   开盖 → caffeinate -u -t 1          （唤醒屏幕）
```

## 安装

```bash
sudo bash Packages/MIFSLid/install.sh
```

卸载：

```bash
sudo bash Packages/MIFSLid/uninstall.sh
```

## 验证（本机实测）

```
21:05:33  合盖 → mifslidd: lid closed -> displaysleepnow    → 屏幕熄灭
21:05:42  开盖 → mifslidd: lid opened -> wake display       → 屏幕亮起
```

查看日志：`tail -f /tmp/mifslidd.log`

## 踩过的坑

| 坑 | 说明 |
|---|---|
| 读不到状态 | 最初用 `IORegistryEntryFromPath("IOService:/IOResources/IOPMrootDomain")`，**路径错**（IOPMrootDomain 不在 IOResources 下）→ 改用 `IOServiceMatching("IOPMrootDomain")` |
| 属性类型 | `AppleClamshellState` 可能是 CFBoolean 或 "Yes"/"No" 字符串，两种都要处理 |

## 开销

500ms 轮询一次 IOKit 属性，CPU 占用可忽略（<0.01%）。
