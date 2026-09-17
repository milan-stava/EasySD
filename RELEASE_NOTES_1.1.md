# EasySD 1.1 release notes

EasySD 1.1 is an MB03+ extension providing runtime switching between EasyCF, SD1 and SD2 without a BSDOS reset. There is no separate EasyCF 1.1 release.

## Highlights

- CF, SD1 and SD2 runtime switching
- independent handling of both MB03+ SD slots
- automatic and manual SD partition selection
- support for one-card and two-card configurations
- safe device detection before every switch
- BASIC menu with current-system and availability reporting
- BSDOS cache invalidation through `KILLX`
- active device/partition labels in catalogue corners
- catalogue write-protection indicator
- early compatible-EasyCF validation
- configurable EasySD SRAM page 6-32

## Files

- `EasySD_1_1_INSTALL.tap` - MB03+ installer
- `SWITCH_MENU.tap` - BASIC CF/SD1/SD2 switcher with machine-code backend
- `EasySD_EasyCF_v1.1.zip` - complete release package

## Installation order

1. Install compatible EasyCF; the current distribution is EasyCF 1.0.1.
2. Run `EasySD_1_1_INSTALL.tap`.
3. Select or confirm the SD partitions.
4. Load `SWITCH_MENU.tap` to switch devices while BSDOS is running.

## Compatibility

This release targets MB03+ and BSDOS 3.08. Standalone eLeMeNt ZX and MB03+ Slim users should continue using EasySD 1.0.1.

EasyCF 1.0 and EasyCF 1.0.1 have the same driver and the same CF functionality. The EasyCF 1.0.1 distribution differs only by adding two launcher TAP files for MB03+ Slim and standalone eLeMeNt ZX. EasySD 1.1 checks the existing internal `EasyCF10` identifier and the required bank-switching entry before enabling SD access; this compatibility check does not define a new EasyCF release.

## Verification

The final installer and switcher were verified on real MB03+ hardware. Tests covered CF/SD1/SD2 switching, configurations with a missing SD card, repeated catalogues, LOAD/SAVE, non-empty `.SEARCH`, write-protection display and rejection of unavailable targets.

## MB03+ BOOT support

The updated MB03+ BOOT initializes both SD1 and SD2 and fixes return through BOOT function `E` when SD2 was the last active device. EasySD 1.1 users should use the current dual-SD BOOT from the separate [MB03+ BOOT project](https://github.com/milan-stava/mb03plusboot).
