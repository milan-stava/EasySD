# EasySD / EasyCF 1.1

EasySD / EasyCF 1.1 adds runtime switching between CompactFlash, SD1 and SD2 on MB03+ without resetting BSDOS or losing normal RAM contents.

The original EasySD 1.0.1 remains the current standalone release for MB03+ Slim and eLeMeNt ZX. Version 1.1 is an MB03+-only extension and requires a compatible EasyCF 1.0 installation.

![EasySD](images/01-easysd-overview.png)

## What's new in 1.1

- runtime switching between CF, SD1 and SD2
- independent SD1 and SD2 detection and partition selection
- support for systems containing only one SD card
- automatic selection of usable SD partitions
- manual eight-row partition selector with a full-width cursor
- safe rejection of missing devices and unusable partitions
- BASIC switcher with detection of EasyHDD, EasyCF and EasySD 1.0
- `KILLX` after switching to invalidate cached disk information
- active device and partition displayed in the BSDOS catalogue corners
- write-protection symbol displayed only next to the disk number
- compatible EasyCF check before the installer touches SD hardware
- configurable EasySD SRAM page in the physical range 6-32

## Requirements and compatibility

EasySD / EasyCF 1.1 requires:

- MB03+
- BSDOS 3.08
- compatible EasyCF 1.0 in SRAM page 2 (write mapping value 98)

The installer verifies the `EasyCF10` identifier and the required bank-switching bridge before installation. If the check fails, it displays `EasyCF required` and exits without modifying BSDOS.

Version 1.1 is not intended for a standalone eLeMeNt ZX or MB03+ Slim. Continue using EasySD 1.0.1 on those platforms.

## Installation

1. Install and verify EasyCF 1.0.
2. Run `EasySD_1_1_INSTALL.tap`.
3. Check the detected SD1 and SD2 cards and their partitions.
4. Confirm the automatically selected partitions or hold SPACE for manual selection.
5. Run `SWITCH_MENU.tap` whenever CF/SD1/SD2 switching is required.

The menu marks an unavailable target as `NOT DETECTED` and refuses to switch to it. Before a complete 1.1 installation it only reports the detected legacy system and displays `EasySD/EasyCF 1.1 not installed`.

## Switcher entry points

The shared machine-code switcher is loaded at `#8000`:

| Address | Decimal | Function |
| --- | ---: | --- |
| `#8000` | 32768 | switch to CF |
| `#8003` | 32771 | switch to SD1 |
| `#8007` | 32775 | switch to SD2 |
| `#800B` | 32779 | return current system in BC |
| `#800E` | 32782 | return availability mask in BC |

The availability mask uses bit 0 for CF, bit 1 for SD1 and bit 2 for SD2. Switching returns `BC=0` on success and `BC=1` when the target is unavailable.

## Building

The original `compile.bat` and `compile.sh` still build the EasySD 1.0.1 targets.

Version 1.1 is built separately:

```text
compile_1_1.bat
```

or on Linux:

```text
./compile_1_1.sh
```

Required tools:

- SjASMPlus 1.20.3 or compatible
- Python 3 for TAP generation

The 1.1 build produces:

- `EasySD_1_1_INSTALL.tap`
- `SWITCH_MENU.tap`
- `FULL_SWITCHER_1_1.bin`

The FULL Switcher sources are stored as `FULL_SWITCHER_1_1.bas` and
`FULL_SWITCHER_1_1.a80`. The release package combines the tokenized BASIC
frontend and the 2924-byte machine-code backend into `FULL_SWITCHER_1_1.tap`.

Assembler listings, raw binaries and TAP files are build artifacts and are excluded from Git.

## Testing

Version 1.1 was tested on real MB03+ hardware with CF, SD1 and SD2. Runtime switching, repeated catalogues, LOAD/SAVE, non-empty `.SEARCH`, write-protection display, single-card configurations and unavailable-target rejection were verified.

## Known external limitation

Returning through the MB03+ BOOT `E` function when SD2 was the last active device requires a separate future MB03+ BOOT update. This does not affect normal CF/SD1/SD2 switching performed by `SWITCH_MENU.tap`.

## EasySD 1.0.1

EasySD 1.0.1 remains available for MB03+, MB03+ Slim and standalone eLeMeNt ZX:

- [EasySD v1.0.1 release](https://github.com/milan-stava/EasySD/releases/tag/v1.0.1)
- [EasySD v1.0.1 complete ZIP](https://github.com/milan-stava/EasySD/releases/download/v1.0.1/EasySD_v1.0.1.zip)

Its main features include FAT16/FAT32, four primary partitions, superfloppy media, automatic/manual partition selection, MBD/MBH images, per-disk write protection and SDHC/SDXC support.

## Documentation

See `EasySD_documentation.txt` for the existing EasySD manual. Version 1.1 release notes are stored in `RELEASE_NOTES_1.1.md`.

Official documentation:

- [English](https://hood.speccy.cz/dwnld/EasySD_CF_infoEN.html)
- [Czech](https://hood.speccy.cz/dwnld/EasySD_CF_infoCZ.html)
- [German](https://hood.speccy.cz/dwnld/EasySD_CF_infoDE.html)
