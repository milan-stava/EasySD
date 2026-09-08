\# EasySD 1.0



EasySD 1.0 is the first public release of EasySD for BSDOS.



EasySD automatically detects supported FAT16/FAT32 partitions, locates MBD/MBH disk images and configures BSDOS without requiring the user to know their physical sector location.



!\[EasySD 1.0](images/01-easysd-overview.png)



\## Supported hardware



\- MB03+

\- eLeMeNt ZX



\## Main features



\- FAT16 and FAT32 support

\- up to four primary partitions

\- superfloppy FAT16/FAT32 media support

\- automatic and manual partition selection

\- SPACE override for temporary MANUAL mode

\- BSDOS disks 1–255

\- MBD and MBH image support

\- automatic calculation of the physical LBA of the first BSDOS disk

\- per-disk write protection

\- SDHC and SDXC support

\- SD initialization with timeout and retry handling

\- FAT32 root-directory preparation tools for Windows and Linux



\## Downloads



The current release is available in the GitHub Releases section.



Release package contents:



\- `EasySD\_MB\_BIN.tap` – EasySD for MB03+

\- `EasySD\_EL.tap` – EasySD for standalone eLeMeNt ZX

\- `EasySD\_documentation.txt` – complete user and technical manual

\- `PREPARE\_EASY\_FAT32.bat` – FAT32 preparation tool for Windows

\- `PREPARE\_EASY\_FAT32.sh` – FAT32 preparation tool for Linux

\- `EasySD\_v1.0.zip` – complete release package



\## Important



MBD/MBH disk images must form one physically contiguous area on the media.



Version 1.0 has been tested on real MB03+ and eLeMeNt ZX hardware, including BSDOS read and write operations.



\## Documentation



See `EasySD\_documentation.txt` for the complete user and technical manual.



\## Related project



EasyCF is the CompactFlash counterpart of EasySD for MB03+.

