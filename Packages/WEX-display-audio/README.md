# WEX 显示音频移植参考（未编译）

> 上游已有可用实现，本目录只是**参考代码归档**，尚未集成到我们的 WEX 构建。

## 文件

| 文件 | 来源 | 行数 | 状态 |
|---|---|---|---|
| `kern_hdmi_audio_adl.cpp` | `jkbuha/WhateverXe-contrib` 提交 `94b8fb6` | 682 | ✅ ADL-P 上已成功 |
| `kern_hdmi_audio.hpp` | 同上 | 20 | 接口 |
| `kern_hdmi_audio_tgl_v5.cpp` | `skmaiti2050/WhateverXe-TigerLakeH` 分支 `wex-0.8.2-hdmiaudio`（v5） | 782 | ⚠️ TGL 仍在调试 |

## 集成步骤（待做）

1. 文件加入 WEX 构建（`WhateverXe/` 目录）
2. `kern_host.cpp`：`processKernel` 里调用 `WEXHDMIAudio::wakeEarly(gpu)`
3. `kern_xe.cpp`：注册 `processFramebuffer` / `processController` / `processMain` 钩子
4. 启动参数：`-wex-hdmi-audio`
5. 重新编译 WEX → 装 EFI → 测试

## 关键寄存器

| 寄存器 | 作用 |
|---|---|
| `AUDIO_PIN_BUF_CTL` (0x48414) bit 31 | 唤醒显示 codec（必须在 AppleHDA 探测前） |
| `HSW_AUD_CHICKENBIT` (0x65F10) bit 15 | codec wake override 脉冲 |
| `AUD_FREQ_CNTRL` (0x65900) | **TGL 特有**：坏值 `0x9010` → 改 `0x8010` |
| `AUD_PIN_ELD_CP_VLD` (0x650C0) | ELD 有效 + 音频输出使能 |
| `PWR_WELL_CTL2` (0x45404) | 音频寄存器所在电源井 |

详见 [docs/12-上游进展与可移植方案.md](../../docs/12-上游进展与可移植方案.md)。
