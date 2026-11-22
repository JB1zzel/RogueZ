/*
 * curses.h - minimal curses for the Z88 Rogue port.
 *
 * Rogue keeps its own 80 x 24 screen (stdscr) and reads it back with inch(),
 * so we keep that buffer exactly as curses would.  What differs is the
 * physical screen: the Z88 has 8 rows of 94 columns.  zcurses.c composes
 * that screen:
 *     row 0, cols 0-79      message line (stdscr row 0)
 *     rows 1-7, cols 0-79   7 rows of the level, a viewport chosen by zview.c
 *     cols 81-93            status panel (Level, Gold, Hp ...)
 * Other windows (hw) are 8 x 94 and are shown as they are, at 0,0, except
 * show_win() maps, which go through the same viewport.
 *
 * LINES and COLS are the physical size (8 x 94), so Rogue's own paging
 * (add_line, help, options) breaks pages every 7 lines by itself.
 */
#ifndef ZCURSES_H
#define ZCURSES_H

#include <stdio.h>

#ifndef TRUE
#define TRUE  1
#define FALSE 0
#endif
#ifndef bool
#define bool char
#endif

#define ERR (-1)
#define OK  0

#define ZSCR_ROWS   8       /* Z88 screen */
#define ZSCR_COLS   94
#define ZMAP_COLS   80      /* Rogue map width */
#define ZPANEL_COL  81      /* status panel: columns 81-93 */
#define ZPANEL_W    13

#define A_CHARTEXT  0x7f
#define A_STANDOUT  0x80

typedef unsigned char chtype;

typedef struct zwin {
    int _maxy, _maxx;       /* size (rows, cols) */
    int _begy, _begx;       /* position on the screen */
    int _cury, _curx;
    int _stride;            /* row length of the buffer (subwindows share it) */
    unsigned char *_buf;    /* char | A_STANDOUT */
    unsigned char **_row;   /* start of each row (no y * stride: the Z80 has
                             * no multiply, and the screen is read constantly) */
    unsigned char _attr;
    unsigned char _owner;   /* buffer allocated by this window */
} WINDOW;

extern WINDOW *stdscr, *curscr;
extern int LINES, COLS;

/* set by the game: 1 while the level map is on stdscr (viewport), 0 for
 * full-screen text drawn on stdscr (tombstone, quit) shown as rows 0-7 */
extern int z_mapmode;
extern char z_panel_note[];

WINDOW *initscr(void);
int  endwin(void);
int  isendwin(void);
WINDOW *newwin(int lines, int cols, int y, int x);
WINDOW *subwin(WINDOW *orig, int lines, int cols, int y, int x);
int  delwin(WINDOW *w);
int  mvwin(WINDOW *w, int y, int x);

int  wmove(WINDOW *w, int y, int x);
int  waddch(WINDOW *w, chtype c);
int  waddstr(WINDOW *w, const char *s);
/* printw family: macros that format with sprintf, no variadic functions of
 * our own (sccz80 pushes arguments left to right: see msg() in io.c) */
extern char z_pbuf[];
int  z_mvwaddstr(WINDOW *w, int y, int x, const char *s);
#define wprintw(w, ...)       waddstr((w), (z_pbuf[0] = 0, sprintf(z_pbuf, __VA_ARGS__), z_pbuf))
#define printw(...)           waddstr(stdscr, (z_pbuf[0] = 0, sprintf(z_pbuf, __VA_ARGS__), z_pbuf))
#define mvwprintw(w, y, x, ...) z_mvwaddstr((w), (y), (x), (z_pbuf[0] = 0, sprintf(z_pbuf, __VA_ARGS__), z_pbuf))
#define mvprintw(y, x, ...)   z_mvwaddstr(stdscr, (y), (x), (z_pbuf[0] = 0, sprintf(z_pbuf, __VA_ARGS__), z_pbuf))
chtype winch(WINDOW *w);
int  wclear(WINDOW *w);
int  werase(WINDOW *w);
int  wclrtoeol(WINDOW *w);
int  wrefresh(WINDOW *w);
int  wstandout(WINDOW *w);
int  wstandend(WINDOW *w);
int  wgetch(WINDOW *w);
int  wgetnstr(WINDOW *w, char *s, int n);

