# [TGL-H35 9A49] 0.8.6 + `-wex-edp-fix-training`: cold boot is fine, but **display-sleep wake fails Phase 2 again** and WindowServer later panics

**Disclosure:** single machine, isolated test, **AI-assisted**, text AI-generated from Chinese notes; I am not a computer professional. Thanks to @b00t0x and @qqaoshi888 — `-wex-edp-fix-training` fixed my cold-boot black panel (see #208), and this report is only about the remaining display-sleep path.

## Summary

With WEX 0.8.6 + `qqaoshi888/WhateverXe` branch `lyndon-0.8.6` commit `ec5cd885` (`-wex-edp-fix-training`):

- **Cold boot:** internal eDP + external DP both work (verified, see #208).
- **Display sleep → wake:** the internal panel **fails link training Phase 2 again**, gets taken offline, and WindowServer hangs; a userspace watchdog panic follows ~11 minutes later.

No system sleep is involved: `pmset disablesleep 1` is set, and the log contains no `Entering Sleep` entry.

## Machine / config

| | |
|---|---|
| Laptop | Xiaomi RedmiBook Pro 15 2021, i5-11300H, Iris Xe `8086:9A49` |
| Panel | internal 3200x2000 30-bit eDP (DDI A, port 0, connector-type 0x02000000) |
| OS | macOS 26.7.3 (25G342), OpenCore |
| WEX | 0.8.6 + `ec5cd885` (`-wex-edp-fix-training`), self-built |
| Graphics | 0.4.5 |
| boot-args | `keepsyms=1 -vi2c-force-polling alcid=38 alcverbs=1 -allow3d -disablegfxframebuffer -v debug=0x100 -wex-edp-fix-training -wex-display-trace -wex-display13-trace` |
| pmset during test | `SleepDisabled=1`, `displaysleep=10`, `hibernatemode=0`, `standby=0` |

(Only the internal panel was connected during this test.)

## Timeline (pmset + kernel log)

```
17:34:04  Display is turned off                     (idle display sleep)
17:39:04  Display is turned on                      (wake by user)
17:39:04  [IGFB][INFO ][POWER] FB0: power state transition Doze --> Wake
17:39:05  [IGFB][INFO ][DISPLAY] FB0: Complete modeset
17:39:06  [IGFB][ERROR][LINK_TRAINING] Phase 2 of link training failed
              - notifying AGDC to take display offline
17:39:06  [IGFB][ERROR][DISPLAY] FB0: Hardware mode set failed, err = 0xe00002bc
17:39:06  [IGFB][ERROR][DISPLAY] FB0 is not enabled        (repeated many times)
17:50:37  panic: userspace watchdog timeout, no WindowServer checkins for 120 s
```

`Phase 2 of link training failed` appears **6 times** in that window; on a working cold boot it is **0** (see #208).

## What I think is happening

`-wex-edp-fix-training` hooks the **light-up** path and repairs the DDI/PG power domain there. The Doze→Wake path performs a full modeset (`FB0: Complete modeset`) and then retrains the link, but the repair apparently does not apply on that path, so Phase 2 fails exactly as it did without the fix on cold boot.

This matches the direction of the 0.8.6 note "Fix a timeout when re-establishing the internal eDP link after display sleep" — on this machine that timeout is not the failure mode; the failure is the training phase itself.

## Questions

1. Would it be correct to run the same `powerDomainRepair()` (and the light-up wrapper's pre-checks) on the **resume modeset** path, or is there a different function that should be hooked for display-sleep wake?
2. Is there a register/state readout I can capture at the moment of the wake retrain that would tell you which precondition is missing? I can add a read-only probe and report values (the machine is otherwise stable on 0.8.3).
3. Is `-wex-tgl-edp-keep` intended to help this path? I tested it during cold-boot experiments and it did not change the black panel there; I have not combined it with display-sleep testing.

## Current state

I have rolled the machine back to 0.8.3 + the previous local eDP patches (display-sleep wake works there), keeping the 0.8.6 build archived, so I can re-test any build you point me at without risking daily use. Full `log show` window (17:33–17:52) and `ioreg` dumps are available on request.

Related: #208 (cold-boot black panel, fixed by `ec5cd885`), #201.

---

**已发布**：https://github.com/b00t0x/WhateverXe/issues/240
（2026-11-27 18:0x，用户确认后发布）
