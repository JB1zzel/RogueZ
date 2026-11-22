; zlook.asm - look() from src/misc.c, by hand: the 3x3 squares round the
; hero, every turn.  Built as module "zlook" next to sccz80's output
; (tools/build88.sh copies it into the build), so tools/banks.py puts it in
; a code bank with misc and tools/farify.py turns calls into other banks
; into far calls, as for C.  Keep it in step with the C version.
;
; Offsets: THING t_pos.x +4, .y +6, t_disguise +10, t_flags +14 (short),
; t_room +43; room r_flags +14; PLACE p_ch +0, p_flags +1, p_mi +2.
; Flags: ISBLIND $0004, ISINVIS $0400, ISHALU $0800, SEEMONST $4000,
; ISDARK 1, F_PASS $80.

	MODULE	zlook

	SECTION	code_compiler

; void look(bool wakeup)
._look
	ld	hl,2
	add	hl,sp
	ld	a,(hl)
	ld	(lk_wake),a
	xor	a
	ld	(lk_pass),a
	; if (!ce(oldpos, hero)) { erase_lamp(&oldpos, oldrp); oldpos = hero;
	;                          oldrp = proom; }
	ld	hl,(_oldpos)
	ld	de,(_player+4)
	and	a
	sbc	hl,de
	jp	nz,lk_moved
	ld	hl,(_oldpos+2)
	ld	de,(_player+6)
	and	a
	sbc	hl,de
	jp	z,lk_same
.lk_moved
	ld	hl,_oldpos
	push	hl
	ld	hl,(_oldrp)
	push	hl
	call	_erase_lamp
	pop	bc
	pop	bc
	ld	hl,(_player+4)
	ld	(_oldpos),hl
	ld	hl,(_player+6)
	ld	(_oldpos+2),hl
	ld	hl,(_player+43)
	ld	(_oldrp),hl
.lk_same
	ld	a,(_player+4)
	ld	(lk_hx),a
	ld	a,(_player+6)
	ld	(lk_hy),a
	ld	a,(_player+14)		; ISBLIND
	and	$04
	ld	(lk_blind),a
	ld	a,(lk_hx)		; the hero's own square
	ld	l,a
	ld	h,0
	ld	a,(lk_hy)
	ld	e,a
	ld	d,h
	call	zpa
	ld	a,(hl)
	ld	(lk_pch),a
	inc	hl
	ld	a,(hl)
	ld	(lk_pfl),a
	ld	a,(lk_hy)		; for (y = hero.y - 1; y <= hero.y + 1; y++)
	dec	a
	ld	(lk_y),a
.lk_yloop
	ld	a,(lk_y)		; if (y > 0 && y < NUMLINES - 1)
	dec	a
	cp	22
	jp	nc,lk_ynext
	ld	a,(lk_hx)		; for (x = hero.x - 1; x <= hero.x + 1; x++)
	dec	a
	ld	(lk_x),a
.lk_xloop
	call	lk_cell
	ld	a,(lk_hx)
	inc	a
	ld	hl,lk_x
	cp	(hl)
	jp	z,lk_ynext
	inc	(hl)
	jp	lk_xloop
.lk_ynext
	ld	a,(lk_hy)
	inc	a
	ld	hl,lk_y
	cp	(hl)
	jp	z,lk_ydone
	inc	(hl)
	jp	lk_yloop
.lk_ydone
	; if (door_stop && !firstmove && passcount > 1) running = FALSE;
	call	lk_ds
	jp	z,lk_e1
	ld	a,(lk_pass)
	cp	2
	jp	c,lk_e1
	xor	a
	ld	(_running),a
.lk_e1
	; if (!running || !jump) mvaddch(hero.y, hero.x, PLAYER);
	ld	a,(_running)
	or	a
	jp	z,lk_e2
	ld	a,(_jump)
	or	a
	ret	nz
