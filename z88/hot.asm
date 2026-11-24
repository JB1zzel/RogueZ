; hot.asm - routines run many times on every key, in assembler (z80asm,
; resident).  C versions of place_at/thing_of are in src/list.c (Linux).
;
;   PLACE *place_at(int y, int x)          &places[x * 24 + y]   (3-byte cells)
;   THING *thing_of(int i)                 i ? &things_pool[i - 1] : NULL (49 bytes)
;   void zb_show(unsigned char *scr, unsigned char rows)
;       scr is 8 rows of 94; for each row r with bit r set in rows (all rows
;       when zb_valid is 0) send the span that differs from zb_shown with
;       GN_Sop (cursor to it, characters, reverse on/off for bit 7), then
;       copy it into zb_shown
; sccz80 calls: arguments pushed left to right, the caller removes them.

        MODULE  hot
        INCLUDE "stdio.def"

        PUBLIC  _place_at, _thing_of, _zb_show
        EXTERN  _places, _things_pool, _zb_shown, _zb_valid, _zb_last, _zb_obuf
        EXTERN  _z_slo, _z_shi

        defc    COLS = 94
        defc    ROWS = 8

        SECTION code_resident

_place_at:                              ; [ret][x][y]
        ld      hl,2
        add     hl,sp
        ld      c,(hl)
        inc     hl
        ld      b,(hl)                  ; bc = x
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = y
        ld      h,b
        ld      l,c
pa:                                     ; hl = x, de = y -> hl = place
zpa:                                    ; (z88/zlook.asm)
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; x * 8
        ld      b,h
        ld      c,l
        add     hl,hl                   ; x * 16
        add     hl,bc                   ; x * 24
        add     hl,de                   ; + y
        ld      b,h
        ld      c,l
        add     hl,hl
        add     hl,bc                   ; * 3
        ld      de,_places
        add     hl,de
        ret

_thing_of:                              ; [ret][i]
        pop     bc
        pop     hl
        push    hl
        push    bc
        ld      a,h
        or      l
        ret     z                       ; 0 -> NULL
        dec     hl                      ; (i - 1) * 49 = *32 + *16 + *1
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; * 16
        ld      b,h
        ld      c,l
        add     hl,hl                   ; * 32
        add     hl,bc                   ; * 48
        add     hl,de                   ; * 49
        ld      de,_things_pool
        add     hl,de
        ret

_zb_show:                               ; [ret][rows][scr]
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        ld      (zs_rows),a
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      (_zb_last),de
        ld      (zs_s),de
        ld      hl,_zb_shown
        ld      (zs_h),hl
        push    ix
        xor     a
        ld      (zs_r),a
        ld      a,1
        ld      (zs_bit),a
zs_row:
        ld      a,(_zb_valid)
        or      a
        jr      z,zs_all                ; nothing valid: whole row
        ld      a,(zs_rows)
        ld      hl,zs_bit
        and     (hl)
        jp      z,zs_next               ; row not touched
        ; first differing column, from z_slo[r] (zcurses.c)
        ld      a,(zs_r)
        ld      e,a
        ld      d,0
        ld      hl,_z_slo
        add     hl,de
        ld      c,(hl)                  ; c = lo
        ld      hl,_z_shi
        add     hl,de
        ld      a,(hl)                  ; hi
        ld      (zs_hi),a
        sub     c
        jp      c,zs_next               ; nothing to look at
        inc     a
        ld      b,a
        ld      e,c                     ; d = 0
        ld      hl,(zs_h)
        add     hl,de
        push    hl
        ld      hl,(zs_s)
        add     hl,de
        pop     de                      ; hl = s + lo, de = h + lo
zs_f:   ld      a,(de)
        cp      (hl)
        jr      nz,zs_ffound
        inc     hl
        inc     de
        inc     c
        djnz    zs_f
        jp      zs_next                 ; row unchanged
zs_ffound:
        ld      a,c
        ld      (zs_f0),a
        ; last differing column, from z_shi[r] down (there is one)
        ld      a,(zs_hi)
        ld      c,a
        ld      e,a
        ld      d,0
        ld      hl,(zs_h)
        add     hl,de
        push    hl
        ld      hl,(zs_s)
        add     hl,de
        pop     de
        ex      de,hl                   ; de = s + hi, hl = h + hi
zs_l:   ld      a,(de)
        cp      (hl)
        jr      nz,zs_lfound
        dec     hl
        dec     de
        dec     c
        jr      zs_l
zs_lfound:
        ld      a,c
        ld      (zs_l0),a
        jr      zs_build
zs_all:
        xor     a
        ld      (zs_f0),a
        ld      a,(_z_lastc)            ; 93, or 79 with the mini map
        ld      (zs_l0),a
