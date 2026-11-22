; Far-call test, fixed part ($8000): driver, stubs, a resident routine, RAM
        MODULE  test_fixed
        XDEF    far_add, far_long, far_ping, far_strtest, far_pong, res_sumstr
        ORG     $8000

start:
        ld      hl,fc_stack
        ld      (fc_sp),hl
        xor     a
        call    bind_s3                 ; the driver runs with bank 0 bound
; 1  add(30, 12) in bank 1
        ld      hl,30
        push    hl
        ld      hl,12
        push    hl
        call    far_add
        pop     bc
        pop     bc
        ld      (r1),hl
; 2  long result (DE:HL) from bank 1
        call    far_long
        ld      (r2),hl
        ld      (r2+2),de
; 3  through a function pointer: (*fp)(100, 23), fp = far_add
        ld      hl,100
        push    hl
        ld      hl,23
        push    hl
        ld      hl,far_add
        call    jphl
        pop     bc
        pop     bc
        ld      (r3),hl
; 4  bank 2 passes its own string to resident code, makes a nested far call,
;    then reads the string again
        call    far_strtest
        ld      (r4),hl
; 5  recursion between banks: ping(20) -> pong(19) -> ping(18) ...
        ld      hl,20
        push    hl
        call    far_ping
        pop     bc
        ld      (r5),hl
; 6  bank and far-call stack back where they started
        ld      a,(fc_bank)
        ld      (r6),a
        ld      hl,(fc_sp)
        ld      (r7),hl
        halt
jphl:   jp      (hl)

; resident: sum of the bytes of a string (sccz80 call: one argument)
res_sumstr:
        pop     bc
        pop     hl
        push    hl
        push    bc
        ld      de,0
rs_1:   ld      a,(hl)
        or      a
        jr      z,rs_2
        add     a,e
        ld      e,a
        jr      nc,rs_3
        inc     d
rs_3:   inc     hl
        jr      rs_1
rs_2:   ex      de,hl
        ret

; stubs (as tools/farify.py makes them); bank 1 and 2 jump tables at $C000
far_add:        ld a,1
                ld de,$C000
                jp farcall
far_long:       ld a,1
                ld de,$C003
                jp farcall
far_ping:       ld a,1
                ld de,$C006
                jp farcall
far_strtest:    ld a,2
                ld de,$C000
                jp farcall
far_pong:       ld a,2
                ld de,$C003
                jp farcall

        INCLUDE "farcall.asm"

; RAM
fc_sp:          defw 0
fc_bank:        defb 0
fc_target:      defw 0
fc_hl:          defw 0
fc_de:          defw 0
fc_stack:       defs 96
r1:             defw 0
r2:             defw 0, 0
r3:             defw 0
r4:             defw 0
r5:             defw 0
r6:             defb 0
r7:             defw 0