#define move(y,x)           wmove(stdscr,(y),(x))
#define addch(c)            waddch(stdscr,(c))
#define addstr(s)           waddstr(stdscr,(s))
#define mvaddch(y,x,c)      (wmove(stdscr,(y),(x)), waddch(stdscr,(c)))
#define mvaddstr(y,x,s)     (wmove(stdscr,(y),(x)), waddstr(stdscr,(s)))
#define mvwaddch(w,y,x,c)   (wmove((w),(y),(x)), waddch((w),(c)))
#define mvwaddstr(w,y,x,s)  (wmove((w),(y),(x)), waddstr((w),(s)))
#define inch()              winch(stdscr)
#define mvinch(y,x)         (wmove(stdscr,(y),(x)), winch(stdscr))
#define mvwinch(w,y,x)      (wmove((w),(y),(x)), winch(w))
#define clear()             wclear(stdscr)
#define erase()             werase(stdscr)
#define clrtoeol()          wclrtoeol(stdscr)
#define refresh()           wrefresh(stdscr)
#define standout()          wstandout(stdscr)
#define standend()          wstandend(stdscr)
#define getch()             wgetch(stdscr)
#define getyx(w,y,x)        ((y) = (w)->_cury, (x) = (w)->_curx)

/* things Rogue calls that mean nothing here */
#define touchwin(w)         0
#define clearok(w,b)        0
#define leaveok(w,b)        0
#define idlok(w,b)          0
#define keypad(w,b)         0
#define raw()               0
#define noraw()             0
#define cbreak()            0
#define nocbreak()          0
#define echo()              0
#define noecho()            0
#define nonl()              0
#define nl()                0
#define flushinp()          0
#define baudrate()          9600
#define mvcur(a,b,c,d)      0
#define unctrl(c)           zunctrl(c)
#define erasechar()         8
#define killchar()          21
char *zunctrl(int c);

/* status panel (replaces Rogue's bottom status line) */
void z_status(int level, int gold, int hp, int maxhp, int str, int maxstr,
              int arm, int xlvl, long exp, const char *hunger);

/* backend (zterm.c on Linux, the OZ layer on the Z88) */
void zb_init(void);
void zb_end(void);
/*
 * Room walls on the map are drawn with OZ box characters (1,'2','*',c).
 * z_compose_map stores them in the screen buffer as ZW_BOX | directions;
 * zb_show sends '@' + directions.  The Linux backend shows them as '-'/'|'
 * again: a '|' is always ZW_U|ZW_D, everything else came from a '-'.
 */
#define ZW_BOX  0x10
#define ZW_R    0x01            /* checked against OZ 4.x: 'A'..'O' */
#define ZW_D    0x02
#define ZW_L    0x04
#define ZW_U    0x08
#define ZW_PASSAGE 0x10         /* '#': user-defined character '@' */
#define ZW_ISBOX(c)  (((c) & 0x7F) > ZW_BOX && ((c) & 0x7F) < 0x20)
unsigned char z_maprows(WINDOW *w, int top, int full);
void z_walls(unsigned char *d, const unsigned char *src, const unsigned char *up,
             const unsigned char *dn, int lo, int hi);
void zb_show(unsigned char scr[ZSCR_ROWS][ZSCR_COLS], unsigned char rows);  /* rows: bit r = row r may have changed */
int  zb_getkey(void);
void z_beep(void);                  /* Rogue's putchar(7) */

/* game side (zview.c) */
int  z_view_top(void);      /* first map row of the 7-row viewport */
void z_show_map(WINDOW *w, const char *message);   /* paged level view */

/* compose and show: map viewport starting at map row 'top' */
void z_compose_map(WINDOW *w, int top);

#endif
