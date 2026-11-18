# ACPI 分析脚本（Windows 侧导出 → 定位热键）

> 来源：本机在 Windows 下用 RW-Everything 导出全部 ACPI 表后，用这两个脚本拆分并定位热键。
> 正是靠它们发现：**热键的 EC 查询定义在厂商 SSDT 第 21 张**（不是 DSDT），从而打开了 macOS 侧的实现路径。

## 背景

Windows 导出得到的是一个**合并文件**（35 张表串联，531,038 字节），需要先按 ACPI 头拆开。

## 用法

### 1. 拆分合并文件

```bash
python3 split_acpi.py AcpiTbls.bin outdir/
```

按标准 ACPI 头（`Signature` + `Length`）切分，输出如：

```
00_XSDT_XMCC1806.bin
01_FACP_XMCC1806.bin
...
21_SSDT_XMCC1806.bin   ★ 热键核心表
35_DSDT_XMCC1806.bin
```

### 2. 扫描热键线索

```bash
python3 scan_acpi.py outdir/
```

检查内容：

| 检查项 | 说明 |
|---|---|
| GUID `46C93E13-EE9B-4262-8488-563BCA757FEF` | RedmiBook 键盘事件 GUID |
| `_WDG` / `_WED` / `PNP0C14` / `MIFS` | WMI 设备与事件方法 |
| `_Qxx` 方法与 `WMID.QV20(n)` 参数 | EC 查询 → 事件号 |

## 本机结果（供对照）

```
21_SSDT_XMCC1806.bin:
  Device (WMID)  _HID=PNP0C14  _UID="XAPe"
  _Q2B → WMID.QV20(1)    Fn+F6 投屏
  _Q66 → WMID.QV20(2)    Fn+F7 截图
  _Q08 → WMID.QV20(3)    Fn+F8 任务视图
```

完整分析见 [docs/10-Fn热键实现计划.md](../../docs/10-Fn热键实现计划.md)、
[docs/09-EC热键抓取指南.md](../../docs/09-EC热键抓取指南.md)。

## 注意

- RW-Everything 保存二进制时 **End / Length 是十六进制**（如 `FE0B03FF` / `100`），
  不改会存成错误大小（这是本次踩过的坑）
- 同名保存会产生 `.BAK`，别被文件名误导
