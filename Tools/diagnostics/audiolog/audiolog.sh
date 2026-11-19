#!/bin/bash
OUT=/var/log/audiolog.txt
: > "$OUT"
for i in $(seq 1 90); do
  TS=$(date '+%H:%M:%S')
  CODEC=$(ioreg -l -w0 2>/dev/null | grep -c 'class IOHDACodecDevice')
  HDMI=$(ioreg -l -w0 2>/dev/null | grep -c 'class AppleHDAHDMI_DPDriver')
  ENG=$(ioreg -l -w0 2>/dev/null | grep -c 'class AppleHDAEngineOutputDP')
  ACI=$(ioreg -l -w0 2>/dev/null | grep -oE '"audio-codec-info" = <[0-9a-f]+>' | grep -v IOKitDiagnostics | tr '\n' ' ')
  DEV=$(system_profiler SPAudioDataType 2>/dev/null | grep -E '^\s{10}\S.*:$' | sed 's/[: ]//g' | tr '\n' ',')
  echo "$TS codec=$CODEC hdmi=$HDMI engDP=$ENG devs=$DEV aci=$ACI" >> "$OUT"
  sleep 2
done
