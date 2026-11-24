; rogue_crt0.asm - start-up and memory map of Rogue as a Z88 application
;
; Card (128K, slot-relative banks; z88card places them, OZ adds the slot):
;   $38-$39  empty (not part of the RAM application)
;   $3A-$3E  code banks 0-4 (sections code_bankN, rodata_bankN), at $8000 (S2);
;            bank 4 ($3E) also has, at its top, the first values of the
;            initialised data (packed; copied to RAM at start) and the MENU
;            and help, untokenized (tools/mkcard.py).  NBANKS is the setting.
;   $3F      application bank at $C000 (S3): this file, resident code, the
;            library, far-call stubs; the DOR at the top (z88/dor.asm)
; RAM: $2000-$7FFF, 96 pages of continuous ("bad") memory from the DOR:
;   initialised data, then zeroed data (bss)
; Six banks in all (a RAM application: OZ 4.7's installer loads at most 7).
; The absolute numbers of the other NBANKS banks (fc_tab) are found at start-up
; by their signatures (rb_find): a card has them below the application
; bank, an installed RAM application anywhere.

        MODULE  rogue_crt0

        INCLUDE "stdio.def"
        INCLUDE "error.def"
        INCLUDE "memory.def"
        INCLUDE "fileio.def"
        INCLUDE "director.def"
        INCLUDE "time.def"
        INCLUDE "map.def"

        PUBLIC  __Exit, l_dcal, applname, _z_newgame, __data_start, __bss_end, __keep_end
        EXTERN  far_main, fc_init, fc_tab, fc_bank

        defc    CRT_ORG_CODE = $C000
        defc    TAR__clib_exit_stack_size = 32
        defc    TAR__register_sp = -1
        defc    CRT_KEY_DEL = 127
        INCLUDE "crt/classic/crt_rules.inc"

        defc    RAMPAGES = 96           ; $2000-$7FFF
        defc    NBANKS = 5              ; code banks 0-4 below the application
        defc    DATABANK = NBANKS - 1   ; bank; the last also has the data image

        SECTION CODE
        org     CRT_ORG_CODE

        jp      start                   ; OZ enters here ...
        scf                             ; ... and calls entry+3 as an enquiry
        ret

start:
        ld      a,(ix+2)                ; top page of the memory OZ gave us
        cp      $20 + RAMPAGES
        jr      nc,ram_ok
        cp      $40                     ; OZ 4 with RAM only inside gives
        ld      hl,msg_nomem            ; $2000-$3FFF: take a bank of our own
        jp      c,init_error            ; for $4000-$7FFF
        call    ram_s1
        ld      hl,msg_nomem
        jp      c,init_error
        jr      ram_got
ram_ok:
        ld      hl,0
        ld      (ram_pool),hl
ram_got:
        ld      ix,-1                   ; an expanded machine?
        ld      a,FA_EOF
        call_oz(os_frm)
        ld      hl,msg_nomem
        jp      nz,init_error

        ld      a,SC_DIS                ; ESC is an ordinary key (Rogue: cancel)
        call_oz(Os_Esc)
        xor     a
        ld      (_z_upstairs),a         ; MENU Options: off until chosen
        ld      (_z_mini),a             ; the panel shows the stats
        ld      b,a
        ld      hl,errhan
        call_oz(os_erh)
        ld      hl,applname
        call_oz(dc_nam)
        ld      (crt_sp),sp             ; for z_newgame
restart:

        call    rb_find                 ; where are the other 7 banks?
        ld      hl,msg_banks
        jp      c,init_error
        ld      a,(fc_tab + DATABANK)   ; first values of the initialised data
        ld      b,a
        ld      c,MS_S2
        call_oz(os_mpb)
rb_dat: ld      hl,$8000                ; + its offset (tools/mkcard.py)
        ld      de,__data_start         ; packed: n (1-127) then n bytes;
dz_lp:  ld      a,(hl)                  ; $80+n-1: n zeros; 0: the end
        inc     hl
        or      a
        jr      z,no_data
        jp      m,dz_zero
        ld      c,a
        ld      b,0
        ldir
        jr      dz_lp
dz_zero:
        sub     $7F
        ld      b,a
        xor     a
dz_z:   ld      (de),a
        inc     de
        djnz    dz_z
        jr      dz_lp
no_data:
        ld      hl,__bss_start          ; zero the rest (OZ does not clear
        ld      bc,__bss_end - __bss_start  ; application RAM after a KILL)
clr:    ld      (hl),0
        inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz,clr

        call    fc_init

        ld      hl,1                    ; main(1, argv, NULL), in code bank 0
        push    hl
        ld      hl,argv
        push    hl
        ld      hl,0
        push    hl
        call    far_main
        pop     bc
        pop     bc
        pop     bc
__Exit:
        ld      a,(_z_mini)             ; give the map back
        or      a
        jr      z,exit_map
        ld      a,'2'
        ld      bc,mp_del
        call_oz(os_map)
exit_map:
        ld      ix,(ram_pool)           ; our own $4000-$7FFF bank, if any
        ld      a,ixh                   ; (OS_Bye frees it too)
        or      ixl
        jr      z,exit_bye
        call_oz(os_mcl)
exit_bye:
        xor     a
        call_oz(os_bye)

; void z_newgame(void): after the tombstone, start again as if from the
; Index: the C stack is dropped, the data copied and cleared again.
_z_newgame:
        ld      sp,(crt_sp)
        jp      restart

; rb_find: fc_tab[0..6] = the absolute numbers of code banks 0-5 and the
; data bank.  On a card they are the 7 banks below the application bank (in
; S3); installed as a RAM application they can be anywhere.  Each carries a
; signature at $3FF0 (tools/mkcard.py): "RG88", a 4-byte build stamp (also
; in rb_sig here), its number.  Try the card layout, then every bank from
; $FF down to $20.  Carry if one is missing.
rb_find:
        ld      hl,fc_tab               ; none found yet
        ld      b,NBANKS
rb_z:   ld      (hl),0
        inc     hl
        djnz    rb_z
        ld      c,MS_S3
        call_oz(os_mgb)                 ; b = application bank
        ld      a,b
        sub     NBANKS
        ld      e,NBANKS
rb_card:                                ; the card layout
        push    af
        push    de
        call    rb_check
        pop     de
        pop     af
        inc     a
        dec     e
        jr      nz,rb_card
        call    rb_all
        ret     nc
        ld      a,$FF                   ; anywhere
rb_scan:
        push    af
        call    rb_check
        pop     af
        dec     a
        cp      $1F
        jr      nz,rb_scan
rb_all:                                 ; nc if all found
        ld      hl,fc_tab
        ld      b,NBANKS
rb_a1:  ld      a,(hl)
        or      a
        scf
        ret     z
        inc     hl
        djnz    rb_a1
        or      a
        ret

rb_check:                               ; bank a: ours? fc_tab[n] = a
        ld      b,a
        ld      d,a
        ld      c,MS_S2
        call_oz(os_mpb)
        ld      hl,$BFF0
        ld      de,rb_sig
        ld      b,8
rb_c1:  ld      a,(de)
        cp      (hl)
        ret     nz
        inc     hl
        inc     de
        djnz    rb_c1
        ld      a,(hl)                  ; its number
        cp      NBANKS
        ret     nc
        ld      e,a
        ld      d,0
        push    hl
        ld      hl,fc_tab
        add     hl,de
        ex      (sp),hl
        ld      c,MS_S2                 ; (the bank is still in S2)
        call_oz(os_mgb)
        pop     hl
        ld      (hl),b
        ret

; ram_s1: OZ 4.x gives a bad application more than $2000-$3FFF only when
; there is RAM in slot 1; with RAM inside only (a 512K Z88) it gives 8K.
; Take a whole bank of our own for $4000-$7FFF: a memory pool (OS_Mop
; MM_S1) belongs to one bank, so take its 64 pages (OS_Mal, 256 bytes
; each, the most OZ gives at once).  The first pool may get a bank OZ is
; already using; such a pool is kept open while the next is tried (so the
; next one gets another bank), then closed.  Bind the bank to S1; OZ keeps
; the binding for the application.  Carry if not possible.
; Its notes live at $2000, in the 8K OZ gave, before the data goes there.
        defc    RS_N = $2000            ; pools kept open
        defc    RS_H = $2002            ; their handles
        defc    RS_TRIES = 8
ram_s1:
        xor     a
        ld      (RS_N),a
rs_try:
        ld      a,MM_S1
        ld      bc,0
        call_oz(os_mop)                 ; ix = pool
        jr      c,rs_fail
        call    rs_fill
        jr      nc,rs_ok
        ld      a,(RS_N)                ; keep this one open for now
        ld      l,a
        ld      h,0
        add     hl,hl
        ld      de,RS_H
        add     hl,de
        push    ix
        pop     de
        ld      (hl),e
        inc     hl
        ld      (hl),d
        ld      hl,RS_N
        inc     (hl)
        ld      a,(hl)
        cp      RS_TRIES
        jr      c,rs_try
        call    rs_close
rs_fail:
        scf
        ret
rs_ok:
        push    de                      ; d = the bank
        push    ix
        call    rs_close                ; the pools that did not do
        pop     ix
        pop     de
        ld      b,d
        ld      c,MS_S1
        call_oz(os_mpb)
        ld      (ram_pool),ix           ; (bss_keep: in that bank now)
        or      a
        ret

rs_fill:                                ; 64 pages from pool ix, one bank:
        ld      de,64                   ; nc and d = bank, or carry
rs_page:
        push    de
        ld      bc,256
        xor     a
        call_oz(os_mal)                 ; bhl = a page
        pop     de
        ret     c
        ld      a,d
        or      a
        jr      z,rs_first
        cp      b
        jr      nz,rs_other
        jr      rs_next
rs_first:
        ld      d,b
rs_next:
        dec     e
        jr      nz,rs_page
        or      a
        ret
rs_other:
        scf
        ret

rs_close:                               ; close the pools kept open
        ld      hl,RS_N
        ld      a,(hl)
        or      a
        ret     z
        dec     (hl)
        ld      l,a
        dec     l
        ld      h,0
        add     hl,hl
        ld      de,RS_H
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        push    de
        pop     ix
        call_oz(os_mcl)
        jr      rs_close

init_error:
        push    hl
        ld      hl,win_err
        call_oz(gn_sop)
        pop     hl
        call_oz(gn_sop)
        ld      bc,500
        call_oz(os_dly)
        xor     a
        call_oz(os_bye)


errhan: ret     z
        cp      RC_Quit                 ; KILL from the Index
        jp      z,__Exit
        xor     a
        ret

l_dcal: jp      (hl)

        SECTION rodata_resident
applname:       defm    "Rogue", 0
argv:           defw    applname, 0
win_err:        defb    1,'7','#','1',32,32,32+94,32+8,128,1,'2','C','1',0
msg_nomem:      defm    "Rogue needs more memory.", 0   ; 24K free, an expanded Z88
msg_banks:      defm    "Rogue: bank missing.", 0
rb_sig:         defm    "RG88"          ; + the build stamp (mkcard.py)
                defb    0, 0, 0, 0

; ---- memory map ------------------------------------------------------------
        INCLUDE "crt/classic/crt_section_code.inc"
        SECTION code_resident
        INCLUDE "crt/classic/crt_section_rodata.inc"
        SECTION rodata_resident
        SECTION ROMABLE_END

        SECTION code_bank0
        org     $8000
        SECTION rodata_bank0
        SECTION code_bank1
        org     $8000
        SECTION rodata_bank1
        SECTION code_bank2
        org     $8000
        SECTION rodata_bank2
        SECTION code_bank3
        org     $8000
        SECTION rodata_bank3
        SECTION code_bank4
        org     $8000
        SECTION rodata_bank4
        SECTION code_bank5
        org     $8000
        SECTION rodata_bank5

        SECTION RAM
        org     $2000
__data_start:
        INCLUDE "crt/classic/crt_section_data.inc"
        SECTION data_resident
        SECTION DATA_END
__data_end:
__bss_start:
        INCLUDE "crt/classic/crt_section_bss.inc"
        SECTION bss_resident
        SECTION BSS_END
__bss_end:
        SECTION bss_keep                ; not cleared by a new game, not in a
                                        ; saved game (z88/zsave.asm): far-call
                                        ; state, the start-up stack pointer
        SECTION bss_keep
crt_sp: defs    2
ram_pool: defs  2                       ; memory pool for $4000-$7FFF, or 0
        PUBLIC  _z_upstairs, _z_mini
_z_upstairs: defs 1                     ; stairs lead up too (options.c)
_z_mini: defs   1                       ; the panel shows the mini map (zmap.c)
        SECTION KEEP_END
__keep_end:
