Switcher 1.1 Full
=================

Release candidate for the EasySD 1.1 distribution.

Purpose
-------
Runtime selection of CF / SD1 / SD2 partitions without reset, with support
for the 26-character VDT partition description.

Controls
--------
UP / 7      previous item
DOWN / 6    next item
ENTER       activate selected partition
E           edit 26-character description
X           exit

Colours
-------
CYAN        usable partition
RED         unusable partition
*           active partition

Notes
-----
- The description is limited to 26 characters.
- Empty line + ENTER stores an empty VDT description; the UI/catalogue shows
  EMPTY ENTRY.
- Final public release is pending hardware verification together with EasySD 1.1.

Files
-----
Switcher_1_1_Full.tap       runnable TAP
src\switcher_1_1_full.a80   main ASM backend
src\switcher_ui.a80         fast ASM UI renderer
src\switcher_1_1_full_gui.bas BASIC frontend
src\switcher_1_1_full.bin   combined machine-code binary
