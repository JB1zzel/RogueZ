; farcall.asm - far calls between code banks on the Z88 (z80asm, resident)
;
; Code banks are bound into segment 2 ($8000-$BFFF); the application bank in
; segment 3 holds this, the stubs (farstubs.asm) and all resident code.
; A stub:   far_foo:  ld a,BANK / ld de,_foo / jp farcall
; farcall keeps the caller's return address and bank on fc_stack, binds the
; target's bank, calls it with the stack exactly as a direct call leaves it,
; then keeps HL and DE (results), binds the caller's bank and returns.
; Tested in tools/farcall (the same code with OUT in place of OS_Mpb).

        MODULE  farcall
        INCLUDE "memory.def"

        PUBLIC  farcall, bind_s2, fc_bank, fc_tab, fc_sp, fc_stack, fc_init

        defc    FC_DEPTH = 32

        SECTION code_resident
farcall:
        ld      (fc_target),de
        pop     de                      ; caller's return address
        ld      hl,(fc_sp)
        ld      (hl),e
        inc     hl
        ld      (hl),d
        inc     hl
        ld      c,a
        ld      a,(fc_bank)
        ld      (hl),a                  ; caller's bank
        inc     hl
        ld      (fc_sp),hl
        ld      a,c
        call    bind_s2
        ld      hl,(fc_target)
        call    fc_jphl                 ; the target returns here
        ld      (fc_hl),hl
        ld      (fc_de),de
        ld      hl,(fc_sp)
        dec     hl
        ld      a,(hl)                  ; caller's bank
        dec     hl
        ld      d,(hl)
        dec     hl
        ld      e,(hl)
        ld      (fc_sp),hl
        push    de
        call    bind_s2
        ld      hl,(fc_hl)
        ld      de,(fc_de)
        ret
fc_jphl:
        jp      (hl)

; bind_s2: bind code bank A (0 = first code bank) into segment 2.
; fc_tab holds the absolute bank of each code bank (found at start-up).
bind_s2:
        ld      (fc_bank),a
        ld      hl,fc_tab
        add     a,l
        ld      l,a
        jr      nc,bs_nc
        inc     h
bs_nc:  ld      b,(hl)
        ld      c,MS_S2
        call_oz(os_mpb)
        ret

; fc_init: empty far-call stack
fc_init:
        ld      hl,fc_stack
        ld      (fc_sp),hl
        ret

        SECTION bss_keep                ; outside a saved game (zsave.asm)
fc_sp:          defs    2
fc_bank:        defs    1
fc_tab:         defs    8               ; absolute banks: code 0-5, data (rb_find)
fc_target:      defs    2
fc_hl:          defs    2
fc_de:          defs    2
fc_stack:       defs    3 * FC_DEPTH
