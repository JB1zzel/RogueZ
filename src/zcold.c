/*
 * zcold.c - the parts of the curses layer used rarely (window creation,
 * string input, status panel formatting).  Banked on the Z88; zcurses.c,
 * which runs on every key, stays resident (BANKING.txt, Z88.txt).
 */
#include <stdlib.h>
#include <string.h>
#include "curses.h"

#ifdef __Z88__
#define ZSTATIC static                  /* as in rogue.h */
#else
#define ZSTATIC
#endif

extern char z_panel[ZSCR_ROWS][ZPANEL_W + 1];
extern unsigned char z_pdirty;

static int ended = 1;
static WINDOW stdwin;
static unsigned char stdbuf[24 * ZMAP_COLS];
static unsigned char *stdrows[24];

static void
set_rows(WINDOW *w, unsigned char **rows)
{
    int y;
    unsigned char *p = w->_buf;

    w->_row = rows;
    for (y = 0; y < w->_maxy; y++)
    {
        rows[y] = p;
        p += w->_stride;
    }
}


WINDOW *
initscr(void)
{
    if (stdscr == NULL)
    {
        stdwin._maxy = 24;
        stdwin._maxx = ZMAP_COLS;
        stdwin._stride = ZMAP_COLS;
        stdwin._buf = stdbuf;
        set_rows(&stdwin, stdrows);
        stdscr = curscr = &stdwin;
        wclear(stdscr);
    }
    zb_init();
    ended = 0;
    return stdscr;
}


int
endwin(void)
{
    if (!ended)
        zb_end();
    ended = 1;
    return OK;
}


int
isendwin(void)
{
    return ended;
}


WINDOW *
newwin(int lines, int cols, int y, int x)
{
    WINDOW *w = calloc(1, sizeof *w);

    if (lines == 0) lines = ZSCR_ROWS - y;
    if (cols == 0) cols = ZSCR_COLS - x;
    w->_maxy = lines;
    w->_maxx = cols;
    w->_begy = y;
    w->_begx = x;
    w->_stride = cols;
    w->_buf = malloc((size_t) lines * cols);
    w->_owner = 1;
    set_rows(w, malloc((size_t) lines * sizeof (unsigned char *)));
    wclear(w);
    return w;
}


WINDOW *
subwin(WINDOW *orig, int lines, int cols, int y, int x)
{
    WINDOW *w = calloc(1, sizeof *w);

    w->_maxy = lines;
    w->_maxx = cols;
    w->_begy = y;
    w->_begx = x;
    w->_stride = orig->_stride;
    w->_buf = orig->_row[y - orig->_begy] + (x - orig->_begx);
    set_rows(w, malloc((size_t) lines * sizeof (unsigned char *)));
    return w;
}


int
delwin(WINDOW *w)
{
    if (w == NULL || w == stdscr)
        return ERR;
    if (w->_owner)
        free(w->_buf);
    free(w->_row);
    free(w);
    return OK;
}


int
mvwin(WINDOW *w, int y, int x)
{
    w->_begy = y;
    w->_begx = x;
    return OK;
}


#ifndef __Z88__
int
wgetnstr(WINDOW *w, char *s, int n)
{
    int c, i = 0;

    for (;;)
    {
        wrefresh(w);
        c = zb_getkey();
        if (c == '\n' || c == '\r')
            break;
        if ((c == 8 || c == 127) && i > 0)
        {
            i--;
            w->_curx--;
            waddch(w, ' ');
            w->_curx--;
        }
        else if (c >= ' ' && c < 127 && i < n - 1)
        {
            s[i++] = (char) c;
            waddch(w, (chtype) c);
        }
    }
    s[i] = '\0';
    return OK;
}
#endif


char *
zunctrl(int c)
{
    static char buf[3];

    c &= 0x7f;
    if (c < ' ' || c == 127)
    {
        buf[0] = '^';
        buf[1] = c == 127 ? '?' : (char) (c + '@');
        buf[2] = '\0';
    }
    else
    {
        buf[0] = (char) c;
        buf[1] = '\0';
    }
    return buf;
}


/*
 * Status panel.  Formatted by hand: printf's number conversion divides in
 * 32 bits and took ~40 ms for the panel on the Z88.  Only lines that changed
 * are marked for redrawing.
 */
static char zbuf[40];                   /* line being built */
char *z_fp;                             /* where it goes next */
void z_fs(const char *s);
void z_fu(unsigned int u);

#ifndef __Z88__	/* Z88: z_fs, z_fu in z88/hot.asm */
void
z_fs(const char *s)
{
    while ((*z_fp = *s++) != '\0')
        z_fp++;
}

void
z_fu(unsigned int u)
{
    static const unsigned int p10[] = { 10000, 1000, 100, 10 };
    ZSTATIC int i, started;
    ZSTATIC char d;

    started = 0;
    for (i = 0; i < 4; i++)
    {
        for (d = '0'; u >= p10[i]; d++)
            u -= p10[i];
        if (d != '0' || started)
        {
            *z_fp++ = d;
            started = 1;
        }
    }
    *z_fp++ = (char) ('0' + u);
}
#endif

static void
zn(int v)
{
    if (v < 0)
    {
        *z_fp++ = '-';
        z_fu((unsigned int) -v);
    }
    else
        z_fu((unsigned int) v);
}

static void
zlong(long v)                           /* experience: never negative */
{
    static const long p10[] = { 1000000000L, 100000000L, 10000000L,
                                1000000L, 100000L, 10000L, 1000L, 100L, 10L };
    int i, started = 0;
    char d;

    if (v < 32768L)
    {
        zn((int) v);
        return;
    }
    for (i = 0; i < 9; i++)
    {
        for (d = '0'; v >= p10[i]; d++)
            v -= p10[i];
        if (d != '0' || started)
        {
            *z_fp++ = d;
            started = 1;
        }
    }
    *z_fp++ = (char) ('0' + (int) v);
}

static void
zline(int row)
{
    zbuf[ZPANEL_W] = '\0';
    *z_fp = '\0';
    if (strcmp(zbuf, z_panel[row]) != 0)
    {
        strcpy(z_panel[row], zbuf);
        z_pdirty |= (unsigned char) (1 << row);
    }
    z_fp = zbuf;
}

static int z_lasthp;

void
z_status(int level, int gold, int hp, int maxhp, int str, int maxstr,
         int arm, int xlvl, long exp, const char *hunger)
{
    z_fp = zbuf;
    z_fs("Level "); zn(level); zline(0);
    z_fs("Gold  "); zn(gold); zline(1);
    z_fs("Hp "); zn(hp); z_fs("("); zn(maxhp); z_fs(")"); zline(2);
    z_fs("Str "); zn(str); z_fs("("); zn(maxstr); z_fs(")"); zline(3);
    z_fs("Arm "); zn(arm); zline(4);
    z_fs("Exp "); zn(xlvl); z_fs("/"); zlong(exp); zline(5);
    z_fs(hunger); zline(6);
    if (z_mini && !z_mstat)             /* the map in the panel: lost hit */
    {                                   /* points, or a change of strength,
                                           armour, experience or hunger (not
                                           at the start of a game): the stats */
        if (z_lasthp && ((z_pdirty & 0x78) || hp < z_lasthp))  /* shows */
            z_alert();
        else
            z_pdirty = 0;
    }
    z_lasthp = hp;
}