zs_build:
        ; VDU: 1,'3','@',32+f,32+r
        ld      de,_zb_obuf
        ld      a,1
        ld      (de),a
        inc     de
        ld      a,'3'
        ld      (de),a
        inc     de
        ld      a,'@'
        ld      (de),a
        inc     de
        ld      a,(zs_f0)
        add     a,32
        ld      (de),a
        inc     de
        ld      a,(zs_r)
        add     a,32
        ld      (de),a
        inc     de
        ; characters f..l
        ld      a,(zs_f0)
        ld      c,a
        ld      b,0
        ld      hl,(zs_s)
        add     hl,bc                   ; hl = s + f
        ld      a,(zs_l0)
        sub     c
        inc     a
        ld      b,a                     ; b = count
        ld      c,0                     ; c = reverse now (0 / $80)
zs_c:   ld      a,(hl)
        and     $80
        cp      c
        call    nz,zs_rev               ; reverse changes
        ld      a,(hl)
        and     $7F
        cp      32
        jr      nc,zs_ok
        cp      ZW_BOX
        jr      c,zs_sp
        jr      nz,zs_wall
        ld      a,'@'                   ; passage: 1,'2','?','@'
        push    af
        ld      a,'?'
        jr      zs_vdu
zs_wall:
        ld      a,(hl)
        and     $0F                     ; wall: 1,'2','*','@' + directions
        add     a,'@'
        push    af
        ld      a,'*'
zs_vdu: push    af
        ld      a,1
        ld      (de),a
        inc     de
        ld      a,'2'
        ld      (de),a
        inc     de
        pop     af
        ld      (de),a
        inc     de
        pop     af
        jr      zs_ok
zs_sp:  ld      a,' '
zs_ok:  ld      (de),a
        inc     de
        inc     hl
        djnz    zs_c
        ld      a,c
        or      a
        call    nz,zs_rev               ; leave reverse off
        xor     a
        ld      (de),a
        ld      hl,_zb_obuf
        call_oz(gn_sop)
        ; copy s[f..l] to h[f..l]
        ld      a,(zs_f0)
        ld      c,a
        ld      b,0
        ld      hl,(zs_s)
        add     hl,bc
        push    hl
        ld      hl,(zs_h)
        add     hl,bc
        ex      de,hl                   ; de = h + f
        pop     hl                      ; hl = s + f
        ld      a,(zs_l0)
        sub     c
        inc     a
        ld      c,a
        ld      b,0
        ldir
zs_next:
        ld      hl,(zs_s)
        ld      bc,COLS
        add     hl,bc
        ld      (zs_s),hl
        ld      hl,(zs_h)
        add     hl,bc
        ld      (zs_h),hl
        ld      hl,zs_bit
        sla     (hl)
        ld      hl,zs_r
        inc     (hl)
        ld      a,(hl)
        cp      ROWS
        jp      c,zs_row
        ld      a,1
        ld      (_zb_valid),a
        pop     ix
        ret

; toggle reverse: c = new state ($80 on / 0 off) after the call; writes
; 1,'2','+','R' or 1,'2','-','R' at de.  Keeps hl, b.
zs_rev: ld      a,c
        xor     $80
        ld      c,a
        ld      a,1
        ld      (de),a
        inc     de
        ld      a,'2'
        ld      (de),a
        inc     de
        ld      a,c
        or      a
        ld      a,'+'
        jr      nz,zs_r1
        ld      a,'-'
zs_r1:  ld      (de),a
        inc     de
        ld      a,'R'
        ld      (de),a
        inc     de
        ret

        SECTION bss_resident
zs_s:           defs    2
zs_h:           defs    2
zs_r:           defs    1
zs_bit:         defs    1
zs_rows:        defs    1
zs_f0:          defs    1
zs_l0:          defs    1
zs_hi:          defs    1

; ---------------------------------------------------------------------------
; do_daemons / do_fuses (src/daemon.c): each runs twice a turn over the
; 20-entry d_list, which is mostly empty.
;   struct delayed_action { int d_type; void (*d_func)(); int d_arg; int d_time; }
;   void do_daemons(int flag): call d_func(d_arg) where d_type == flag and
;                              d_time == DAEMON (-1)
;   void do_fuses(int flag):   where d_type == flag and d_time > 0:
;                              --d_time; at 0: d_type = EMPTY, call d_func(d_arg)
; d_func holds far-call stubs for banked functions (tools/farify.py).  A
; called function may change d_list, so everything is reloaded after a call.

        PUBLIC  _do_daemons, _do_fuses
        EXTERN  _d_list
        defc    MAXDAEMONS = 20

        SECTION code_resident
_do_daemons:
        xor     a
        jr      dd_start
_do_fuses:
        ld      a,1
dd_start:
        ld      (dd_mode),a             ; (code is in ROM: no patching)
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      (dd_flag),de
        ld      hl,_d_list
        ld      b,MAXDAEMONS
