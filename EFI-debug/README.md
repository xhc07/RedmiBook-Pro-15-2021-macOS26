# EFI-debug（调试版 / Verbose）

> 返回主文档：[README.md](../README.md) · 日常版：[../EFI/](../EFI/README.md)

和 `EFI/` **完全相同**，只多了两个启动参数：

| 参数 | 作用 |
|---|---|
| `-v` | 啰嗦模式：开机滚动打印内核与 kext 加载日志 |
| `debug=0x100` | 让内核把调试信息输出到屏幕/串口，panic 时信息更完整 |

```
keepsyms=1 -vi2c-force-polling alcid=38 alcverbs=1 -allow3d -disablegfxfirmware \
-wex-tgl-edp-keep -wex-edp-fix-training -wex-edp-no-extcap -v debug=0x100
```

## 什么时候用

- 开机黑屏、卡住、需要看卡在哪一步
- 某个 kext 没加载、属性缺失（配合 `Tools/diagnostics/check-driver-state.sh`）
- 向上游报 bug 前抓日志

## 注意

- 启动会明显变慢（滚屏 + debug 输出）
- 不要长期用它日常使用；排查完换回 `EFI/`
- 两个版本**其余内容完全一致**（kext、ACPI、config 的其它字段）
