# EasySD / EasyCF 1.1 release notes

EasySD / EasyCF 1.1 is an MB03+ extension providing runtime switching between CF, SD1 and SD2 without a BSDOS reset.

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

1. Install compatible EasyCF 1.0.
2. Run `EasySD_1_1_INSTALL.tap`.
3. Select or confirm the SD partitions.
4. Load `SWITCH_MENU.tap` to switch devices while BSDOS is running.

## Compatibility

This release targets MB03+ and BSDOS 3.08. Standalone eLeMeNt ZX and MB03+ Slim users should continue using EasySD 1.0.1.

EasyCF 1.1 provides the same standalone CF functionality as EasyCF 1.0. Its only functional difference is the internal preparation for CF/SD1/SD2 runtime switching: a compatible bank-switching bridge and fixed interface. The internal identifier remains `EasyCF10`, so the installer checks both the identifier and the bridge before enabling EasySD 1.1.

## Verification

The final installer and switcher were verified on real MB03+ hardware. Tests covered CF/SD1/SD2 switching, configurations with a missing SD card, repeated catalogues, LOAD/SAVE, non-empty `.SEARCH`, write-protection display and rejection of unavailable targets.

## Known external limitation

The MB03+ BOOT `E` path does not yet initialize SD2 when SD2 was the last active device. This belongs to the separate MB03+ BOOT project and does not affect switching from `SWITCH_MENU.tap`.