dd_loop:                                ; hl = entry, de = flag, b = count
        ld      a,(hl)
        cp      e
        jr      nz,dd_next
        inc     hl
        ld      a,(hl)
        dec     hl
        cp      d
        jr      nz,dd_next
        push    bc
        push    hl
        ld      a,(dd_mode)
        or      a
        jr      nz,dd_f
        call    dd_match                ; hl = entry
        jr      dd_back
dd_f:
        call    df_match
dd_back:
        pop     hl
        pop     bc
        ld      de,(dd_flag)
dd_next:
        ld      a,l
        add     a,8
        ld      l,a
        jr      nc,dd_nc
        inc     h
dd_nc:
        djnz    dd_loop
        ret

dd_match:                               ; daemon: d_time == -1 ?
        ld      de,6
        add     hl,de
        ld      a,(hl)
        inc     hl
        and     (hl)
        inc     a
        ret     nz
        ld      de,-5                   ; back to d_func
        add     hl,de
dd_call:                                ; hl -> d_func: (*d_func)(d_arg)
        ld      c,(hl)
        inc     hl
        ld      b,(hl)
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        push    de
        ld      h,b
        ld      l,c
        call    dd_jphl
        pop     de
        ret
dd_jphl:
        jp      (hl)

df_match:                               ; fuse: d_time > 0 ?
        push    hl
        ld      de,6
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = d_time
        bit     7,d
        jr      nz,df_no                ; negative
        ld      a,d
        or      e
        jr      z,df_no                 ; zero
        dec     de                      ; --d_time
        ld      (hl),d
        dec     hl
        ld      (hl),e
        ld      a,d
        or      e
        jr      nz,df_no
        pop     hl                      ; went off: d_type = EMPTY
        xor     a
        ld      (hl),a
        inc     hl
        ld      (hl),a
        inc     hl
        jr      dd_call
df_no:
        pop     hl
        ret

        SECTION bss_resident
dd_flag:        defs    2
dd_mode:        defs    1

; ---------------------------------------------------------------------------
; int rnd(int range)  (src/resident.c): range == 0 ? 0 : RN % range, with
;   RN = (seed = (seed*11109 + 13849) & 0x7fffffff) >> 16 & 0x7fff
; RN is never negative, so the remainder is RN % |range|.  Called a dozen
; times a turn; sccz80's version goes through l_long_mult and l_div.

        PUBLIC  _rnd
        EXTERN  _seed

        SECTION code_resident
_rnd:
        pop     bc
        pop     hl
        push    hl
        push    bc
        ld      a,h
        or      l
        ret     z
        bit     7,h                     ; |range|
        jr      z,rn_pos
        xor     a
        sub     l
        ld      l,a
        sbc     a,a
        sub     h
        ld      h,a
rn_pos:
        push    hl
        ld      hl,0                    ; de:hl = seed * 11109 ($2B65)
        ld      de,0
        ld      c,$2B
        call    rn_mul8
        ld      c,$65
        call    rn_mul8
        ld      bc,13849
        add     hl,bc
        jr      nc,rn_nc
        inc     de
rn_nc:
        res     7,d
        ld      (_seed),hl
        ld      (_seed+2),de
        ld      a,d                     ; dividend a:c = RN (15 bits)
        ld      c,e
        pop     de                      ; divisor
        ld      hl,0
        ld      b,16
rn_div:
        sla     c
        rla
        adc     hl,hl
        sbc     hl,de
        jr      nc,rn_dok
        add     hl,de
rn_dok:
        djnz    rn_div
        ret                             ; hl = remainder

rn_mul8:                                ; de:hl = de:hl*256 + seed*c, msb first
        ld      b,8
rn_m8:
        add     hl,hl
        rl      e
        rl      d
        sla     c
        jr      nc,rn_m8n
        push    bc
        ld      bc,(_seed)
        add     hl,bc
        ld      bc,(_seed+2)
        ex      de,hl
        adc     hl,bc
        ex      de,hl
        pop     bc
rn_m8n:
        djnz    rn_m8
        ret

; ---------------------------------------------------------------------------
; int dist(int y1, int x1, int y2, int x2)  (src/chase.c): squared distance.
; bool diag_ok(coord *sp, coord *ep)       (src/chase.c)
; int step_ok(int ch)                      (src/io.c)
; chase() calls these for each square round each moving monster.

        PUBLIC  _dist, _diag_ok, _step_ok, zpa, zstepok

        SECTION code_resident
_dist:                                  ; [ret][x2][y2][x1][y1]
        ld      hl,2
        add     hl,sp
        ld      c,(hl)
        inc     hl
        ld      b,(hl)                  ; bc = x2
        inc     hl
        push    bc                      ; x2
        ld      c,(hl)
        inc     hl
        ld      b,(hl)                  ; bc = y2
        inc     hl
        push    bc                      ; y2
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = x1
        inc     hl
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a                     ; hl = y1
        pop     bc                      ; y2
        push    de                      ; x1
        ex      de,hl                   ; de = y1
        ld      h,b
        ld      l,c
        or      a
        sbc     hl,de                   ; y2 - y1
        call    dsq
        pop     de                      ; x1
        pop     bc                      ; x2
        push    hl                      ; dy^2
        ld      h,b
        ld      l,c
        or      a
        sbc     hl,de                   ; x2 - x1
        call    dsq
        pop     de
        add     hl,de
        ret

