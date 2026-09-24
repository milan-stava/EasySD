# EasySD 1.1

EasySD 1.1 adds the SD part of the shared EasySD / EasyCF 1.1 system on a full MB03+.

## Main changes

- runtime switching between CF, SD1 and SD2 without restarting BSDOS
- independent detection and partition selection for SD1 and SD2
- support for configurations with one or two inserted SD cards
- Basic Switcher 1.0 for complete CF / SD1 / SD2 devices
- FULL Switcher 1.1 with additional P1-P4 selection
- 26-character user-defined VDT partition names
- active device and partition displayed in the BSDOS catalogue
- write-protection symbol displayed next to the disk number
- unavailable devices and invalid partitions cannot be activated

## Installation

1. Install EasyCF 1.1.
2. Run `EasySD_1_1_INSTALL.tap`.
3. Confirm the automatically selected SD partitions or hold SPACE for manual selection.
4. Use `SWITCH_MENU.tap` to switch complete devices, or FULL Switcher 1.1 for device and partition selection.

EasyCF must be installed first because it creates the shared switching interface used by EasySD 1.1.

## Downloads

- `EasySD_EasyCF_v1.1.zip` - complete package with the installer, both switchers and CZ/EN/DE documentation
- `EasySD_1_1_INSTALL.tap` - EasySD 1.1 installer for a full MB03+
- `SWITCH_MENU.tap` - Basic Switcher 1.0

The source code and build scripts are stored under `ver 1.1` in the repository.

## Compatibility

The shared CF / SD1 / SD2 system is intended for a full MB03+. Standalone eLeMeNt ZX and MB03+ Slim users should continue using EasySD 1.0.1.

EasySD 1.1 and both switchers accept compatible EasyCF 1.0.1 and EasyCF 1.1 drivers, but EasyCF 1.1 is the recommended release for a new installation.
