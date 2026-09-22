; based on doc http://elm-chan.org/docs/mmc/mmc_e.html

SPI_PORT	equ 0xeb
OUT_PORT	equ 0xe7	; port for CS control (D1:D0)
DMA_PORT    equ 11

SD_0		equ 0xFE    ;0xFE,esxdos 0xF6	; D0 LOW = SLOT0 active; D3 low = NMI disabled
SD_1		equ 0xFD    ;0xFD,esxdos 0xF5	; D1 LOW = SLOT1 active; D3 low = NMI disabled

CMD_0		equ	0x40	; Go idle state
CMD_1		equ	0x40+1	; SEND_OP_COND
CMD_8		equ 0x40+8	; SEND_IF_COND
CMD_9		equ 0x40+9	; SEND_CSD
CMD_10		equ	0x40+10	; SEND_CID
CMD_12		equ 0x40+12	; STOP_TRANSMISSION
CMD_16		equ	0x40+16	; SET_BLOCKLEN
CMD_17		equ	0x40+17	; READ_SINGLE_BLOCK
CMD_18		equ	0x40+18	; READ_MULTIPLE_BLOCK
;CMD_23		equ 0x40+23	; SET_BLOCK_COUNT (MMC ONLY)
ACMD23		equ 0x40+23	; SET_WR_BLOCK_ERASE_COUNT
CMD_24		equ 0x40+24	; WRITE_BLOCK
CMD_25		equ 0x40+25	; WRITE_MULTIPLE_BLOCK
ACMD41		equ 0x40+41	; APP_SEND_OP_COND
CMD_55		equ 0x40+55	; APP_CMD
CMD_58		equ 0x40+58	; READ_OCR

BLOCKSIZE	equ	512		; SD/MMC block size (bytes)
; R1 response
; D0 = Idle state / init not completed yet
; D1 = Erase Reset
; D2 = Illegal Command
; D3 = Com CRC Error
; D4 = Erase Sequence Error
; D5 = Address Error
; D6 = Parameter Error
; D7 = ALWAYS LOW

SD_ON	ld a,(card_select)
	out (OUT_PORT),a
	ld a,0xff
	out (SPI_PORT),a
	ret 
SD_OFF
    ld a,0xFF
	out (OUT_PORT),a
;	out	(SPI_PORT),a
    ret

/*
SD_ON   ; a = 0,1 sd card
    and 1
    ld hl,sd_cs
    ld e,a
    ld d,0
    add hl,de
    ld a,(hl)
    out (OUT_PORT),a
    ret

sd_cs
    db SD_0,SD_1
*/
SD_INIT
	; call SD_OFF
	ld a,0xff
	out (OUT_PORT),a
	call SD_POWER_ON
	ld a,(card_select)
	out (OUT_PORT),a

	call SD_RESET
	; resp = 1
	call SD_SEND_IF_COND
	; 0 = OK
	; cp 0
	; ret nz
	cp 1
	jr z,SD_INIT
	; resp = 0x1AA
	call SD_OCR
	ld a,0xff
	out (OUT_PORT),a
	ret

SD_POWER_ON
; Set DI and CS high and apply 74 or more clock pulses to SCLK.
; The card will enter its native operating mode and go ready to accept native command.
    ; call SD_OFF
	; send 80clocks
	; 10x8bits
	ld b,10
	; ld bc,0
	ld a,255
1
	; ld a,0xff
	out (SPI_PORT),a
	djnz 1B
	; dec bc
	; ld a,b
	; or c
	; jr nz,1B
	
	; ld a,SD_1
	; out (OUT_PORT),a
	ret

SD_RESET
	ld a,0xff
	out (SPI_PORT),a
	; send CMD_0
	; param =0,0,0,0
	; crc = 0x95
	ld a,CMD_0
	out (SPI_PORT),a
	xor a
	out (SPI_PORT),a
	out (SPI_PORT),a
	out (SPI_PORT),a
	out (SPI_PORT),a
	ld a,0x95
	out (SPI_PORT),a

	call WAIT

	cp 1
    jr nz,SD_RESET

	; 1 = in idle state, ok
    ret

