/*
 * zmap.c - compose the map screen (message row, 7 map rows, status panel)
 * from stdscr.  Split from zcurses.c: on the Z88 it is banked (one far call
 * a refresh); zcurses.c's hot primitives stay in the fixed bank.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "curses.h"

#ifdef __Z88__
#define ZSTATIC static                  /* sccz80: no stack locals (rogue.h) */
#else
#define ZSTATIC
#endif
#define ZD_ROW  1                       /* as in zcurses.c */
#define ZD_WALL 2

extern unsigned char screen[ZSCR_ROWS][ZSCR_COLS], zblank[ZMAP_COLS];
extern unsigned char sdirty[24], sdlo[24], sdhi[24];
extern unsigned char z_slo[ZSCR_ROWS], z_shi[ZSCR_ROWS];
extern char full;
extern int last_top;
extern unsigned char z_pdirty;
extern char z_panel[ZSCR_ROWS][ZPANEL_W + 1];
void z_span_all(void);

#ifndef __Z88__	/* Z88: in z88/hot.asm */
/*
 * The message row and the 7 map rows of the screen, from stdscr rows 0 and
 * top..top+6: only the columns that need it.  Returns the rows (bits) it
 * touched; z_slo/z_shi tell zb_show which columns.
 */
unsigned char
z_maprows(WINDOW *w, int top, int full)
{
    int r, wrow, lo, hi;
    unsigned char mask = 0;

    for (r = 0; r < ZSCR_ROWS; r++)
    {
        wrow = r ? top + r - 1 : 0;
        z_slo[r] = 255;
        z_shi[r] = 0;
        lo = 0;
        hi = ZMAP_COLS - 1;
        if (!full && wrow >= 0 && wrow < 24)
        {
            /* the columns that changed (and the ones beside them: a corner
             * joins its neighbours), and under or over a '|' or door that
             * came or went in the rows beside (corners again) */
            lo = 255;
            hi = 0;
            if (sdirty[wrow])
            {
                lo = sdlo[wrow];
                hi = sdhi[wrow];
                if (r && lo > 0)
                    lo--;
                if (r && hi < ZMAP_COLS - 1)
                    hi++;
            }
            if (r && wrow >= 2 && (sdirty[wrow - 1] & ZD_WALL))
            {
                if (sdlo[wrow - 1] < lo)
                    lo = sdlo[wrow - 1];
                if (sdhi[wrow - 1] > hi)
                    hi = sdhi[wrow - 1];
            }
            if (r && wrow < 23 && (sdirty[wrow + 1] & ZD_WALL))
            {
                if (sdlo[wrow + 1] < lo)
                    lo = sdlo[wrow + 1];
                if (sdhi[wrow + 1] > hi)
                    hi = sdhi[wrow + 1];
            }
            if (lo > hi)
                continue;
            if (hi > ZMAP_COLS - 1)
                hi = ZMAP_COLS - 1;
        }
        if (wrow < 0 || wrow >= w->_maxy)
            memset(&screen[r][lo], ' ', (size_t) (hi - lo + 1));
        else if (r && w == stdscr && wrow >= 1)
            z_walls(screen[r], w->_row[wrow],
                    wrow >= 2 ? w->_row[wrow - 1] : zblank,
                    wrow + 1 < w->_maxy ? w->_row[wrow + 1] : zblank, lo, hi);
        else
            memcpy(&screen[r][lo], w->_row[wrow] + lo, (size_t) (hi - lo + 1));
        z_slo[r] = (unsigned char) lo;
        z_shi[r] = (unsigned char) hi;
        mask |= (unsigned char) (1 << r);
    }
    return mask;
}
#endif

/*
 * Map screen: message row, 7 rows of the level from 'top', status panel.
 * Composes only rows that changed, unless w is not stdscr, the viewport
 * moved, or something else was on the screen (full).
 */
void
z_compose_map(WINDOW *w_, int top_)
{
    static char note_shown;
    ZSTATIC WINDOW *w;
    ZSTATIC int top, r, n;
    ZSTATIC unsigned char mask;

    w = w_;
    top = top_;
    mask = 0;

    if (w != stdscr || top != last_top || z_panel_note[0] || note_shown)
        full = 1;
    if (full)
    {
        memset(screen, ' ', sizeof screen);
        memset(sdirty, 1, sizeof sdirty);
        z_pdirty = 0xFF;
    }
    mask = z_maprows(w, top, full);
    if (z_pdirty)
    {
        for (r = 0; r < ZSCR_ROWS; r++)
        {
            if (!(z_pdirty & (unsigned char) (1 << r)))
                continue;
            memset(&screen[r][ZPANEL_COL], ' ', ZPANEL_W);
            n = (int) strlen(z_panel[r]);
            memcpy(&screen[r][ZPANEL_COL], z_panel[r], (size_t) n);
            if (z_slo[r] > ZPANEL_COL)
                z_slo[r] = ZPANEL_COL;
            z_shi[r] = ZSCR_COLS - 1;
        }
        mask |= z_pdirty;
    }
#ifndef __Z88__
    if (w == stdscr && getenv("ZWALLCHECK"))
    {                                   /* test: incremental == from scratch */
        unsigned char t[ZMAP_COLS];
        int wrow;

        for (r = 1; r < ZSCR_ROWS; r++)
        {
            wrow = top + r - 1;
            if (wrow < 1 || wrow >= w->_maxy)
                continue;
            z_walls(t, w->_row[wrow], wrow >= 2 ? w->_row[wrow - 1] : zblank,
                    wrow + 1 < w->_maxy ? w->_row[wrow + 1] : zblank,
                    0, ZMAP_COLS - 1);
            if (memcmp(t, screen[r], ZMAP_COLS) != 0)
                fprintf(stderr, "@@WALLBUG row %d\n", wrow);
        }
        if (memcmp(screen[0], w->_row[0], ZMAP_COLS) != 0)
            fprintf(stderr, "@@WALLBUG message row\n");
    }
#endif
    note_shown = z_panel_note[0];
    if (note_shown)
        memcpy(&screen[ZSCR_ROWS - 1][ZPANEL_COL], z_panel_note, strlen(z_panel_note));
    if (full)
        z_span_all();
    memset(sdirty, 0, sizeof sdirty);
    memset(sdlo, 255, sizeof sdlo);
    memset(sdhi, 0, sizeof sdhi);
    z_pdirty = 0;
    /* a view of another window (hw) is not stdscr: the next map refresh
     * must be full again */
    full = (w != stdscr);
    last_top = top;
    zb_show(screen, mask);
}
