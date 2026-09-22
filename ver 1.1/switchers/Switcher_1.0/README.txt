Switcher 1.0 - simple CF / SD1 / SD2 switcher for EasySD/EasyCF 1.1

This is the original simple switcher kept separately from FULL_SWITCHER_1_1.
It changes only the active device (CF, SD1, SD2). It does not edit VDT names.

Build on Windows:
  compile.bat

Requirements:
  - sjasmplus.exe in the parent EasySD 1.1 directory (preferred), or in this directory, or in PATH
  - Windows PowerShell
  - no Python required

Sources:
  switch_device_unified.a80  machine-code backend
  SWITCH_MENU.bas            readable ZX BASIC source
  make_switch_menu.ps1       creates tokenized TAP, equivalent to the original Python generator

Expected outputs:
  SWITCH_ALL.bin   557 bytes
  SWITCH_ALL.lst
  SWITCH_MENU.tap  1797 bytes

Reference known-good SHA-256 from the original Python build:
  SWITCH_ALL.bin  d428317783e8f4e6544f9eb2b4fd1639fa8e9a6efe42788fca7782236d158b57
  SWITCH_MENU.tap e890fa5bd69fd4f733909d3ae3632c0d7d832ade6080bfde1a8aa80982012a4b
