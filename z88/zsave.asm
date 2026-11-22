; zsave.asm - saved games on the Z88: the game's RAM, compressed, in an OZ
; file.  Built as module "zsave" next to sccz80's output (tools/build88.sh)
; so it is banked with save.c like C code.
;
; Everything Rogue knows lives in application RAM between __data_start and
; __bss_end (globals, the heap, the curses windows).  The C stack is OZ's,
; and the far-call state, the screen copy (zb_shown, zb_obuf) and these
; routines' own variables are in section bss_keep, outside that block.
; A save is the block, compressed; a restore unpacks it over RAM and the
; game carries on (src/save.c).
;
; File: 8 bytes that identify the card build ("RZ", __bss_end, _main,
; _look: another build's file is refused), then tokens until the block is
; full:
;   $00-$7F  n: n+1 bytes follow as they are
;   $80-$FF  n, lo, hi: copy (n & $7F) + 3 bytes from hi*256+lo back
; The packer (a simple LZ: a 256-entry hash of byte pairs, and the byte
; before for runs) makes about 7K of the 24K.  zb_shown is its scratch
; (hash table and output buffer), so the screen is redrawn whole after.
;
; int z_ramsave(char *name)   1 saved, 0 not
; int z_ramload(char *name)   1 restored, 0 no file / not readable,
;                             2 another build's file, 3 failed half way
;                             (RAM is spoilt: start a new game)
; int z_savexists(char *name) 1 if the file can be opened
; void z_savedel(char *name)

	MODULE	zsave
	INCLUDE	"fileio.def"

	SECTION	code_compiler

	defc	ZV_NAMELEN = 48
	defc	ZC_OBUF = 512		; output buffer: zb_shown + 512 ...
	defc	ZC_OBLEN = 240		; ... 240 bytes (zb_shown is 752)

._z_ramsave
	pop	bc
	pop	hl
	push	hl
	push	bc
	push	ix
	ld	a,OP_OUT
	call	zv_open
	jp	c,zv_no
	ld	hl,_zb_shown + ZC_OBUF
	ld	(zc_ob),hl
	xor	a
	ld	(zc_err),a
	ld	hl,zv_magic		; the header goes first
	ld	b,8
.zs_h	ld	a,(hl)
	call	zc_put
	inc	hl
	djnz	zs_h
	ld	hl,_zb_shown		; hash table: no positions
	ld	de,_zb_shown + 1
	ld	bc,511
	ld	(hl),0
	ldir
	ld	hl,__data_start
	ld	(zc_p),hl
	ld	(zc_lit),hl
	xor	a
	ld	(zc_nlit),a
.zs_loop
	ld	hl,(zc_p)		; done?
	ld	de,__bss_end
	ex	de,hl
	or	a
	sbc	hl,de			; hl = bytes left
	jp	z,zs_end
	ld	a,h			; longest match: min(left, 130)
	or	a
	jr	nz,zs_m130
	ld	a,l
	cp	130
	jr	c,zs_mx
.zs_m130
	ld	a,130
.zs_mx	ld	(zc_max),a
	xor	a
	ld	(zc_best),a
	ld	a,(zc_max)
	cp	3
	jr	c,zs_lit		; fewer than 3 bytes left
	ld	hl,(zc_p)		; hash of the next two bytes
	ld	a,(hl)
	add	a,a
	inc	hl
	xor	(hl)
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	de,_zb_shown
	add	hl,de			; hl = &table[h]
	ld	e,(hl)
	inc	hl
	ld	d,(hl)			; de = where those bytes were last
	ld	bc,(zc_p)
	ld	(hl),b			; and now here
	dec	hl
	ld	(hl),c
	ld	a,d
	or	e
	jr	z,zs_run
	call	zc_len			; de = candidate
	ld	(zc_best),a
	ld	hl,(zc_p)
	or	a
	sbc	hl,de
	ld	(zc_off),hl
.zs_run
	ld	de,(zc_p)		; the byte before: runs
	ld	hl,__data_start
	or	a
	sbc	hl,de
	jr	z,zs_pick
	dec	de
	call	zc_len
	ld	hl,zc_best
	cp	(hl)
	jr	c,zs_pick
	jr	z,zs_pick
	ld	(hl),a
	ld	hl,1
	ld	(zc_off),hl
.zs_pick
	ld	a,(zc_best)
	cp	3
	jr	c,zs_lit
	call	zc_flush		; literals before it
	ld	a,(zc_best)
	add	a,$80 - 3
	call	zc_put
	ld	a,(zc_off)
	call	zc_put
	ld	a,(zc_off + 1)
	call	zc_put
	ld	a,(zc_best)
	ld	e,a
	ld	d,0
	ld	hl,(zc_p)
	add	hl,de
	ld	(zc_p),hl
	ld	(zc_lit),hl
	jp	zs_loop
.zs_lit
	ld	hl,(zc_p)		; one more literal
	inc	hl
	ld	(zc_p),hl
	ld	hl,zc_nlit
	inc	(hl)
	ld	a,(hl)
	cp	128
	jp	nz,zs_loop
	call	zc_flush
	ld	hl,(zc_p)
	ld	(zc_lit),hl
	jp	zs_loop
.zs_end
	call	zc_flush
	call	zc_out			; the rest of the buffer
	ld	a,(zc_err)
	or	a
	jp	nz,zv_nocl
	call_oz(gn_cl)
	jp	c,zv_no
	ld	hl,1
	pop	ix
	ret
.zv_nocl
	call_oz(gn_cl)
.zv_no
	ld	hl,0
	pop	ix
	ret

; a = length of the match of (de) with (zc_p), at most zc_max
.zc_len
	push	de
	ld	hl,(zc_p)
	ld	a,(zc_max)
	ld	b,a
	ld	c,0
.zl_l	ld	a,(de)
	cp	(hl)
	jr	nz,zl_e
	inc	de
	inc	hl
	inc	c
	djnz	zl_l
.zl_e	ld	a,c
	pop	de
	ret

; write the pending literals (zc_nlit from zc_lit)
.zc_flush
	ld	a,(zc_nlit)
	or	a
	ret	z
	ld	b,a
	dec	a
	call	zc_put
	ld	hl,(zc_lit)
.zf_l	ld	a,(hl)
	call	zc_put
	inc	hl
	djnz	zf_l
	xor	a
	ld	(zc_nlit),a
	ret

; a to the output buffer; written out when full.  Keeps bc, de, hl.
.zc_put
	push	hl
	ld	hl,(zc_ob)
	ld	(hl),a
	inc	hl
	ld	(zc_ob),hl
	push	de
	ld	de,_zb_shown + ZC_OBUF + ZC_OBLEN
	or	a
	sbc	hl,de
	pop	de
	pop	hl
	ret	nz
	push	bc
	push	de
	push	hl
	call	zc_out			; (an error shows at the end)
	pop	hl
	pop	de
	pop	bc
	ret

; write the buffer; carry on error
.zc_out
	ld	hl,(zc_ob)
	ld	de,_zb_shown + ZC_OBUF
	or	a
	sbc	hl,de
	ld	b,h
	ld	c,l			; bc = bytes in it
	ex	de,hl
	ld	(zc_ob),hl
	ld	a,b
	or	c
	ret	z
	ld	de,0
	call_oz(os_mv)
	ret	nc
	ld	a,1
	ld	(zc_err),a
	scf
	ret

._z_ramload
	pop	bc
	pop	hl
	push	hl
	push	bc
	push	ix
	ld	a,OP_IN
	call	zv_open
	jp	c,zv_no
	ld	hl,zv_hdr		; this build's file?
	ld	b,8
.zr_h	call_oz(os_gb)
	jp	c,zv_nocl
	ld	(hl),a
	inc	hl
	djnz	zr_h
	ld	hl,zv_hdr
	ld	de,zv_magic
	ld	b,8
.zr_c	ld	a,(de)
	cp	(hl)
	jp	nz,zr_other
	inc	hl
	inc	de
	djnz	zr_c
	ld	de,__data_start		; unpack over the game's RAM: from here on
.zr_tok					; only registers, the stack and bss_keep
	ld	hl,__bss_end
	or	a
	sbc	hl,de
	jp	z,zr_done
	jp	c,zr_bad
	call_oz(os_gb)			; token
	jp	c,zr_bad
	bit	7,a
	jr	nz,zr_copy
	inc	a			; a+1 literal bytes
	ld	b,a
	call	zr_room
	jp	c,zr_bad
.zr_lit	call_oz(os_gb)
	jp	c,zr_bad
	ld	(de),a
	inc	de
	djnz	zr_lit
	jp	zr_tok
.zr_copy
	and	$7F
	add	a,3
	call	zr_room
	jp	c,zr_bad
	ld	c,a
	ld	b,0			; bc = length
	call_oz(os_gb)
	jp	c,zr_bad
	ld	l,a
	push	bc
	call_oz(os_gb)
	pop	bc
	jp	c,zr_bad
	ld	h,a			; hl = distance back
	push	de
	ex	de,hl
	or	a
	sbc	hl,de			; hl = de - distance
	pop	de
	ldir
	jp	zr_tok
.zr_room				; carry if a bytes do not fit before
	push	hl			; __bss_end (hl = room left)
	push	af
	ld	a,h
	or	a
	jr	nz,zr_ok
	pop	af
	push	af
	cp	l
	jr	z,zr_ok
	jr	c,zr_ok
	pop	af
	pop	hl
	scf
	ret
.zr_ok	pop	af
	pop	hl
	or	a
	ret
.zr_done
	call_oz(gn_cl)
	ld	hl,1
	pop	ix
	ret
.zr_other
	call_oz(gn_cl)
	ld	hl,2
	pop	ix
	ret
.zr_bad
	call_oz(gn_cl)
	ld	hl,3
	pop	ix
	ret

._z_savexists
	pop	bc
	pop	hl
	push	hl
	push	bc
	push	ix
	ld	a,OP_IN
	call	zv_open
	jp	c,zv_no
	call_oz(gn_cl)
	ld	hl,1
	pop	ix
	ret

._z_savedel
	pop	bc
	pop	hl
	push	hl
	push	bc
	push	ix
	ld	b,0
	call_oz(gn_del)
	pop	ix
	ret

.zv_open				; hl = name, a = mode -> ix, carry on error
	ld	b,0
	ld	de,zv_name
	ld	c,ZV_NAMELEN
	call_oz(gn_opf)
	ret

.zv_magic
	defm	"RZ"
	defw	__bss_end, _main, _look

	SECTION	bss_keep
.zv_hdr		defs	8
.zv_name	defs	48		; ZV_NAMELEN
.zc_p		defs	2
.zc_lit		defs	2
.zc_nlit	defs	1
.zc_max		defs	1
.zc_best	defs	1
.zc_off		defs	2
.zc_ob		defs	2
.zc_err		defs	1
._zb_shown	defs	752		; the screen as OZ shows it (src/zoz.c)
._zb_obuf	defs	392	; VDU string for GN_Sop (z88/hot.asm)

	GLOBAL	_z_ramsave
	GLOBAL	_z_ramload
	GLOBAL	_z_savexists
	GLOBAL	_z_savedel
	GLOBAL	__data_start
	GLOBAL	__bss_end
	GLOBAL	_main
	GLOBAL	_look
	GLOBAL	_zb_shown
	GLOBAL	_zb_obuf
