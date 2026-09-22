EasySD 1.1 SD1+SD2 - MB03+ bridge fix

MB03+:
- restored the previously working resident banking bridge:
  #0010 JP #036E
  #001B LD A,97 / OUT(23),A / JR #0090
  #0021 JP #0367
  #002B JP #0374
- restored driver-page stubs at #0367, #036E, #0374 and RET points #0372/#0378/#037E
- BSDOS page 97 installer again patches only #001B and #036B..#037D for this bridge;
  it does not overwrite #0014/#0023/#002B.

eLeMeNt / Slim:
- unchanged SD-only page-98 bridge (97 <-> 98), already tested on eLeMeNt.

Before testing MB03+ after a previous broken install, cold boot/reset so BSDOS page 97 starts clean,
then install the newly built EasySD 1.1.
