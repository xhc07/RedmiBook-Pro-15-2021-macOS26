# EFI（日常版 / Quiet）

> 返回主文档：[README.md](../README.md)

- **默认使用这个版本**
- 没有 `-v` 与 `debug=0x100`，开机不滚日志，启动更快
- 保留 `keepsyms=1`（**不可删**，`SimpleHDA` 依赖它，否则没有声音）
- 需要排查问题时请改用 [../EFI-debug/](../EFI-debug/README.md)

```
keepsyms=1 -vi2c-force-polling alcid=38 alcverbs=1 -allow3d -disablegfxfirmware \
-wex-tgl-edp-keep -wex-edp-fix-training -wex-edp-no-extcap
```

## 显示睡眠（重要）

`-wex-tgl-edp-softsleep` **必须保留**：它让显示器睡眠只关背光、保留链路，唤醒时只做 partial modeset。

配合本仓库 WhateverXe 中的背光修复（唤醒后无条件置 `PP_CONTROL` bit2），显示睡眠可正常恢复。
去掉这个参数会走"完整链路重训"，本机重训后 WindowServer 拿不到显示 → 看门狗 panic。
