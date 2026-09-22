EasySD 1.1 SD1/SD2 - release build set

Files:
  easyhdd_1_1_release_SD12.a80
  compile_1_1_SD12.bat
  make_taps_1_1_SD12.ps1

Required existing files in the same directory:
  sjasmplus.exe (or sjasmplus in PATH)
  GUI.a80 and all normal EasySD include/source files
  BSROM140_EL.rom
  BSDOS.rom

Run:
  compile_1_1_SD12.bat

Main outputs:
  EasySD_1_1_INSTALL.bin   MB03+ 1.1, SD1+SD2
  EasySD_1_1_EL.tap        eLeMeNt ZX 1.1, SD1+SD2, shared driver page 98
  EasySD_1_1_SLIM.tap      MB03+ Slim 1.1, SD1+SD2, shared driver page 98

Also generated:
  EasySD_1_1_INSTALL.tap
  EasySD_1_1_EL.bin / .lst
  EasySD_1_1_SLIM.bin / .lst

Paging model:
  MB03+:        BSDOS 97, CF 98, SD1+SD2 shared SD driver page from PAGE_SD (default 105)
  eLeMeNt ZX:   BSDOS 97, SD1+SD2 shared driver page 98
  MB03+ Slim:   BSDOS 97, SD1+SD2 shared driver page 98

The PowerShell generator uses the proven eLeMeNt/Slim bootstrap and inserts the actual BIN length automatically.
