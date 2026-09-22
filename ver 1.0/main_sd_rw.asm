;;;    device zxspectrum48
;;;    org 32768
DMA_SD  equ 1
start_sd
    call SD_INIT
    ld ix,buff
    ld de,0
    ld hl,0
    call SD_READ
    ; call nz,SD_IDLE
    jr start_sd

card_select
     db SD_0
;    db SD_1
    include "sd_rw.asm"
    align 256
buff
    ds 512
end_sd
;    savetap "sddebug.tap",start, end-start
;    save3dos "sddebug.bin",start,end-start
;;;	savebin "SDreadwrite", start, end-start