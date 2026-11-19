# Upstream issue draft: display audio (HDMI/DP) not working

**Title:** Display audio (HDMI / DP) not functional on TGL — no display codec enumerated

---

## Summary

On my RedmiBook Pro 15 2021 (Intel i5-11300H, Iris Xe `8086:9A49`), external display audio
(HDMI and Type-C/DP) does not work. Video works fine on both. No HDMI/DP audio output ever
appears in CoreAudio, and `IOHDACodecDevice` stays at 1 (analog codec only).

## Environment

| Item | Value |
|---|---|
| Laptop | RedmiBook Pro 15 2021 (TIMI TM2017) |
| CPU / iGPU | i5-11300H / Iris Xe `8086:9A49` |
| Codec | Realtek ALC256 (`alc-layout-id = 38`) |
| WhateverXe | 0.8.3 + AppleIntelTGLCompat 0.8.1 |
| Driver kexts | `AppleIntelTGLGraphics` 16.0.0 (donor from GPUDriversIntel-16.0.32) |
| macOS | 26.7.3 (25G342) |
| boot-args | `keepsyms=1 -vi2c-force-polling alcid=38 alcverbs=1 -wex-tgl-edp-keep -wex-edp-fix-training -wex-edp-no-extcap -wex-tgl-edp-softsleep` |
| Audio kext | SimpleHDA 1.0.0 (third-party AppleHDA replacement, EFI-injected) |

## Symptoms

| Check | HDMI | Type-C/DP | Expected |
|---|---|---|---|
| Display works | ✅ 3840×2160@30 | ✅ 3840×2160@60 | — |
| `av-signal-type` | `0x08` ✅ | `0x10` ✅ | correct |
| `connector-type` | `0x00080000` ✅ | `0x00040000` ✅ | correct |
| `audio-codec-info` (on `AppleIntelFramebuffer`) | `0x00000000` | `0x00000000` | codec id |
| `IOHDACodecDevice` | 1 | 1 | 2 (analog + display) |
| `AppleHDAHDMI_DPDriver` | 0 | 0 | ≥1 |
| `AppleHDAEngineOutputDP` | 0 | 0 | ≥1 |
| CoreAudio output | 内建 only | 内建 only | HDMI/DP output |

Booting **with the display already connected** makes no difference (verified with a
boot-time logger sampling for 3 minutes: codec count never reaches 2,
`audio-codec-info` stays 0).

## Findings

1. **The GPU does contain the display audio codec ID.** A read-only probe reading GPU MMIO
   found:

   ```
   0x65000 = 0x0070FA60
   0x65010 = 0x00000044
   0x65020 = 0x80862812    ← vendor 0x8086 + device 0x2812 (Intel display audio codec)
   0x6507C = 0x00FF000F
   ```

2. **The framebuffer publishes `audio-codec-info = 0`.** Apple's Intel framebuffer
   (the 16.0.32 donor binary contains the string `audio-codec-info`) apparently computes it,
   but the value stays 0 in this configuration.

3. **Overriding the property does not help.** A test kext set
   `audio-codec-info = 0x80862812` and `av-signal-type` on the framebuffer; the property was
   accepted at boot but the driver overwrote it back to 0 on every display hotplug, and no
   codec/driver appeared.

4. **WhateverXe has no display-audio code.** Searching the 0.8.3 source for
   `audio` / `HDA` / `infoframe` / `ELD` yields only two unrelated comments.

## What seems to be missing (for the driver to implement)

Based on Linux `i915`/`intel_audio.c` and the AMD analogue, enabling display audio needs:

1. Enable the audio path for the active transcoder/DDI (`AUDIO_ENABLE`-style bits)
2. Write Audio InfoFrames for the active mode (channels / sample rate)
3. Read ELD from the sink (DPCD `0x00060+` / CEA-861 for HDMI)
4. Publish `audio-codec-info` (and keep it correct across hotplug), so the HDA stack can
   enumerate the display codec

Without step 1-4, the HDA stack never sees a display codec — hence `IOHDACodecDevice` = 1.

## Question

Is display audio on the roadmap for WhateverXe? If not, would a PR implementing the above
be accepted? I can help test on this hardware (HDMI + Type-C/DP, 4K@30 / 4K@60).

I can also provide:
- Full `ioreg` dump with display connected
- The register dump above (with/without display)
- A minimal read-only probe kext used to obtain it
