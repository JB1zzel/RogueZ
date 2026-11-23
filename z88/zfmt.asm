; zfmt.asm - status panel formatting (z_status, src/zcold.c), at z_fp:
; void z_fs(const char *s): copy s, z_fp left on its terminator
; void z_fu(unsigned int u): u in decimal (not terminated)
; Built as module "zfmt" next to sccz80's output (tools/build88.sh), banked
; with zcold like C code (it was in the fixed bank, which is full).

	MODULE	zfmt
	SECTION	code_compiler
._z_fs
        pop     bc
        pop     hl
        push    hl
        push    bc
        ld      de,(_z_fp)
.fs_l
        ld      a,(hl)
        ld      (de),a
        or      a
        jr      z,fs_e
        inc     hl
        inc     de
        jr      fs_l
.fs_e
        ld      (_z_fp),de
        ret

._z_fu
        pop     bc
        pop     hl
        push    hl
        push    bc
        ld      de,(_z_fp)
        xor     a
        ld      (fu_on),a
        ld      bc,-10000
        call    fu_dig
        ld      bc,-1000
        call    fu_dig
        ld      bc,-100
        call    fu_dig
        ld      bc,-10
        call    fu_dig
        ld      a,l
        add     a,'0'
        ld      (de),a
        inc     de
        ld      (_z_fp),de
        ret
.fu_dig	; hl = u, bc = -power
        ld      a,'0'-1
.fu_l
        inc     a
        add     hl,bc
        jr      c,fu_l
        sbc     hl,bc                   ; undo the last (carry is clear)
        cp      '0'
        jr      nz,fu_out
        ld      a,(fu_on)               ; leading zero?
        or      a
        ret     z
        ld      a,'0'
.fu_out
        ld      (de),a
        inc     de
        ld      a,1
        ld      (fu_on),a
        ret


	SECTION	bss_compiler
.fu_on	defs    1


	GLOBAL	_z_fs
	GLOBAL	_z_fu
	GLOBAL	_z_fp