SD_SEND_IF_COND
	ld a,0xff
	out (SPI_PORT),a
	ld a,CMD_8
	out (SPI_PORT),a
	xor a
	out (SPI_PORT),a
	out (SPI_PORT),a
	ld a,1
	out (SPI_PORT),a
	ld a,0xaa
	out (SPI_PORT),a
	; CRC for CMD_8
	ld a,0x87
	out (SPI_PORT),a

	call WAIT

	; in a,(SPI_PORT) - from WAIT	; R7 (R1+32bit response)
	in a,(SPI_PORT)
	in a,(SPI_PORT)
	in a,(SPI_PORT)
	in a,(SPI_PORT)
	; pokud 0x1AA, V2
	; posli acmd41



    ld b,10
retry_41
    push bc
	ld a,0xff
	out (SPI_PORT),a
	ld a,CMD_55
	out (SPI_PORT),a
	xor a
	out (SPI_PORT),a
	out (SPI_PORT),a
	out (SPI_PORT),a
	out (SPI_PORT),a
	; "crc" not needed
	out (SPI_PORT),a

	call WAIT

	ld a,0xff
	out (SPI_PORT),a

	; in a,(SPI_PORT)	from wait

	ld a,ACMD41
	out (SPI_PORT),a
	ld a,%01000000	; HCS / bit 30
	out (SPI_PORT),a
	xor a
	out (SPI_PORT),a
	out (SPI_PORT),a
	out (SPI_PORT),a
	; "crc" not needed
	ld a,1
	out (SPI_PORT),a

	call WAIT

	; in a,(SPI_PORT)	; from wait
	; 0 = ok
	; 1 = still in idle
    pop bc
	; cp 1
    cp 0
    ret z
    djnz retry_41
	; jr z,retry_41

	ret

SD_OCR
	ld a,CMD_58
	ld hl,0
	ld de,0
	call SD_SENDCMD
	; a = R1
	ld e,a
    in a,(SPI_PORT)
	in a,(SPI_PORT)
	in a,(SPI_PORT)
	in a,(SPI_PORT)
	; 128 = ready
        ; test SDXC
	ld a,e	; a = R1
	ret
SD_CSD	; get CSD register
	ld a,CMD_9
	jr csd_cid_comm
SD_CID	; get CID register
	; ix = read to address
	ld a,CMD_10
csd_cid_comm	; common for CSD/CID read
	ld hl,0
	ld de,0
	call SD_SENDCMD
	cp 0
	ret nz
    ld e,a  ; store R1
	call WAIT_DATA

	push ix
	pop hl
	ld bc,(256*16)+SPI_PORT ; 16 bytes
	inir
    in a,(SPI_PORT)
	in a,(SPI_PORT)
    ld a,e  ; restore R1
	ret
/*
SD_BL_LEN
    ld a,CMD_16
    ld hl,0
    ld de,512
    call SD_SENDCMD
    ret
*/
SD_READ
	; call SD_IDLE
;----
    ld a,(card_select)
	out (OUT_PORT),a
;----
	ld a,0xff
	out (SPI_PORT),a
	; hlde = sector
	ld a,CMD_17
	call SD_SENDCMD
	; 0 = ok
	cp 0
    ret nz
    ld e,a  ; store R1
    ; call pause
	call WAIT_DATA
		; cp 0xFE
		; jr nz,wderr
	; 0xFE = data start
	push ix
	pop hl

	IF DMA_SD
	call dma_read
	ELSE
	ld bc,SPI_PORT
	inir
	inir
	ENDIF

	; 2b crc
	in a,(SPI_PORT)
	in a,(SPI_PORT)
;----
	ld a,255
	out (OUT_PORT),a
	out (SPI_PORT),a
;----

	; call SD_IDLE

    ld a,e  ; restore R1
	ret
; wderr
; 	ld e,a
; 	ld a,2
; 	out (254),a
; 	ld a,e
; 	ret
; pause
;     ld bc,512
; 1
;     dec bc
;     ld a,b
;     or c
;     jr nz,1B
;     ; djnz 1B
;     ret



; SD_TEST
; 	ld de,0
; 	ld hl,0x44
; 	ld ix,0x100
; 	call SD_READ
; 	ld de,0
; 	ld hl,0x44
; 	ld ix,0x100
; 	call SD_WRITE
; 	jr SD_TEST

	
SD_WRITE
	; hlde = sector
	; ix = from address

	; call SD_IDLE
