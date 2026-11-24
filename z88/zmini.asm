; zmini.asm - the mini map: the whole level in an 80 x 64 pixel map in the
; status panel's place (columns 80-93), one cell 1 pixel wide, 2 high.
; Gunther Strube's opengraphics method (the Z88 dev kit's notes): MP_GRA,
; OS_Sci SC_HR0 for the map memory, written directly.
;   void z_mini_open(void)    clear the map memory, window 2, the map
;   void z_mini_close(void)   give the map back (MP_DEL)
;   void z_mini_row(int y, unsigned char *row)
;                             level row y (1-22) from stdscr's row: walls,
;                             doors, passages, stairs and the hero are dots
; The map memory is bound in S1 for a moment (this code runs in S2, the
; fixed bank in S3).  Rogue's RAM from $4000 is out of sight then, so what
; is written is first gathered on the stack (OZ keeps it below $2000), and
; the old binding is kept there too.
; Built as module "zmini" next to sccz80's output (tools/build88.sh).

	MODULE	zmini
	INCLUDE	"map.def"
	INCLUDE	"screen.def"
	INCLUDE	"stdio.def"
	INCLUDE	"memory.def"
	SECTION	code_compiler

	defc	ZM_W = 80		; pixels

._z_mini_open
	ld	hl,zmo_win		; window 2, then the map in it (as the
	call_oz(gn_sop)			; kit's opengraphics: MP_GRA first)
	ld	a,'2'
	ld	bc,mp_gra
	ld	hl,ZM_W - 1		; the width - 1
	call_oz(os_map)
	ld	b,0
	ld	hl,0
	ld	a,sc_hr0
	call_oz(os_sci)			; B = bank, HL = address of HIRES0
	push	bc
	push	hl
	call_oz(os_sci)			; (written back as it was)
	pop	hl
	pop	bc
	ld	a,b
	ld	(zm_bank),a
	ld	a,h
	and	$3F
	or	$40			; its address in S1
	ld	h,a
	ld	(zm_addr),hl
	push	hl			; the map in S1; the old binding on
	ld	c,MS_S1			; the stack
	call_oz(os_mpb)
	pop	hl
	push	bc
	ld	d,h			; clear it
	ld	e,l
	inc	de
	ld	(hl),0
	ld	bc,ZM_W * 8 - 1
	ldir
	pop	bc			; Rogue's RAM back in S1
	ld	c,MS_S1
	call_oz(os_mpb)
	ret

._z_mini_close
	ld	a,'2'
	ld	bc,mp_del
	call_oz(os_map)
	ld	hl,zmc_win		; window 1 again, as zoz.c's winit but
	call_oz(gn_sop)			; not cleared: the stats are redrawn
	ret				; over the map (zmap.c)

._z_mini_row				; [ret][row][y]
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)			; de = row
	inc	hl
	ld	a,(hl)			; a = y
	dec	a
	add	a,a
	ld	c,a			; its first pixel row (even)
	push	bc
	ld	hl,-ZM_W / 8
	add	hl,sp
	ld	sp,hl			; 10 bytes on the stack: the row's pixels
	ex	de,hl			; hl = row, de = pixels
	push	de
	ld	c,ZM_W / 8
zmr_b:	ld	b,8
zmr_c:	ld	a,(hl)			; drawn: walls, doors, passages, stairs,
	inc	hl			; the hero
	and	$7F
	cp	'-'
	jr	z,zmr_1
	cp	'|'
	jr	z,zmr_1
	cp	'+'
	jr	z,zmr_1
	cp	'#'
	jr	z,zmr_1
	cp	'%'
	jr	z,zmr_1
	cp	'@'
	jr	z,zmr_1
	or	a			; carry clear: a gap
	jr	zmr_2
zmr_1:	scf
zmr_2:	ex	de,hl
	rl	(hl)
	ex	de,hl
	djnz	zmr_c
	inc	de
	dec	c
	jr	nz,zmr_b
	; hl = zm_addr + (py / 8) * 80 + (py mod 8): its first byte
	ld	hl,ZM_W / 8 + 2
	add	hl,sp
	ld	a,(hl)			; py
	ld	c,a
	and	$F8
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,hl
	add	hl,de			; (py AND $F8) * 10
	ld	a,c
	and	7
	ld	e,a
	ld	d,0
	add	hl,de
	ld	de,(zm_addr)
	add	hl,de
	pop	de			; the pixels
	push	hl			; the map in S1; the old binding on
	push	de			; the stack
	ld	a,(zm_bank)
	ld	b,a
	ld	c,MS_S1
	call_oz(os_mpb)
	pop	de
	pop	hl
	push	bc
	ld	b,ZM_W / 8		; both pixel rows (the same 8-row band)
zmr_p:	ld	a,(de)
	ld	(hl),a
	inc	hl
	ld	(hl),a
	dec	hl
	inc	de
	ld	a,l
	add	a,8
	ld	l,a
	jr	nc,zmr_q
	inc	h
zmr_q:	djnz	zmr_p
	pop	bc			; Rogue's RAM back in S1
	ld	c,MS_S1
	call_oz(os_mpb)
	ld	hl,ZM_W / 8 + 2
	add	hl,sp
	ld	sp,hl
	ret

zmc_win:				; the map's cells cleared as text, then
	defb	1,'7','#','2',32+80,32,32+14,32+8,128, 1,'2','C','2'
	defb	1,'7','#','1',32,32,32+94,32+8,128, 1,'2','-','C', 1,'2','-','S'
	defb	1,'2','H','1', 0
zmo_win:
	defb	1,'7','#','2',32+80,32,32+14,32+8,128, 1,'2','C','2'
	defb	1,'2','H','1', 0		; text goes to window 1 again

	SECTION	bss_compiler
zm_bank:	defs	1
zm_addr:	defs	2

	GLOBAL	_z_mini_open
	GLOBAL	_z_mini_close
	GLOBAL	_z_mini_row
