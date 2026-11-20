## Tiger Lake-H35 (i5-11300H, 9A49, eDP): DMC fixes the deadlock, Deep Idle sleeps now, but wake still dies in WindowServer

First of all, thank you to everyone in this thread — @b00t0x, @Aqpcet, @macintelk and others — for the detailed traces and for publishing the test methods. They are what made this testable on my side at all.

**Disclosure up front:** I am not a computer professional. Much of this testing was done with AI assistance (DeepSeek), on a **single machine**, in isolation. This text is AI-generated from my own logs; please treat it as a data point, not as an authoritative analysis.

### Machine

| | |
|---|---|
| Laptop | Xiaomi RedmiBook Pro 15 2021 (TIMI TM2017) |
| CPU / iGPU | i5-11300H (Tiger Lake-H35) / Iris Xe `8086:9A49` |
| Panel | 3200x2000 30-bit eDP (TL156MDMP01, DDI A), internal only |
| OS | macOS 26.7.3 (25G342), OpenCore, booted from an external USB SSD |
| Driver | WhateverXe 0.8.3 + WhateverXe Graphics 0.4.4, `-disablegfxfirmware -allow3d` |

### What I tried, and what happened

**1. DMC loader (following @Aqpcet and @macintelk).**
I embedded `tgl_dmc_ver2_12.bin` (19,760 bytes, main payload 4,460 dwords at 0x310) and loaded it after `hwInitializeCState`, plus a reload in `systemDidWake`.

My first version made the same mistake @Aqpcet described: I read the MMIO data array 44 bytes early, so every DMC event handler was written as zero. Result was the same as his: **the sleep deadlock was gone**, but wake panicked in `SafeForceWake`.

I then rebuilt it with the corrected table (`mmioaddr[20]` / `mmiodata[20]`, data at `header + 96 + 20*4`) and added `fixup_dmc_evt` for TGL (VBLANK_A `0x32` -> delayed `0x2e`). All 9 MMIO writes now read back correctly (`WEXTGLDMCMmioVerified = 9`). **Wake behaviour was unchanged** — this matches @Aqpcet's negative result.

**2. Getting macOS to actually use Deep Idle.**
This platform advertises **both** S3 and Modern Standby: DSDT has `Name(_S3)`, FACP flags are `0x0020C4E5` (bit 21 `LOW_POWER_S0_IDLE_CAPABLE` set), and Windows `powercfg /a` reports "S0 low power idle" available with S3 disabled. macOS picks S3, which is why an earlier S0ix attempt with `SSDT-DEEPIDLE` + S0ixStandby did nothing (`deep_idle_count` stayed 0).

Renaming `Name(_S3)` to `Name(XS3)` via an ACPI patch, plus `SSDT-DEEPIDLE` (`\_SB.LPS0` / `\_GPE.LXEN` returning 1 under Darwin) and S0ixStandby 0.5.4, does work: the machine now genuinely sleeps in Deep Idle, on battery, no deadlock:

```
22:37:49  Entering Sleep state due to 'Software Sleep' ... Using Batt (69%)  110 secs
22:39:39  Wake from Deep Idle [CDNVA] : due to RTC/Lid Open Using BATT (67%)
```

**3. But the wake is where it dies now.**
`pmset -g log` for that wake:

```
Delays to Sleep notifications:
  AppleIntelFramebuffer driver is slow (SetState to 1)   386 ms
  WindowServer timed out                                30000 ms
Delays to Wake notifications:
  AppleIntelMEClientController (SetState to 1)        12285 ms
  VoodooI2CHIDDevice (SetState to 1)                  12377 ms
```

WindowServer then gets 2 induced crashes and the userspace watchdog fires after 120 s:

```
userspace watchdog timeout: no successful checkins from WindowServer
(2 induced crashes) in 120 seconds
```

Visually: the panel content is still there, backlight is off, the pointer can move for a while, then everything is frozen.

**4. `-wex-tgl-edp-softsleep` and Deep Idle appear to be mutually exclusive here.**
With softsleep enabled the sleep transition never completes — `Failure during wake: 0x00000027 : Some drivers failed to handle setPowerState panic`, and then the usual `SafeForceWake` RENDER-domain panic. Without softsleep, Deep Idle sleeps fine and only the wake fails, as above.

**5. Two smaller observations that may save someone time.**
- `-disablegfxfirmware` is **mandatory** on this machine: removing it left the system with no acceleration and corrupted colours (GuC firmware path appears broken for this TGL configuration).
- Removing `-vi2c-force-polling` changed nothing, despite 12-18 s `VoodooI2CHIDDevice` delays in the wake trace.
- `pmset` sometimes logs a phantom AC at re-sleep on battery (`Using AC (Charge:0%)`, around 2.5 min after the first sleep). Forcing the ACPI `_PSR` of a fake `ACPI0003` device to return 0 under Darwin reduced it, but did not change the wake failure.

### Questions

1. Is there a way to make WEX **skip the full modeset** on a Deep Idle wake (or to treat it like the softsleep partial-modeset path, without softsleep blocking Deep Idle entry)? That seems to be the remaining blocker: display is never re-advertised before WindowServer's 30 s timeout.
2. Is `AppleIntelMEClientController` taking 12-18 s at wake expected, and is it on the critical path?
3. Does the DMC event-handler table need to be reloaded at a different point in the wake sequence than `systemDidWake`?

Thanks again for all the work in this thread — if any of this is useful I can provide fuller logs (`pmset -g log` windows, panic backtraces).

---

**已发布**：https://github.com/b00t0x/WhateverXe/issues/157#issuecomment-7043458583
（2026-11-20 23:30，使用 classic token，`public_repo` 权限）
