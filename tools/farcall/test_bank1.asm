        MODULE  test_bank1
        INCLUDE "test_fixed.def"
        ORG     $C000
        jp      add
        jp      long
        jp      ping
add:                                    ; add(a, b): [ret][b][a]
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        add     hl,de
        ret
long:   ld      hl,$5678
        ld      de,$1234
        ret
ping:                                   ; n + pong(n - 1), 0 at 0
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      a,d
        or      e
        jr      nz,ping_1
        ld      hl,0
        ret
ping_1: push    de
        dec     de
        push    de
        call    far_pong
        pop     bc
        pop     de
        add     hl,de
        ret
