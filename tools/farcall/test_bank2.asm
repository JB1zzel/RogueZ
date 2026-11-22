        MODULE  test_bank2
        INCLUDE "test_fixed.def"
        ORG     $C000
        jp      strtest
        jp      pong
strtest:
        ld      hl,text
        push    hl
        call    res_sumstr              ; resident code reads bank 2's string
        pop     bc
        push    hl
        ld      hl,5
        push    hl
        ld      hl,6
        push    hl
        call    far_add                 ; nested far call to bank 1
        pop     bc
        pop     bc
        pop     de
        add     hl,de
        push    hl
        ld      hl,text
        push    hl
        call    res_sumstr              ; bank 2 must be bound again
        pop     bc
        pop     de
        add     hl,de
        ret
pong:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      a,d
        or      e
        jr      nz,pong_1
        ld      hl,0
        ret
pong_1: push    de
        dec     de
        push    de
        call    far_ping
        pop     bc
        pop     de
        add     hl,de
        ret
text:   defm    "Rogue"
        defb    0
