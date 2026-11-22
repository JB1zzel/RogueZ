; ozcalls.asm - OZ calls for the C screen layer (src/zoz.c), z80asm, resident
;
;   void oz_sop(char *s)    write a 0-terminated string (VDU codes included)
;   int  oz_in(void)        wait for a key: 0-255, or $100 escape,
;                           $200 redraw needed (RC_Draw), $300 quit, $400 other
; Both keep IX.  oz_in binds the current code bank into S2 again afterwards,
; in case OZ changed segment 2 while another application ran.

        MODULE  ozcalls
        INCLUDE "stdio.def"
        INCLUDE "error.def"

        PUBLIC  _oz_sop, _oz_in
        EXTERN  bind_s2, fc_bank

        SECTION code_resident
_oz_sop:
        pop     bc
        pop     hl
        push    hl
        push    bc
        push    ix
        call_oz(gn_sop)
        pop     ix
        ret

_oz_in:
        push    ix
        call_oz(os_in)
        pop     ix
        ld      h,0
        ld      l,a
        jr      nc,oi_rebind
        ld      h,1
        cp      RC_Esc
        jr      z,oi_rebind
        ld      h,2
        cp      RC_Draw
        jr      z,oi_rebind
        cp      RC_Susp
        jr      z,oi_rebind
        ld      h,3
        cp      RC_Quit
        jr      z,oi_rebind
        ld      h,4
oi_rebind:
        push    hl
        ld      a,(fc_bank)
        call    bind_s2
        pop     hl
        ret