dsq:                                    ; hl = hl * hl (low 16 bits)
        bit     7,h
        jr      z,dsq_p
        xor     a
        sub     l
        ld      l,a
        sbc     a,a
        sub     h
        ld      h,a
dsq_p:
        ld      a,h
        or      a
        jr      nz,dsq_slow
        bit     7,l
        jr      nz,dsq_slow
        add     hl,hl
        ld      de,dsq_tab
        add     hl,de
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ret
dsq_slow:
        ld      b,h
        ld      c,l
        ex      de,hl
        ld      hl,0
        ld      a,16
dsq_l:
        add     hl,hl
        ex      de,hl
        add     hl,hl
        ex      de,hl
        jr      nc,dsq_n
        add     hl,bc
dsq_n:
        dec     a
        jr      nz,dsq_l
        ret

_step_ok:                               ; [ret][ch]
        pop     bc
        pop     hl
        push    hl
        push    bc
        ld      a,h
        ld      h,0
        or      a
        ld      a,l
        ld      l,1
        ret     nz                      ; not a char: !isalpha() is true
        call    stepok_a
        ld      l,a
        ret

stepok_a:                               ; a = ch -> a = 1 ok / 0 not, z set if not
zstepok:                                ; (z88/zlook.asm)
        cp      ' '
        jr      z,so_no
        cp      '|'
        jr      z,so_no
        cp      '-'
        jr      z,so_no
        or      $20                     ; isalpha?
        sub     'a'
        cp      26
        jr      c,so_no
        ld      a,1
        or      a
        ret
so_no:
        xor     a
        ret

_diag_ok:                               ; [ret][ep][sp]
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = ep
        inc     hl
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a                     ; hl = sp
        ld      a,(hl)                  ; sp->x, sp->y: on the map
        ld      (dg_sx),a
        inc     hl
        inc     hl
        ld      a,(hl)
        ld      (dg_sy),a
        ex      de,hl                   ; hl = ep
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = ep->x
        inc     hl
        ld      a,d                     ; 0 <= x < NUMCOLS
        or      a
        jr      nz,dg_no
        ld      a,e
        cp      80
        jr      nc,dg_no
        ld      (dg_ex),a
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = ep->y
        ld      a,d                     ; 0 < y < NUMLINES - 1
        or      a
        jr      nz,dg_no
        ld      a,e
        or      a
        jr      z,dg_no
        cp      23
        jr      nc,dg_no
        ld      (dg_ey),a
        ld      hl,dg_sy                ; ep->y == sp->y ?
        cp      (hl)
        jr      z,dg_yes
        ld      a,(dg_ex)               ; ep->x == sp->x ?
        ld      hl,dg_sx
        cp      (hl)
        jr      z,dg_yes
        ld      a,(dg_sx)               ; step_ok(chat(ep->y, sp->x))
        ld      l,a
        ld      h,0
        ld      a,(dg_ey)
        ld      e,a
        ld      d,h
        call    pa
        ld      a,(hl)
        call    stepok_a
        jr      z,dg_no
        ld      a,(dg_ex)               ; && step_ok(chat(sp->y, ep->x))
        ld      l,a
        ld      h,0
        ld      a,(dg_sy)
        ld      e,a
        ld      d,h
        call    pa
        ld      a,(hl)
        call    stepok_a
        ld      l,a
        ld      h,0
        ret
dg_yes:
        ld      hl,1
        ret
dg_no:
        ld      hl,0
        ret

        SECTION rodata_resident
dsq_tab:
        defw    0, 1, 4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144, 169, 196, 225, 256, 289, 324, 361, 400, 441, 484, 529, 576, 625, 676, 729, 784, 841, 900, 961, 1024, 1089, 1156, 1225, 1296, 1369, 1444, 1521, 1600, 1681, 1764, 1849, 1936, 2025, 2116, 2209, 2304, 2401, 2500, 2601, 2704, 2809, 2916, 3025, 3136, 3249, 3364, 3481, 3600, 3721, 3844, 3969, 4096, 4225, 4356, 4489, 4624, 4761, 4900, 5041, 5184, 5329, 5476, 5625, 5776, 5929, 6084, 6241, 6400, 6561, 6724, 6889, 7056, 7225, 7396, 7569, 7744, 7921, 8100, 8281, 8464, 8649, 8836, 9025, 9216, 9409, 9604, 9801, 10000, 10201, 10404, 10609, 10816, 11025, 11236, 11449, 11664, 11881, 12100, 12321, 12544, 12769, 12996, 13225, 13456, 13689, 13924, 14161, 14400, 14641, 14884, 15129, 15376, 15625, 15876, 16129

        SECTION bss_resident