.lk_e2
	ld	hl,(_stdscr)
	push	hl
	ld	hl,(_player+6)
	push	hl
	ld	hl,(_player+4)
	push	hl
	call	_wmove
	pop	bc
	pop	bc
	pop	bc
	ld	hl,(_stdscr)
	push	hl
	ld	hl,'@'
	push	hl
	call	_waddch
	pop	bc
	pop	bc
	ret

; one square (lk_y, lk_x); ret = C's continue
.lk_cell
	ld	a,(lk_x)		; if (x < 0 || x >= NUMCOLS) continue;
	cp	80
	ret	nc
	ld	a,(lk_blind)		; not blind: skip the hero's square
	or	a
	jp	nz,lk_c1
	call	lk_onhero
	ret	z
.lk_c1
	ld	a,(lk_x)		; pp = INDEX(y, x); ch = pp->p_ch
	ld	l,a
	ld	h,0
	ld	a,(lk_y)
	ld	e,a
	ld	d,h
	call	zpa
	ld	(lk_pp),hl
	ld	a,(hl)
	cp	' '
	ret	z
	ld	(lk_ch),a
	inc	hl
	ld	a,(hl)
	ld	(lk_fl),a
	; if (pch != DOOR && ch != DOOR && (pfl & F_PASS) != (fl & F_PASS)) continue
	ld	a,(lk_pch)
	cp	'+'
	jp	z,lk_c2
	ld	a,(lk_ch)
	cp	'+'
	jp	z,lk_c2
	ld	a,(lk_pfl)
	ld	hl,lk_fl
	xor	(hl)
	and	$80
	ret	nz
.lk_c2
	; if (((fl & F_PASS) || ch == DOOR) && ((pfl & F_PASS) || pch == DOOR))
	ld	a,(lk_fl)
	and	$80
	jp	nz,lk_c3
	ld	a,(lk_ch)
	cp	'+'
	jp	nz,lk_c5
.lk_c3
	ld	a,(lk_pfl)
	and	$80
	jp	nz,lk_c4
	ld	a,(lk_pch)
	cp	'+'
	jp	nz,lk_c5
.lk_c4
	;   if (hero.x != x && hero.y != y &&
	;       !step_ok(chat(y, hero.x)) && !step_ok(chat(hero.y, x))) continue
	ld	a,(lk_x)
	ld	hl,lk_hx
	cp	(hl)
	jp	z,lk_c5
	ld	a,(lk_y)
	ld	hl,lk_hy
	cp	(hl)
	jp	z,lk_c5
	ld	a,(lk_hx)
	ld	l,a
	ld	h,0
	ld	a,(lk_y)
	ld	e,a
	ld	d,h
	call	zpa
	ld	a,(hl)
	call	zstepok
	jp	nz,lk_c5
	ld	a,(lk_x)
	ld	l,a
	ld	h,0
	ld	a,(lk_hy)
	ld	e,a
	ld	d,h
	call	zpa
	ld	a,(hl)
	call	zstepok
	ret	z
.lk_c5
	ld	hl,(lk_pp)		; tp = p_monst_of(pp)
	inc	hl
	inc	hl
	ld	a,(hl)
	or	a
	jp	nz,lk_mon
	ld	h,a
	ld	l,a
	ld	(lk_tp),hl
	; ch = trip_ch(y, x, ch): changes nothing unless hallucinating
	ld	a,(_player+15)		; ISHALU
	and	$08
	jp	z,lk_c6
	ld	a,(lk_y)
	ld	l,a
	ld	h,0
	push	hl
	ld	a,(lk_x)
	ld	l,a
	push	hl
	ld	a,(lk_ch)
	ld	l,a
	push	hl
	call	_trip_ch
	pop	bc
	pop	bc
	pop	bc
	ld	a,l
	ld	(lk_ch),a
	jp	lk_c6
