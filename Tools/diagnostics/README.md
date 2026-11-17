# 诊断工具集（过程记录）

> 这些脚本是排查过程中实际用过的工具，整理成可复用的形式。
> 返回主文档：[README.md](../../README.md) · 安装脚本见 [../README.md](../README.md)

## 用到的核心方法

| 方法 | 做什么 | 为什么有效 |
|---|---|---|
| **ioreg 属性法** | 读驱动暴露的 `TGL*` 属性（如 `TGLEDPKept`、`TGLSoftSleepReady`、`TGLEDPExtCapMasked`） | 直接确认某个 hook 是否装上、是否触发过，比看日志可靠 |
| **采样 + 时间跳变** | 每秒写一次状态到磁盘，事后看时间戳是否连续 | 系统真正进入 S3 时 CPU 停止调度 → 采样中断 → 日志出现跳变；连续则说明"根本没睡" |
| **panic 栈反向定位** | 从 panic 栈里的符号（`SafeForceWake`、`wrapTGLHostSubmit`）反推是哪条路径 | 比猜配置快得多 |
| **对照实验** | 每次只改一个变量（关加速 / 去电池 SSDT / 换驱动版本） | 排除法，避免"改了一堆不知道哪个起作用" |
| **HID 嗅探** | 抓 IOHIDSystem 事件，确认按键到底有没有到达系统 | 区分"EC 层没上报"和"上报了但没映射" |
| **ESP 健康检查** | fsck + 挂载 + 校验 config | 强制断电后 FAT32 变脏是黑苹果最常见的"莫名启动失败"原因 |

## 工具清单

### 1. `sleeptrace.sh` —— 睡眠状态采样器

```bash
sudo ./sleeptrace.sh 600 /tmp/sleeptrace.log   # 采样 600 秒
```

每秒记录：`deep_idle`（Deep Idle 计数）、`disp`（IODisplayWrangler 电源态）、
`fb`（帧缓冲电源态）、`ws`（WindowServer PID）。

**判读**：用 `analyze-sleeptrace.py` 分析。

### 2. `analyze-sleeptrace.py` —— 采样日志分析

```bash
python3 ./analyze-sleeptrace.py /tmp/sleeptrace.log
```

输出时间跳变列表：

- **无跳变** → 系统从未真正挂起（卡在睡眠过渡 / 或被驱动阻塞）
- **跳变 ≥ 20 秒** → 系统确实进入过睡眠（这是判断"S3 是否工作的关键证据"）
- **跳变 3–11 秒** → 短暂卡顿（通常是 GPU/驱动阻塞）

### 3. `check-driver-state.sh` —— 驱动状态快照

```bash
./check-driver-state.sh
```

一次性导出：kext 版本、`TGL*` 关键属性、显示/加速、背光、电池、输入设备、电源策略。
**用途**：改配置前后各跑一次，diff 就知道变了什么。

### 4. `check-esp.sh` —— EFI 分区健康检查/修复

```bash
sudo ./check-esp.sh            # 自动找 200MB EFI 分区
sudo ./check-esp.sh disk2s1    # 或手动指定
```

做三件事：`fsck_msdos -fy` 修复 → 挂载 → 检查多余目录与 config 合法性。
**典型场景**：强制断电后 ESP 挂不上、或启动莫名失败。

### 5. `dump-panic.sh` —— panic 摘要

```bash
./dump-panic.sh
```

列出最近的 `.panic`/`.gpuRestart`/`.spin`，打印最新 panic 前几行与最近的睡眠/唤醒记录。
若 panic 被另存为 `.rtf`，用：

```bash
textutil -convert txt -stdout ~/Desktop/panic.rtf | head -5
```

### 6. `fnprobe.sh` —— Fn 键一键探测

```bash
sudo ./fnprobe.sh 60     # 抓 60 秒，同时记录 HID 事件与亮度变化
```

结束后自动汇总三段：按键类 HID 事件、亮度变化、**厂商页 0xFF00+**（判断按键是否到达系统）。
输出文件：`/tmp/fnprobe_hid.log`、`/tmp/fnprobe_bright.log`。

**实测结论（本机）**：

| 键 | 结果 |
|---|---|
| Fn+F4/F5（亮度） | 亮度每档 ±128 |
| Fn+F1/F2/F3（静音/音量） | `PAGE=0x0C` 的 Mute / Volume Down / Up |
| Fn+F6/F7/F8（投屏/截图/任务视图） | **无任何 HID 事件、无厂商页** → EC 私有协议 |
| Fn+F9/F10（触控板/键盘灯） | 无 HID，EC 硬件直接生效 |

### 7. `brightctl` —— 亮度读写（源码 `brightctl.c`）

```bash
./brightctl            # 读当前亮度
./brightctl 0.6        # 设为 60%
```

走 `IODisplaySetFloatParameter` / `IODisplayGetFloatParameter`，用于**验证背光驱动是否响应**。
（注意：它只改占空比，不改背光使能位 `PP_CONTROL bit2`，所以"背光使能为 0"时改了也不亮——这正是我们定位问题的关键实验之一。）

### 8. `brightd` —— 亮度恢复守护进程（源码 `brightd.c`）

监听系统唤醒，唤醒后重新施加一次亮度值。
**用途**：如果你的机器唤醒后背光丢失，可用它做兜底恢复。

### 9. `hidsniff` / `hidsniff2` —— HID 事件嗅探（源码同名 `.c`）

```bash
./hidsniff      # 打印原始 HID 事件（usage page / usage / value）
./hidsniff2     # 第二版：加入设备名与时间戳
```

**用途**：判断 Fn 键、亮度键到底有没有到达 HID 层。
我们用它确认了「Fn 亮度键不经过 PS2/HID，而是 EC 触发的 ACPI 查询（`_Q15`/`_Q16`）」——
这直接决定了后来走 `SSDT-BRTN` 而不是改键码表。

## 一次完整的睡眠排查流程（实测有效）

```bash
# 1. 记录基线
./check-driver-state.sh > /tmp/before.txt

# 2. 启动采样器（另开终端）
sudo ./sleeptrace.sh 300 /tmp/sleeptrace.log

# 3. 手动触发睡眠（苹果菜单或 pmset sleepnow），观察 60-90 秒后唤醒/强制重启

# 4. 分析
python3 ./analyze-sleeptrace.py /tmp/sleeptrace.log
./dump-panic.sh

# 5. 对比
./check-driver-state.sh > /tmp/after.txt && diff /tmp/before.txt /tmp/after.txt
```

## 注意

- 这些脚本都**只读**系统状态（除了 `check-esp.sh` 会 fsck 并挂载），不会改配置
- `brightd` 需要 root（写 IOKit 显示参数）
- 采样器本身开销极小（每秒 3–4 次 ioreg 查询），但仍建议只在排查时运行
