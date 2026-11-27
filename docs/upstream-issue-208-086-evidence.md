## 0.8.6 result on the same family: external DP works, internal eDP logs `Unsupported DDI` then `Phase 2 of link training failed`

**Disclosure:** single machine, isolated test, **AI-assisted**, text AI-generated from Chinese notes; I am not a computer professional. Thanks again to @b00t0x for pointing us at 0.8.6 — this run produced the first hard evidence I have on the internal-panel failure.

### Setup

- Xiaomi RedmiBook Pro 15 2021, i5-11300H, Iris Xe `8086:9A49`, **internal 3200x2000 30-bit eDP** (`TL156MDMP01`, DDI A), plus a 3840x2160 DP display over USB-C
- WEX **0.8.6** (official RELEASE, SHA-256 `81a1adff…a80457`) + Graphics **0.4.5**
- boot-args: `keepsyms=1 -vi2c-force-polling alcid=38 alcverbs=1 -allow3d -disablegfxfirmware -v debug=0x100 -wex-display-trace -wex-display13-trace`
  (deliberately **without** `-wex-tgl-edp-keep`, to test the native path first)

### Result

- The machine boots fully (loginwindow and apps come up), the **external DP display lights up and shows the desktop**.
- The **internal panel stays black** at every stage.
- `-wex-display-trace` / `-wex-display13-trace` produced **zero** trace lines.

### Kernel log (AppleIntelTGLGraphicsFramebuffer), 0.8.6

```
16:49:55.237  [IGFB][ERROR][PORT] Unsupported DDI        (repeated ~20x)
16:50:05.527  [IGFB][ERROR][LINK_TRAINING] Phase 2 of link training failed - notifying AGDC to take display offline
16:50:05.667  ... same message repeated 5x within ~1 s
```

Note: the usual `Unsupported CD clock decimal frequency 0x28b` / `Wrong CD clock frequency 0x0 set by EFI` / power-well / backlight-frequency errors appear in the **working** 0.8.3 boot as well, so I do not think those are the cause here.

### For comparison, the working configuration (0.8.3 + Graphics 0.4.4)

```
boot-args: keepsyms=1 -vi2c-force-polling alcid=38 alcverbs=1 -allow3d
           -disablegfxfirmware -wex-tgl-edp-keep -wex-edp-fix-training
           -wex-edp-no-extcap -wex-tgl-edp-softsleep -v debug=0x100
```

`ioreg` on the working system:

| display | port-number | connector-type | av-signal-type |
|---|---|---|---|
| internal eDP | **0** | **0x02000000** | 0x00000000 |
| external DP (USB-C) | 3 | 0x00040000 | 0x10000000 |

So the internal panel is on **DDI A / port 0 with connector type 0x02000000**, and that is the port that fails.

### What I think is happening

1. `Unsupported DDI` right before the training attempts suggests the **port/DDI mapping rejects the internal eDP configuration**.
2. The subsequent `Phase 2 of link training failed` is the same signature reported for other TGL-H35 9A49 panels (#37).
3. On this machine, the three flags that make it work in 0.8.3 (`-wex-edp-fix-training`, `-wex-edp-no-extcap`, `-wex-tgl-edp-softsleep`) come from the local qqaoshi888/WilliamAlexanda patch set. I checked the 0.8.6 source tree and **none of those three flags or their logic exists there** — only `-wex-tgl-edp-keep`, which I tested with and without.

### Questions

1. Is DDI A (port 0, `connector-type 0x02000000`) supported by the new Display13 port map on TGL-H35, or is `Unsupported DDI` expected there?
2. Is there an upstream equivalent of the old `-wex-edp-fix-training` / `-wex-edp-no-extcap` behaviour, or is a port of those patches needed for panels like this one?
3. Would a trace flag that survives this path help you debug it? I can run any build you point me at and report the register/log output.

I can attach the full `log show` window (16:48–16:54) or any specific `ioreg` dump if useful.

---

**已发布**：https://github.com/b00t0x/WhateverXe/issues/208#issuecomment-7214203092
（2026-11-27 17:0x，经用户确认后发布）
