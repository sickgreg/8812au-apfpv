# Agent Notes

## Streaming stability investigation
- Default Realtek settings allowed AMPDU bursts up to 1 MB, producing bursty UDP delivery during AP video streaming. The driver now defaults the advertised AMPDU factor to 64 KB to keep aggregates smaller.
- A new `rtw_tx_max_agg_num` module parameter enforces a maximum TX descriptor aggregate length. The build defaults it to `12` (24 MPDUs) but accepts values `1-31`; `0` or negatives hand control back to firmware.
- `scripts/build-ssc338q.sh` runs an AP-mode focused cross build for the SSC338Q OpenIPC toolchain and validates that the expected kernel tree and toolchain are present before compiling.
- When `CONFIG_AP_MODE=y`, the Makefile now disables STA-centric features (P2P, TDLS, roaming, and driver-level power saving) and enables the IP camera EDCA presets so AP builds bias toward steady throughput.

## Future changes touching this repository
- Follow the existing indentation (tabs for structure members, spaces for comments) when editing C headers and sources.
- Keep build scripts POSIX sh compatible and guard against missing toolchains or kernel trees.