dg_sx:  defs    1
dg_sy:  defs    1
dg_ex:  defs    1
dg_ey:  defs    1

; ---------------------------------------------------------------------------
; Curses primitives (src/zcurses.c), called for every square drawn.
;   WINDOW: _maxy 0, _maxx 2, _begy 4, _begx 6, _cury 8, _curx 10,
;           _stride 12, _buf 14, _row 16, _attr 18
; Sizes and positions are below 256.
; int wmove(WINDOW *w, int y, int x)
; chtype winch(WINDOW *w)
; int waddch(WINDOW *w, chtype c): printable characters here, the rest in
;     z_waddch_slow (C)

        PUBLIC  _wmove, _winch, _waddch
        EXTERN  _z_waddch_slow, _stdscr, _sdirty, _sdlo, _sdhi

        SECTION code_resident
_wmove:                                 ; [ret][x][y][w]
        ld      hl,2
        add     hl,sp
        ld      c,(hl)
        inc     hl
        ld      b,(hl)                  ; bc = x
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = y
        inc     hl
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a                     ; hl = w
        ld      a,d
        or      b
        jr      nz,wm_err               ; negative, or past any window
        ld      a,e
        cp      (hl)                    ; y >= _maxy ?
        jr      nc,wm_err
        inc     hl
        inc     hl
        ld      a,c
        cp      (hl)                    ; x >= _maxx ?
        jr      nc,wm_err
        ld      a,e
        ld      de,6
        add     hl,de                   ; _cury
        ld      (hl),a
        inc     hl
        ld      (hl),0
        inc     hl
        ld      (hl),c
        inc     hl
        ld      (hl),0
        ld      hl,0
        ret
wm_err:
        ld      hl,-1
        ret

_winch:                                 ; [ret][w]
        pop     bc
        pop     hl
        push    hl
        push    bc
        ld      de,8
        add     hl,de
        ld      c,(hl)                  ; c = _cury
        inc     hl
        inc     hl
        ld      a,(hl)                  ; a = _curx
        ld      de,6
        add     hl,de                   ; _row
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        ld      b,0
        add     hl,bc
        add     hl,bc
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = _row[_cury]
        ld      l,a
        ld      h,0
        add     hl,de
        ld      a,(hl)
        and     $7f
        ld      l,a
        ld      h,0
        ret

_waddch:                                ; [ret][c][w]
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; c = chtype
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = w
        ld      a,c
        and     $7f
        cp      32
        jp      c,_z_waddch_slow        ; same arguments
        cp      127
        jp      z,_z_waddch_slow
        ld      b,a
        ld      a,c
        and     $80
        or      b
        ld      hl,18
        add     hl,de
        or      (hl)                    ; ch | standout | _attr
        ld      (wa_ch),a
        ld      hl,8
        add     hl,de
        ld      c,(hl)                  ; c = _cury
        inc     hl
        inc     hl
        ld      b,(hl)                  ; b = _curx
        push    bc
        ld      hl,16
        add     hl,de
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a                     ; hl = _row
        ld      b,0
        add     hl,bc
        add     hl,bc
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a                     ; hl = _row[_cury]
        pop     bc
        push    bc
        ld      c,b
        ld      b,0
        add     hl,bc                   ; + _curx
        ld      a,(wa_ch)
        pop     bc                      ; c = _cury, b = _curx
        cp      (hl)
        jr      z,wa_ns                 ; no change: the row stays clean
        push    bc
        ld      c,(hl)                  ; old character
        ld      (hl),a
        ld      b,1                     ; ZD_ROW
        call    wa_vw                   ; new one a '|' or door?
        jr      z,wa_w
        ld      a,c
        call    wa_vw
        jr      nz,wa_nw
wa_w:   ld      b,3                     ; ZD_ROW | ZD_WALL
wa_nw:  ld      a,b
        pop     bc
        ld      hl,(_stdscr)            ; stdscr: mark the row
        or      a                       ; (a is never 0: carry clear)
        sbc     hl,de
        jr      nz,wa_ns
        push    bc
        push    de
        ld      e,c
        ld      d,0                     ; de = row
        ld      hl,_sdirty
        add     hl,de
        or      (hl)
        ld      (hl),a
        ld      a,b                     ; column: widen sdlo..sdhi
        ld      hl,_sdlo
        add     hl,de
        cp      (hl)
        jr      nc,wa_lo
        ld      (hl),a
wa_lo:  ld      hl,_sdhi
        add     hl,de
        cp      (hl)
        jr      c,wa_hi
        ld      (hl),a
wa_hi:  pop     de
        pop     bc