.lk_mon
	ld	l,a
	ld	h,0
	push	hl
	call	_thing_of
	pop	bc
	ld	(lk_tp),hl
	; if (on(player, SEEMONST) && on(*tp, ISINVIS))
	ld	a,(_player+15)		; SEEMONST
	and	$40
	jp	z,lk_m1
	ld	de,15
	add	hl,de
	ld	a,(hl)			; ISINVIS
	and	$04
	jp	z,lk_m1
	call	lk_ds			;   if (door_stop && !firstmove) running = FALSE;
	ret	z
	xor	a
	ld	(_running),a
	ret				;   continue
.lk_m1
	ld	a,(lk_wake)		; if (wakeup) wake_monster(y, x);
	or	a
	jp	z,lk_m2
	ld	a,(lk_y)
	ld	l,a
	ld	h,0
	push	hl
	ld	a,(lk_x)
	ld	l,a
	push	hl
	call	_wake_monster
	pop	bc
	pop	bc
.lk_m2
	ld	hl,(lk_tp)		; if (see_monst(tp))
	push	hl
	call	_see_monst
	pop	bc
	ld	a,l
	or	a
	jp	z,lk_c6
	ld	a,(_player+15)		;   ISHALU: ch = rnd(26) + 'A'
	and	$08
	jp	z,lk_m3
	ld	hl,26
	push	hl
	call	_rnd
	pop	bc
	ld	a,l
	add	a,'A'
	ld	(lk_ch),a
	jp	lk_c6
.lk_m3
	ld	hl,(lk_tp)		;   else ch = tp->t_disguise
	ld	de,10
	add	hl,de
	ld	a,(hl)
	ld	(lk_ch),a
