# audiolog —— 开机音频状态记录器

> 用途：排查"外接屏音频"这类**只在开机瞬间可能生效**的问题。

## 用法

```bash
sudo cp audiolog.sh /usr/local/bin/
sudo cp local.audiolog.plist /Library/LaunchDaemons/
sudo chown root:wheel /Library/LaunchDaemons/local.audiolog.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/local.audiolog.plist
# 重启后查看
cat /var/log/audiolog.txt
```

每 2 秒记录一次，共 3 分钟：

```
21:10:31 codec=0 hdmi=0 engDP=0 aci=
21:11:23 codec=1 hdmi=0 engDP=0 aci=<00000000>
```

字段含义：`IOHDACodecDevice` 数量 / `AppleHDAHDMI_DPDriver` / `AppleHDAEngineOutputDP` /
framebuffer 的 `audio-codec-info`。

## 本机实测结论（2026-11-19，插着 HDMI 开机）

`codec` 始终 `0→1`（只有模拟），`hdmi` 恒 0，`aci` 恒 `0x00000000`
→ 外接屏音频在驱动层完全未实现（见 `docs/08 §6.11`）。