wa_ns:
        inc     b                       ; ++_curx >= _maxx ?
        ld      hl,2
        add     hl,de
        ld      a,b
        cp      (hl)
        jr      nc,wa_wrap
        ld      hl,10
        add     hl,de
        ld      (hl),b
        ld      hl,0
        ret
wa_wrap:
        ld      a,(de)                  ; _cury < _maxy - 1 ?
        dec     a
        ld      l,a
        ld      a,c
        cp      l
        jr      nc,wa_last
        inc     c                       ; next line
        ld      hl,8
        add     hl,de
        ld      (hl),c
        inc     hl
        inc     hl
        ld      (hl),0
        ld      hl,0
        ret
wa_last:
        ld      hl,2                    ; stay on the last column
        add     hl,de
        ld      a,(hl)
        dec     a
        ld      hl,10
        add     hl,de
        ld      (hl),a
        ld      hl,0
        ret

wa_vw:                                  ; z if a (no attribute bit) is '|' or '+'
        and     $7F
        cp      '|'
        ret     z
        cp      '+'
        ret

        SECTION bss_resident
wa_ch:  defs    1

; ---------------------------------------------------------------------------
; void z_walls(unsigned char *d, const unsigned char *src,
;              const unsigned char *up, const unsigned char *dn, int lo, int hi)
; (C version and rules in src/zcurses.c): copy columns lo..hi of map row
; src to d, '#' -> ZW_PASSAGE, '-' and '|' -> ZW_BOX | directions.

        PUBLIC  _z_walls
        defc    ZW_BOX = $10
        defc    ZW_R = $01              ; as in src/curses.h
        defc    ZW_D = $02
        defc    ZW_L = $04
        defc    ZW_U = $08
        defc    ZMAP_COLS = 80

        SECTION code_resident
_z_walls:                               ; [ret][hi][lo][dn][up][src][d]
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        ld      (zw_hi),a
        inc     hl
        inc     hl
        ld      c,(hl)                  ; c = lo
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      (zw_dn),de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      (zw_up),de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      (zw_d0),de              ; src
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a                     ; hl = d
        ld      b,0
        add     hl,bc
        ex      de,hl                   ; de = d + lo
        ld      hl,(zw_d0)
        add     hl,bc                   ; hl = src + lo
        ld      a,(zw_hi)
        sub     c
        inc     a
        ld      b,a                     ; columns
zw_l:
        ld      a,(hl)
        cp      '.'
        jr      z,zw_put0
        cp      ' '
        jr      z,zw_put0
        cp      '#'
        jr      z,zw_pas
        cp      '|'
        jr      z,zw_bar
        cp      '-'
        jr      z,zw_dash
zw_put0:
        ld      (de),a
        inc     hl
        inc     de
        djnz    zw_l
        ret
zw_pas:
        ld      a,ZW_BOX                ; ZW_PASSAGE
        jr      zw_put0
zw_bar:
        ld      a,ZW_BOX | ZW_U | ZW_D
        jr      zw_put0

zw_dash:
        push    bc
        push    de
        push    hl
        ld      de,(zw_d0)
        or      a
        sbc     hl,de
        ex      de,hl                   ; de = column
        ld      c,0                     ; c = directions
        ld      hl,(zw_up)
        add     hl,de
        ld      a,(hl)
        ld      b,-1                    ; (the row above)
        call    zw_isv
        jr      nz,zw_1
        ld      c,ZW_U
zw_1:
        ld      hl,(zw_dn)
        add     hl,de
        ld      a,(hl)
        ld      b,1                     ; (the row below)
        call    zw_isv
        jr      nz,zw_2
        ld      a,c
        or      ZW_D
        ld      c,a
zw_2:
        pop     hl                      ; hl = src cell
        ld      a,c
        or      a
        ld      a,ZW_BOX | ZW_L | ZW_R  ; no corner: a line
        jr      z,zw_put
        ld      a,e                     ; column 0: nothing to the left
        or      a
        jr      z,zw_3
        dec     hl
        ld      a,(hl)
        inc     hl
        ld      b,-1                    ; (the column to the left)
        call    zw_ish
        jr      nz,zw_3
        ld      a,c
        or      ZW_L
        ld      c,a
zw_3:
        ld      a,e                     ; last column: nothing to the right
        cp      ZMAP_COLS - 1
        jr      z,zw_4
        inc     hl
        ld      a,(hl)
        dec     hl
        ld      b,1                     ; (the column to the right)
        call    zw_ish
        jr      nz,zw_4
        ld      a,c
        or      ZW_R
        ld      c,a
zw_4:
        ld      a,c
        and     ZW_L | ZW_R
        ld      a,c
        jr      nz,zw_5
        or      ZW_L | ZW_R
zw_5:
        or      ZW_BOX
zw_put:
        pop     de
        pop     bc
        jr      zw_put0

zw_isv:                                 ; z if a is '|' or a door, or the
        cp      '|'                     ; hero or a monster standing on a
        ret     z                       ; door (b: the row, -1 or 1)
        cp      '+'
        ret     z
        push    hl
        ld      h,b
        ld      l,0
        jr      zw_who
