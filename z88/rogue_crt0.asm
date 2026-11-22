; rogue_crt0.asm - start-up and memory map of Rogue as a Z88 application
;
; Card (128K, slot-relative banks; z88card places them, OZ adds the slot):
;   $38-$3D  code banks 0-5 (sections code_bankN, rodata_bankN), at $8000 (S2)
;   $3E      first values of the initialised data (copied to RAM at start)
;   $3F      application bank at $C000 (S3): this file, resident code, the
;            library, far-call stubs; the DOR at the top (z88/dor.asm)
; RAM: $2000-$7FFF, 96 pages of continuous ("bad") memory from the DOR:
;   initialised data, then zeroed data (bss)
; The card's absolute bank numbers (fc_base) come from the application bank,
; which OZ binds into S3 (OS_Mgb): code bank 0 is 7 banks below it.

        MODULE  rogue_crt0

        INCLUDE "stdio.def"
        INCLUDE "error.def"
        INCLUDE "memory.def"
        INCLUDE "fileio.def"
        INCLUDE "director.def"
        INCLUDE "time.def"

        PUBLIC  __Exit, l_dcal, applname, _z_newgame, __data_start, __bss_end, __keep_end
        EXTERN  far_main, fc_init, fc_base, fc_bank

        defc    CRT_ORG_CODE = $C000
        defc    TAR__clib_exit_stack_size = 32
        defc    TAR__register_sp = -1
        defc    CRT_KEY_DEL = 127
        INCLUDE "crt/classic/crt_rules.inc"

        defc    RAMPAGES = 96           ; $2000-$7FFF
        defc    DATABANK = 6            ; card bank of the data image (from bank 0)

        SECTION CODE
        org     CRT_ORG_CODE

        jp      start                   ; OZ enters here ...
        scf                             ; ... and calls entry+3 as an enquiry
        ret

start:
        ld      a,(ix+2)                ; top page of the memory OZ gave us
        cp      $20 + RAMPAGES
        ld      hl,msg_nomem
        jr      c,init_error
        ld      ix,-1                   ; an expanded machine?
        ld      a,FA_EOF
        call_oz(os_frm)
        ld      hl,msg_expanded
        jr      nz,init_error

        ld      a,SC_DIS                ; ESC is an ordinary key (Rogue: cancel)
        call_oz(Os_Esc)
        xor     a
        ld      b,a
        ld      hl,errhan
        call_oz(os_erh)
        ld      hl,applname
        call_oz(dc_nam)
        ld      (crt_sp),sp             ; for z_newgame
restart:

        ld      c,MS_S3                 ; S3 holds the application bank, card
        call_oz(os_mgb)                 ; bank $3F: code bank 0 ($38) is 7 below
        ld      a,b
        sub     7
        push    af                      ; A = absolute bank of code bank 0

        add     a,DATABANK              ; first values of the initialised data
        ld      b,a
        ld      c,MS_S2
        call_oz(os_mpb)
        ld      hl,$8000
        ld      de,__data_start
        ld      bc,__data_end - __data_start
        ld      a,b
        or      c
        jr      z,no_data
        ldir
no_data:
        ld      hl,__bss_start          ; zero the rest (OZ does not clear
        ld      bc,__bss_end - __bss_start  ; application RAM after a KILL)
clr:    ld      (hl),0
        inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz,clr

        pop     af
        ld      (fc_base),a
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
        xor     a
        call_oz(os_bye)

; void z_newgame(void): after the tombstone, start again as if from the
; Index: the C stack is dropped, the data copied and cleared again.
_z_newgame:
        ld      sp,(crt_sp)
        jp      restart

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
        jr      z,__Exit
        xor     a
        ret

l_dcal: jp      (hl)

        SECTION rodata_resident
applname:       defm    "Rogue", 0
argv:           defw    applname, 0
win_err:        defb    1,'7','#','1',32,32,32+94,32+8,128,1,'2','C','1',0
msg_nomem:      defm    "Rogue: not enough memory free (it needs 24K).", 0
msg_expanded:   defm    "Rogue needs an expanded Z88.", 0

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
        SECTION KEEP_END
__keep_end:
