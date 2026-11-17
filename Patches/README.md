# 补丁说明

## ours/

| 文件 | 内容 |
|---|---|
| `WhateverXe-tgl-brightness-and-softsleep.patch` | 我们对 WhateverXe 0.8.2 的源码改动：<br>1. 背光占空比下限重映射（最低 6.25%，消除死区）<br>2. softsleep 唤醒背光使能修复（`pp & 1` → 无条件置位 + 面板上电补置） |

应用方式：

```bash
git clone --branch 0.8.2 --depth 1 https://github.com/b00t0x/WhateverXe.git
cd WhateverXe
git apply /path/to/Patches/ours/WhateverXe-tgl-brightness-and-softsleep.patch
```

> 注意：`EFI/` 中预编译的 `WhateverXe.kext` 只包含第 1 项改动（亮度）；第 2 项（背光修复）
> 尚未并入预编译二进制，源码改动保留供参考与上游采用。

## third-party/

来自同机型仓库 [WilliamAlexanda/macOS-for-RedmiBook-Pro-15-2021](https://github.com/WilliamAlexanda/macOS-for-RedmiBook-Pro-15-2021)
的 4 个 eDP 补丁，原样保留（含 `all-in-one.patch` 与 `SHA256SUMS`）：

| 文件 | 作用 |
|---|---|
| `01-edp-fix-training-ddi-conflict.patch` | 点屏前 DDI A 电源复位 / 冲突处理 |
| `02-tgl-edp-keep-softsleep.patch` | 沿用固件链路（`-wex-tgl-edp-keep`）+ 软睡眠（`-wex-tgl-edp-softsleep`） |
| `03-redmibook-bpc-backlight.patch` | 强制固件位深 + 背光周期重映射 |
| `04-edp-retrain-extcap.patch` | 屏蔽 DPCD `0x00E` bit7，重训按 400 µs 轮询 |

版权归其作者，按其仓库许可证使用。

---

← 返回主文档：[README.md](../README.md) · 子文档索引见 [README §7.1](../README.md#71-子文档索引)
