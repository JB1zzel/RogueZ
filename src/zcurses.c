/*
 * zcurses.c - the curses subset Rogue uses, on in-memory buffers, plus the
 * composer that turns them into the Z88's 8 x 94 screen.  No OS calls here:
 * output and keys go through the backend (zb_*).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "curses.h"

WINDOW *stdscr, *curscr;
int LINES = ZSCR_ROWS, COLS = ZSCR_COLS;
int z_mapmode = 1;

unsigned char screen[ZSCR_ROWS][ZSCR_COLS];   /* also zmap.c */
unsigned char zblank[ZMAP_COLS];           /* no row: no walls in it */
char z_panel[ZSCR_ROWS][ZPANEL_W + 1];     /* status panel (z_status, zcold.c) */
/*
 * Only what changed is composed and compared: rows of stdscr written since
 * the last refresh (sdirty), and the panel (z_pdirty).  Anything else - another
 * window shown, a different viewport - forces a full refresh (full).
 */
unsigned char sdirty[24];               /* also z88/hot.asm */
unsigned char sdlo[24], sdhi[24];       /* changed columns of each row (min,
                                         * max; reset to 255, 0) - hot.asm */
unsigned char z_slo[ZSCR_ROWS], z_shi[ZSCR_ROWS];   /* zb_show: columns of
                                         * each screen row to compare */
#define ZD_ROW  1                       /* sdirty: the row changed */
#define ZD_WALL 2                       /* ... and a '|' or door came or went:
                                         * the rows beside it are reshaped */
#define ZD_VWALL(c)  (((c) & 0x7F) == '|' || ((c) & 0x7F) == '+')
unsigned char z_pdirty = 0xFF;      /* panel rows to redraw, bit per row */
char full = 1;                          /* also zmap.c */
int last_top = -1;
char z_panel_note[ZPANEL_W + 1];      /* panel row 7: e.g. "Map 2/3" */


#ifndef __Z88__	/* Z88: wmove, winch and waddch's common case in z88/hot.asm */
int
wmove(WINDOW *w, int y, int x)
{
    if (y < 0 || y >= w->_maxy || x < 0 || x >= w->_maxx)
        return ERR;
    w->_cury = y;
    w->_curx = x;
    return OK;
}
#endif

#ifdef __Z88__
#define waddch_c z_waddch_slow              /* control characters, newline */
#else
#define waddch_c waddch
#endif
int
waddch_c(WINDOW *w, chtype c)
{
    unsigned char ch = c & A_CHARTEXT;

    if (ch == '\n')
    {
        wclrtoeol(w);
        w->_curx = 0;
        if (w->_cury < w->_maxy - 1)
            w->_cury++;
        return OK;
    }
    if (ch == '\r')
    {
        w->_curx = 0;
        return OK;
    }
    if (ch == '\t')
    {
        do
            waddch(w, ' ');
        while (w->_curx & 7);
        return OK;
    }
    if (ch < ' ' || ch == 127)
    {
        waddch(w, '^');
        return waddch(w, ch == 127 ? '?' : ch + '@');
    }
    c = ch | (c & A_STANDOUT) | w->_attr;
    if (w->_row[w->_cury][w->_curx] != c)
    {                                   /* rewriting the same: still clean */
        if (w == stdscr)
        {
            sdirty[w->_cury] |= ZD_VWALL(w->_row[w->_cury][w->_curx])
                                || ZD_VWALL(c) ? ZD_ROW | ZD_WALL : ZD_ROW;
            if (w->_curx < sdlo[w->_cury])
                sdlo[w->_cury] = (unsigned char) w->_curx;
            if (w->_curx > sdhi[w->_cury])
                sdhi[w->_cury] = (unsigned char) w->_curx;
        }
        w->_row[w->_cury][w->_curx] = c;
    }
    if (++w->_curx >= w->_maxx)
    {
        if (w->_cury < w->_maxy - 1)
        {
            w->_curx = 0;
            w->_cury++;
        }
        else
            w->_curx = w->_maxx - 1;
    }
    return OK;
}

int
waddstr(WINDOW *w, const char *s)
{
    while (*s)
        waddch(w, (unsigned char) *s++);
    return OK;
}

char z_pbuf[160];                       /* printw family (curses.h) */

int
z_mvwaddstr(WINDOW *w, int y, int x, const char *s)
{
    if (wmove(w, y, x) == ERR)
        return ERR;
    return waddstr(w, s);
}