;----
	ld a,(card_select)
	out (OUT_PORT),a
	ld a,0xff
	out (SPI_PORT),a
;----	
	ld a,CMD_24
	call SD_SENDCMD
	cp 0    ; 0 = ok

	ld a,0xFE	; data start
	; out (c),a
	out (SPI_PORT),a

	push ix
	pop hl
	IF DMA_SD
	call dma_write
	ld c,SPI_PORT
	ELSE
	ld bc,SPI_PORT
	otir
	otir
	ENDIF

	xor a
	; 2b crc
	; out (c),a
	; out (c),a
	out (SPI_PORT),a
	out (SPI_PORT),a

	call WAIT
	; a = Data response
	ld e,a
	
wbsy
	call WAIT
	cp 0
	jr z,wbsy

;----
	ld a,255
	out (OUT_PORT),a
	out (SPI_PORT),a
;----

	; call SD_IDLE

	ld a,e
	and 0x1f
	; a = Data response
	ret
/*
SD_READ_MULTI
	ei
	ld a,CMD_18
	call SD_SENDCMD
	call WAIT_DATA
	; 0xFE = data start
    ret ; now read blocks until sd_stoptrans sent
; test_loop
; 	push ix
; 	pop hl
; 	ld bc,SPI_PORT
; 	inir
; 	inir
; 	inir
; 	inir

; 	call SD_STOPTRANS

; 	ret

SD_STOPTRANS
	ld a,CMD_12
	ld hl,0
	ld de,0
	call SD_SENDCMD

1
	in a,(SPI_PORT)
	cp 0xff	; ceka se na not idle
	jr nz,1B
	ret
*/

; SD_IDLE
; 	ld b,16
; 	ld a,0xff
; 1
; 	; in a,(SPI_PORT)
; 	out (SPI_PORT),a
; 	djnz 1B
; 	ret

SD_SENDCMD
	ld c,SPI_PORT
	out (c),a
	out (c),h
	out (c),l
	out (c),d
	out (c),e

	; xor a
	ld a,0xff
	out	(c),a 

WAIT
    ; ld b,0
	ld bc,0
wloop
	in a,(SPI_PORT)
	cp 0xFF
	ret nz
	dec bc
	ld a,b
	or c
	jr nz,wloop
    ; djnz wloop
	ld a,0xff	; timeout
	ret

WAIT_DATA
    ; ld b,0
	ld bc,0
wdata_loop
	in a,(SPI_PORT)
	cp 0xFE
    ret z
	dec bc
	ld a,b
	or c
	jr nz,wdata_loop
    ; djnz wdata_loop
	; jr WAIT_DATA
	ld a,0xff	; timeout
	ret

dma_write
    ld (dma_to),hl
    ld hl,wr0
    set 2,(hl)
    jr dma_set

dma_read
    ld (dma_to),hl
    ld hl,wr0
    res 2,(hl)
dma_set
    ld hl,dma_cmd
    ld bc,(256*dma_cmd_len)+DMA_PORT
    otir	;tento otir funguje, ale neumi nahravat do dos banky
;	call	OTIR		;prestrankuj do dos banky a tam spust DMA prenos
    reti
;
dma_cmd
    db #C3  ; 11000011  WR6 reset
    db #C7  ; 11000111  WR6 reset port a to z80 std timing
    db #CB  ; 11001011  WR6 reset port b to z80 std timing
wr0 db #7D  ; 01111101  WR0 port a start+len    a>b,transfer
            ; 01111001  port a start+len    b>a,transfer
dma_to
    defw 0; port A start
    ; dw 0xeb ; SPI_PORT
dma_len     ; -1
    dw 511  ; port A len
    db 0x14 ; 00010100  WR1 port a inc, memory, 4T
	; ^^ TODO: 3T
    db 0x28 ; 00101000  WR2 port b fixed, port, 4T
    db 0xc0 ; 11000000  WR3 DMA enable
    ; db 0x8d ; 10001101  WR4 load port B addr, byte at time
    db 0xAd ; 10101101  WR4 load port B addr, CONTINUOUS
    dw SPI_PORT ; SPI_PORT
    db 0x92 ; 10010010  WR5 stop at blk end,EN wait
    db 0xcf ; 11001111  WR6 load
    db 0x87 ; 10000111  WR6 Enable DMA
dma_cmd_len   equ $-dma_cmd
