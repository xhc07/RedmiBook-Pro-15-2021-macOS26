# MIFSAudioProbe —— 显示音频只读探测

> 用途：读取 Intel GPU 的显示音频寄存器，判断"外接屏为什么没声音"。
> **只读，不写任何寄存器。**

## 用法

```bash
# 1. 编译（需要 MacKernelSDK）
./build.sh

# 2. 放进 EFI/OC/Kexts/，并在 config.plist 的 Kernel.Add 注册
#    Info.plist 里只有 GPU personality（8086:9A49）

# 3. 重启后读取
ioreg -l -w0 -c MIFSAudioProbe | grep -E 'ProbeDevice|AudioRegs'
```

## 输出示例（本机 2026-11-19 实测）

```
ProbeDevice     = 39497 (0x9A49)
AudioRegs65000  = 0x65000: 0x0070FA60
                  0x65004: 0x00120000
                  0x65010: 0x00000044
                  0x65020: 0x80862812   ← 厂商 0x8086 + 显示音频 codec 0x2812
                  0x65024: 0x00100000
                  0x6504C: 0xFFFFFFFF
                  0x6507C: 0x00FF000F
AudioRegs64000  = 0x64000: 0x80000007
                  0x64004: 0x0C10023F
```

## 关键发现

- **0x65020 = 0x80862812**：GPU 里存着显示音频 codec 的厂商/设备 ID（Intel 8086:2812）
- 但 framebuffer 的 `audio-codec-info` 属性是 **0**
- → 说明 **codec 已知，但没有被"导出"给 macOS 音频栈**

## 踩过的坑

| 坑 | 说明 |
|---|---|
| `IOMatchCategory` | 必须设独立值，否则会抢走 AppleHDAController（曾导致内置音频消失） |
| 符号缺失 | 删除函数实现但保留调用 → kext **静默不加载**（开机日志看不出来） |
| 运行时加载 | macOS 26 需要 System Settings 批准 + 重启 |
| BAR 映射 | 未上电的设备读回 `0xFFFF`（HDA 控制器在 D3 时） |

## 下一步（未完成）

尝试把 `audio-codec-info` 设成 `0x80862812`，看音频栈是否识别显示 codec。