#ifndef __Z88__
chtype
winch(WINDOW *w)
{
    return w->_row[w->_cury][w->_curx] & A_CHARTEXT;
}
#endif

int
werase(WINDOW *w)
{
    int y;

    for (y = 0; y < w->_maxy; y++)
        memset(w->_row[y], ' ', (size_t) w->_maxx);
    w->_cury = w->_curx = 0;
    if (w == stdscr)
        full = 1;
    return OK;
}

int
wclear(WINDOW *w)
{
    return werase(w);
}

int
wclrtoeol(WINDOW *w)
{
    memset(w->_row[w->_cury] + w->_curx, ' ',
           (size_t) (w->_maxx - w->_curx));
    if (w == stdscr)
    {
        sdirty[w->_cury] = ZD_ROW | ZD_WALL;
        if (w->_curx < sdlo[w->_cury])
            sdlo[w->_cury] = (unsigned char) w->_curx;
        sdhi[w->_cury] = (unsigned char) (w->_maxx - 1);
    }
    return OK;
}

int
wstandout(WINDOW *w)
{
    w->_attr = A_STANDOUT;
    return OK;
}

int
wstandend(WINDOW *w)
{
    w->_attr = 0;
    return OK;
}

#ifndef __Z88__
int
wgetch(WINDOW *w)
{
    (void) w;
    return zb_getkey();
}
#endif

/*
 * Status panel: 13 columns down the right-hand side.
 */
static void
copy_row(int srow, WINDOW *w, int wrow, int scol, int ncols)
{
    if (wrow < 0 || wrow >= w->_maxy)
        memset(&screen[srow][scol], ' ', (size_t) ncols);
    else
        memcpy(&screen[srow][scol], w->_row[wrow], (size_t) ncols);
}

#ifndef __Z88__	/* Z88: in z88/hot.asm */
/*
 * Copy columns lo..hi of map row src (stdscr; up, dn: the rows above and
 * below it) to d, drawing walls and passages: '#' becomes ZW_PASSAGE, '|' a
 * vertical line, '-' a horizontal line or, when a '|' or door is above or
 * below it, a corner joining the '-' or door beside it.
 */
void
z_walls(unsigned char *d, const unsigned char *src, const unsigned char *up,
        const unsigned char *dn, int lo, int hi)
{
    unsigned char c, h, v, prev, next;
    int i;

    for (i = lo; i <= hi; i++)
    {
        c = src[i];
        if (c == '#')
            c = ZW_PASSAGE;
        else if (c == '|')
            c = ZW_BOX | ZW_U | ZW_D;
        else if (c == '-')
        {
            v = 0;
            if (up[i] == '|' || up[i] == '+')
                v |= ZW_U;
            if (dn[i] == '|' || dn[i] == '+')
                v |= ZW_D;
            h = 0;
            if (v)
            {
                prev = i > 0 ? src[i - 1] : ' ';
                next = i + 1 < ZMAP_COLS ? src[i + 1] : ' ';
                if (prev == '-' || prev == '+')
                    h |= ZW_L;
                if (next == '-' || next == '+')
                    h |= ZW_R;
            }
            if (!h)
                h = ZW_L | ZW_R;
            c = ZW_BOX | h | v;
        }
        d[i] = c;
    }
}
#endif

/* zb_show is to compare whole rows */
void
z_span_all(void)
{
    memset(z_slo, 0, sizeof z_slo);
    memset(z_shi, ZSCR_COLS - 1, sizeof z_shi);
}


int
wrefresh(WINDOW *w)
{
    int r, n;

    if (w == stdscr)
    {
        if (z_mapmode)
        {
            z_compose_map(stdscr, z_view_top());
            return OK;
        }
        memset(screen, ' ', sizeof screen);
        for (r = 0; r < ZSCR_ROWS; r++)
            copy_row(r, stdscr, r, 0, ZMAP_COLS);
    }
    else
    {
        /* a window over whatever is on the screen, clipped */
        for (r = 0; r < w->_maxy; r++)
        {
            int sy = w->_begy + r;

            if (sy < 0 || sy >= ZSCR_ROWS)
                continue;
            n = w->_maxx;
            if (w->_begx + n > ZSCR_COLS)
                n = ZSCR_COLS - w->_begx;
            if (n > 0)
                memcpy(&screen[sy][w->_begx], w->_row[r], (size_t) n);
        }
    }
    full = 1;                   /* not the map view: redo it all next time */
    z_span_all();
    zb_show(screen, 0xFF);
    return OK;
}