.lk_c6
	ld	a,(lk_blind)		; if (blind && not the hero's square) continue
	or	a
	jp	z,lk_c7
	call	lk_onhero
	ret	nz
.lk_c7
	ld	hl,(_stdscr)		; move(y, x): always on the window, so just
	ld	de,8			; set _cury, _curx (WINDOW +8, +10)
	add	hl,de
	ld	a,(lk_y)
	ld	(hl),a
	inc	hl
	ld	(hl),0
	inc	hl
	ld	a,(lk_x)
	ld	(hl),a
	inc	hl
	ld	(hl),0
	; if ((proom->r_flags & ISDARK) && !see_floor && ch == FLOOR) ch = ' '
	ld	hl,(_player+43)
	ld	de,14
	add	hl,de
	ld	a,(hl)
	and	1
	jp	z,lk_c8
	ld	a,(_see_floor)
	or	a
	jp	nz,lk_c8
	ld	a,(lk_ch)
	cp	'.'
	jp	nz,lk_c8
	ld	a,' '
	ld	(lk_ch),a
.lk_c8
	; if (tp != NULL || ch != CCHAR(inch())) addch(ch)
	ld	hl,(lk_tp)
	ld	a,h
	or	l
	jp	nz,lk_add
	ld	hl,(_stdscr)		; inch(): _row[y][x] (WINDOW +16)
	ld	de,16
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,(lk_y)
	ld	e,a
	ld	d,0
	add	hl,de
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,(lk_x)
	ld	e,a
	add	hl,de
	ld	a,(hl)
	and	$7F
	ld	hl,lk_ch
	cp	(hl)
	jp	z,lk_run
.lk_add
	ld	hl,(_stdscr)
	push	hl
	ld	a,(lk_ch)
	ld	l,a
	ld	h,0
	push	hl
	call	_waddch
	pop	bc
	pop	bc
.lk_run
	; if (door_stop && !firstmove && running)
	call	lk_ds
	ret	z
	ld	a,(_running)
	or	a
	ret	z
	ld	a,(lk_hy)		; d = y - hero.y, e = x - hero.x (-1..1)
	ld	b,a
	ld	a,(lk_y)
	sub	b
	ld	d,a
	ld	a,(lk_hx)
	ld	b,a
	ld	a,(lk_x)
	sub	b
	ld	e,a
	ld	a,(_runch)		; switch (runch): squares behind are ignored
	cp	'h'
	jp	nz,lk_r1
	ld	a,e			;   x == ex
	dec	a
	ret	z
	jp	lk_rch
.lk_r1
	cp	'j'
	jp	nz,lk_r2
	ld	a,d			;   y == sy
	inc	a
	ret	z
	jp	lk_rch
.lk_r2
	cp	'k'
	jp	nz,lk_r3
	ld	a,d			;   y == ey
	dec	a
	ret	z
	jp	lk_rch
.lk_r3
	cp	'l'
	jp	nz,lk_r4
	ld	a,e			;   x == sx
	inc	a
	ret	z
	jp	lk_rch
.lk_r4
	cp	'y'
	jp	nz,lk_r5
	ld	a,d			;   (y + x) - sumhero >= 1
	add	a,e
	dec	a
	cp	2
	ret	c
	jp	lk_rch
.lk_r5
	cp	'u'
	jp	nz,lk_r6
	ld	a,d			;   (y - x) - diffhero >= 1
	sub	e
	dec	a
	cp	2
	ret	c
	jp	lk_rch
.lk_r6
	cp	'n'
	jp	nz,lk_r7
	ld	a,d			;   (y + x) - sumhero <= -1
	add	a,e
	add	a,2
	cp	2
	ret	c
	jp	lk_rch
.lk_r7
	cp	'b'
	jp	nz,lk_rch
	ld	a,d			;   (y - x) - diffhero <= -1
	sub	e
	add	a,2
	cp	2
	ret	c
.lk_rch
	ld	a,(lk_ch)		; switch (ch)
	cp	'+'
	jp	nz,lk_r8
	call	lk_inline		;   DOOR: in line with the hero: stop
	ret	nz
	xor	a
	ld	(_running),a
	ret
.lk_r8
	cp	'#'
	jp	nz,lk_r9
	call	lk_inline		;   PASSAGE: in line: passcount++
	ret	nz
	ld	hl,lk_pass
	inc	(hl)
	ret
.lk_r9
	cp	'.'
	ret	z
	cp	'|'
	ret	z
	cp	'-'
	ret	z
	cp	' '
	ret	z
	xor	a			;   anything else: stop
	ld	(_running),a
	ret

; z if (lk_y, lk_x) is the hero's square
.lk_onhero
	ld	a,(lk_x)
	ld	hl,lk_hx
	cp	(hl)
	ret	nz
	ld	a,(lk_y)
	ld	hl,lk_hy
	cp	(hl)
	ret

; z if x == hero.x || y == hero.y
.lk_inline
	ld	a,(lk_x)
	ld	hl,lk_hx
	cp	(hl)
	ret	z
	ld	a,(lk_y)
	ld	hl,lk_hy
	cp	(hl)
	ret

; nz if door_stop && !firstmove
.lk_ds
	ld	a,(_door_stop)
	or	a
	ret	z
	ld	a,(_firstmove)
	or	a
	jp	nz,lk_dsz
	inc	a
	ret
.lk_dsz
	xor	a
	ret

	SECTION	bss_compiler
.lk_wake	defs	1
.lk_pass	defs	1
.lk_hx		defs	1
.lk_hy		defs	1
.lk_x		defs	1
.lk_y		defs	1
.lk_blind	defs	1
.lk_pch		defs	1
.lk_pfl		defs	1
.lk_ch		defs	1
.lk_fl		defs	1
.lk_pp		defs	2
.lk_tp		defs	2

	GLOBAL	_look
	GLOBAL	_player
	GLOBAL	_oldpos
	GLOBAL	_oldrp
	GLOBAL	_running
	GLOBAL	_jump
	GLOBAL	_door_stop
	GLOBAL	_firstmove
	GLOBAL	_see_floor
	GLOBAL	_runch
	GLOBAL	_stdscr
	GLOBAL	_erase_lamp
	GLOBAL	_trip_ch
	GLOBAL	_wake_monster
	GLOBAL	_see_monst
	GLOBAL	_thing_of
	GLOBAL	_rnd
	GLOBAL	_wmove
	GLOBAL	_waddch
	GLOBAL	zpa
	GLOBAL	zstepok
