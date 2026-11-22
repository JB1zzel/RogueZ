; farcall.asm - call a C function (sccz80) in another code bank
;
; Code banks are bound into segment 3 ($C000-$FFFF).  Every banked function
; that is called from another bank, from resident code, or through a function
; pointer has a stub (made by tools/farify.py), resident in the fixed bank:
;
;     far_foo:  ld   a,BANK         ; card bank of foo, 0 = first code bank
;               ld   de,_foo
;               jp   farcall
;
; farcall moves the caller's return address and bank to a small stack of its
; own (fc_stack), so the target finds its arguments exactly where a direct
; call puts them (sccz80: caller pushes them, caller removes them).  On the
; way back it keeps HL and DE (int, pointer and long results), binds the
; caller's bank again and returns to the caller.  A, BC and flags are not
; kept: sccz80 expects nothing in them after a call.
;
; fc_stack holds 3 bytes per nested far call (FC_DEPTH levels).

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
        call    bind_s3
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
        push    de                      ; return address back on the stack
        call    bind_s3
        ld      hl,(fc_hl)
        ld      de,(fc_de)
        ret
fc_jphl:
        jp      (hl)

; bind_s3: bind code bank A (0 = first code bank) into segment 3.
; Test harness (tools/zbank): OUT ($D3),A.  On the Z88: A + card base bank,
; OS_Mpb with C = MS_S3 (see BANKING.txt).
bind_s3:
        ld      (fc_bank),a
        out     ($D3),a
        ret