zw_ish:                                 ; z if a is '-' or a door, or someone
        cp      '-'                     ; on a door (b: the column, -1 or 1)
        ret     z
        cp      '+'
        ret     z
        push    hl
        ld      h,0
        ld      l,b
zw_who:                                 ; a letter or '@' there (h, l: the
        cp      '@'                     ; row and column from this cell):
        jr      c,zw_no                 ; is it on a door? (else the corner
        cp      'Z' + 1                 ; next to a doorway drew straight)
        jr      nc,zw_no
        push    de
        push    bc
        ld      a,(mr_wrow)
        add     a,h
        ld      c,a
        ld      b,0
        push    bc                      ; y
        ld      a,e
        add     a,l
        ld      l,a
        ld      h,0
        push    hl                      ; x
        call    far_z_isdoor            ; (misc.c: chat(y, x) == DOOR)
        pop     bc
        pop     bc
        ld      a,l
        pop     bc
        pop     de
        pop     hl
        dec     a                       ; z: a door
        ret
zw_no:  pop     hl
        or      1                       ; nz (a may be 0: no row there)
        ret

        SECTION bss_resident
zw_d0:  defs    2
zw_up:  defs    2
zw_dn:  defs    2
zw_hi:  defs    1

; ---------------------------------------------------------------------------
; unsigned char z_maprows(WINDOW *w, int top, int full)  (C version and
; comments in src/zmap.c): compose the message row and the 7 map rows,
; only the columns that changed; returns the rows touched.

        PUBLIC  _z_maprows
        EXTERN  _screen, _zblank, far_z_isdoor
        defc    MR_COLS = 94            ; ZSCR_COLS

        SECTION code_resident
_z_maprows:                             ; [ret][full][top][w]
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        ld      (mr_full),a
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      (mr_top),de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = w
        ld      hl,(_stdscr)
        or      a
        sbc     hl,de
        ld      a,0
        jr      nz,mr_ns
        inc     a
mr_ns:  ld      (mr_isstd),a
        ex      de,hl
        ld      a,(hl)                  ; _maxy
        ld      (mr_maxy),a
        ld      de,16
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      (mr_rows),de            ; _row
        ld      hl,_screen
        ld      (mr_scr),hl
        xor     a
        ld      (mr_mask),a
        ld      (mr_r),a
        inc     a
        ld      (mr_bit),a
mr_loop:
        ld      hl,0                    ; wrow = r ? top + r - 1 : 0
        ld      a,(mr_r)
        or      a
        jr      z,mr_w0
        ld      hl,(mr_top)
        ld      e,a
        ld      d,0
        add     hl,de
        dec     hl
mr_w0:  xor     a                       ; valid: 0 <= wrow < 24
        ld      (mr_valid),a
        ld      a,h
        or      a
        jr      nz,mr_v
        ld      a,l
        cp      24
        jr      nc,mr_v
        ld      (mr_wrow),a
        ld      a,1
        ld      (mr_valid),a
mr_v:
        ld      a,(mr_r)
        ld      e,a
        ld      d,0
        ld      hl,_z_slo
        add     hl,de
        ld      (hl),255
        ld      hl,_z_shi
        add     hl,de
        ld      (hl),0
        xor     a                       ; lo = 0, hi = 79
        ld      (mr_lo),a
        ld      a,ZMAP_COLS - 1
        ld      (mr_hi),a
        ld      a,(mr_full)
        or      a
        jr      nz,mr_do
        ld      a,(mr_valid)
        or      a
        jr      z,mr_do
        ld      a,255                   ; lo = 255, hi = 0
        ld      (mr_lo),a
        xor     a
        ld      (mr_hi),a
        ld      a,(mr_wrow)
        ld      e,a
        ld      hl,_sdirty
        add     hl,de
        ld      a,(hl)
        or      a
        jr      z,mr_nb
        ld      hl,_sdlo
        add     hl,de
        ld      a,(hl)
        ld      (mr_lo),a
        ld      hl,_sdhi
        add     hl,de
        ld      a,(hl)
        ld      (mr_hi),a
        ld      a,(mr_r)                ; map rows: one more each side
        or      a
        jr      z,mr_nb
        ld      a,(mr_lo)
        or      a
        jr      z,mr_l0
        dec     a
        ld      (mr_lo),a
mr_l0:  ld      a,(mr_hi)
        cp      ZMAP_COLS - 1
        jr      nc,mr_nb
        inc     a
        ld      (mr_hi),a
mr_nb:
        ld      a,(mr_r)
        or      a
        jr      z,mr_chk
        ld      a,(mr_wrow)             ; a wall came or went above
        cp      2
        jr      c,mr_nab
        dec     a
        call    mr_union
