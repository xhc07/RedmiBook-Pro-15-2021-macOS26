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
