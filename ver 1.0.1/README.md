# EasySD 1.0.1

EasySD 1.0.1 is the current release of EasySD for BSDOS.

EasySD automatically detects supported FAT16/FAT32 partitions, locates MBD/MBH disk images and configures BSDOS without requiring the user to know their physical sector location.

![EasySD 1.0](images/01-easysd-overview.png)

## Supported hardware

- MB03+
- MB03+ Slim
- eLeMeNt ZX

EasySD 1.0.1 therefore supports three hardware platforms. On MB03+ version 1.0.1 uses SD slot `SD1` only; from the user's point of view this is the left SD slot.

## What's new in 1.0.1

- added MB03+ Slim support
- added `EasySD_SLIM.tap` bootstrap
- EasySD now supports MB03+, MB03+ Slim and standalone eLeMeNt ZX
- updated build system and documentation

## Main features

- FAT16 and FAT32 support
- up to four primary partitions
- superfloppy FAT16/FAT32 media support
- automatic and manual partition selection
- SPACE override for temporary MANUAL mode
- BSDOS disks 1–255
- MBD and MBH image support
- automatic calculation of the physical LBA of the first BSDOS disk
- per-disk write protection
- SDHC and SDXC support
- SD initialization with timeout and retry handling
- FAT32 root-directory preparation tools for Windows and Linux

## Downloads

The current release is available in the GitHub Releases section.

### Complete package

[**Download EasySD v1.0.1 ZIP**](https://github.com/milan-stava/EasySD/releases/download/v1.0.1/EasySD_v1.0.1.zip)

### Individual files

- [EasySD_MB_BIN.tap](https://github.com/milan-stava/EasySD/releases/download/v1.0.1/EasySD_MB_BIN.tap) – EasySD for MB03+
- [EasySD_SLIM.tap](https://github.com/milan-stava/EasySD/releases/download/v1.0.1/EasySD_SLIM.tap) – EasySD for MB03+ Slim
- [EasySD_EL.tap](https://github.com/milan-stava/EasySD/releases/download/v1.0.1/EasySD_EL.tap) – EasySD for standalone eLeMeNt ZX
- [EasySD_documentation.txt](https://github.com/milan-stava/EasySD/releases/download/v1.0.1/EasySD_documentation.txt) – complete manual
- [PREPARE_EASY_FAT32.bat](https://github.com/milan-stava/EasySD/releases/download/v1.0.1/PREPARE_EASY_FAT32.bat) – Windows FAT32 preparation tool
- [PREPARE_EASY_FAT32.sh](https://github.com/milan-stava/EasySD/releases/download/v1.0.1/PREPARE_EASY_FAT32.sh) – Linux FAT32 preparation tool

See the [EasySD 1.0.1 release](https://github.com/milan-stava/EasySD/releases/tag/v1.0.1) for release notes.

## Important

MBD/MBH disk images must form one physically contiguous area on the media.

Version 1.0.1 has been tested on real MB03+, MB03+ Slim and eLeMeNt ZX hardware. BSDOS read and write operations were verified on the applicable hardware, and the MB03+ Slim bootstrap was verified on real hardware.

## Documentation

See `EasySD_documentation.txt` for the complete user and technical manual.

## Related project

EasyCF is the CompactFlash counterpart of EasySD. CompactFlash access is provided by MB03+; EasyCF can also be launched from eLeMeNt ZX when an external MB03+ with a CF card is connected.

## Official website

Full HTML documentation, screenshots and project information:

- [English documentation](https://hood.speccy.cz/dwnld/EasySD_CF_infoEN.html)
- [Czech documentation](https://hood.speccy.cz/dwnld/EasySD_CF_infoCZ.html)
- [German documentation](https://hood.speccy.cz/dwnld/EasySD_CF_infoDE.html)