mr_nab: ld      a,(mr_wrow)             ; ... or below
        cp      23
        jr      nc,mr_chk
        inc     a
        call    mr_union
mr_chk:
        ld      a,(mr_lo)               ; nothing to do?
        ld      b,a
        ld      a,(mr_hi)
        cp      b
        jp      c,mr_next
        cp      ZMAP_COLS
        jr      c,mr_do
        ld      a,ZMAP_COLS - 1
        ld      (mr_hi),a
mr_do:
        ld      a,(mr_lo)
        ld      c,a
        ld      b,0
        ld      hl,(mr_scr)
        add     hl,bc
        ex      de,hl                   ; de = screen[r] + lo
        ld      a,(mr_hi)
        sub     c
        ld      c,a                     ; bc = n - 1
        ld      a,(mr_valid)
        or      a
        jr      z,mr_blank
        ld      a,(mr_maxy)
        ld      l,a
        ld      a,(mr_wrow)
        cp      l
        jr      nc,mr_blank
        ld      a,(mr_r)                ; walls: map rows of stdscr from 1
        or      a
        jr      z,mr_copy
        ld      a,(mr_isstd)
        or      a
        jr      z,mr_copy
        ld      a,(mr_wrow)
        or      a
        jr      z,mr_copy
        ; z_walls(screen[r], row[wrow], up, dn, lo, hi)
        ld      hl,(mr_scr)
        push    hl
        ld      a,(mr_wrow)
        call    mr_row
        push    hl
        ld      a,(mr_wrow)
        ld      hl,_zblank
        cp      2
        jr      c,mr_up
        dec     a
        call    mr_row
mr_up:  push    hl
        ld      a,(mr_maxy)
        ld      l,a
        ld      a,(mr_wrow)
        inc     a
        cp      l
        ld      hl,_zblank
        jr      nc,mr_dn
        call    mr_row
mr_dn:  push    hl
        ld      a,(mr_lo)
        ld      l,a
        ld      h,0
        push    hl
        ld      a,(mr_hi)
        ld      l,a
        push    hl
        call    _z_walls
        ld      hl,12
        add     hl,sp
        ld      sp,hl
        jr      mr_set
mr_copy:
        push    de
        push    bc
        ld      a,(mr_wrow)
        call    mr_row
        ld      a,(mr_lo)
        ld      c,a
        ld      b,0
        add     hl,bc                   ; hl = row[wrow] + lo
        pop     bc
        pop     de
        inc     bc
        ldir
        jr      mr_set
mr_blank:
        ex      de,hl
        ld      (hl),' '
        ld      a,b
        or      c
        jr      z,mr_set
        ld      d,h
        ld      e,l
        inc     de
        ldir
mr_set:
        ld      a,(mr_r)
        ld      e,a
        ld      d,0
        ld      hl,_z_slo
        add     hl,de
        ld      a,(mr_lo)
        ld      (hl),a
        ld      hl,_z_shi
        add     hl,de
        ld      a,(mr_hi)
        ld      (hl),a
        ld      a,(mr_bit)
        ld      hl,mr_mask
        or      (hl)
        ld      (hl),a
mr_next:
        ld      hl,(mr_scr)
        ld      de,MR_COLS
        add     hl,de
        ld      (mr_scr),hl
        ld      hl,mr_bit
        sla     (hl)
        ld      hl,mr_r
        inc     (hl)
        ld      a,(hl)
        cp      8
        jp      c,mr_loop
        ld      a,(mr_mask)
        ld      l,a
        ld      h,0
        ret

mr_row:                                 ; hl = _row[a]
        ld      hl,(mr_rows)
        ld      e,a
        ld      d,0
        add     hl,de
        add     hl,de
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ret

mr_union:                               ; row a: if sdirty & ZD_WALL, widen lo..hi
        ld      e,a
        ld      d,0
        ld      hl,_sdirty
        add     hl,de
        bit     1,(hl)
        ret     z
        ld      hl,_sdlo
        add     hl,de
        ld      a,(mr_lo)
        cp      (hl)
        jr      c,mr_u1
        ld      a,(hl)
        ld      (mr_lo),a
mr_u1:  ld      hl,_sdhi
        add     hl,de
        ld      a,(mr_hi)
        cp      (hl)
        ret     nc
        ld      a,(hl)
        ld      (mr_hi),a
        ret

        SECTION bss_resident
mr_full:  defs  1
mr_top:   defs  2
mr_isstd: defs  1
mr_maxy:  defs  1
mr_rows:  defs  2
mr_scr:   defs  2
mr_mask:  defs  1
mr_r:     defs  1
mr_bit:   defs  1
mr_valid: defs  1
mr_wrow:  defs  1
mr_lo:    defs  1
mr_hi:    defs  1


        SECTION bss_resident
        PUBLIC  _z_lastc
_z_lastc:       defs    1               ; zb_show's last column: 93, or 79
                                        ; with the mini map (zmap.c)
