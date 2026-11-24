/*
 * zterm.c - Linux backend for the Z88 layout: draws the 8 x 94 screen in a
 * box on a terminal and reads keys raw.  On the Z88 this file is replaced by
 * the OZ layer (windows, Os_Tin).
 *
 * ZKEYS=file      read keys from a file instead of the terminal (for tests);
 *                 at end of file the game quits
 * ZSHOTS=file     append every screen to a text file (for tests)
 * ZPIPE=1         bot mode: before each key, write the 24 x 80 logical screen
 *                 and the 8 x 94 Z88 screen to stdout, then read one key from
 *                 stdin
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include "curses.h"

static struct termios saved;
static int raw_on;
static FILE *keyf, *shotf;
static unsigned char last[ZSCR_ROWS][ZSCR_COLS];
static int have_last, pipemode;
void z_dump_monsters(void);

void
zb_init(void)
{
    struct termios t;
    char *k = getenv("ZKEYS"), *s = getenv("ZSHOTS");

    if (k != NULL)
        keyf = fopen(k, "r");
    if (s != NULL)
        shotf = fopen(s, "a");
    pipemode = getenv("ZPIPE") != NULL;
    if (pipemode)
        return;
    if (keyf == NULL && isatty(0) && tcgetattr(0, &saved) == 0)
    {
        t = saved;
        t.c_lflag &= ~(ICANON | ECHO | ISIG);
        t.c_iflag &= ~(IXON | ICRNL);
        t.c_cc[VMIN] = 1;
        t.c_cc[VTIME] = 0;
        tcsetattr(0, TCSANOW, &t);
        raw_on = 1;
    }
    if (keyf == NULL)
        printf("\033[2J\033[?25l");
}

void
zb_end(void)
{
    if (raw_on)
        tcsetattr(0, TCSANOW, &saved);
    raw_on = 0;
    if (keyf == NULL && !pipemode)
        printf("\033[?25h\033[%d;1H\n", ZSCR_ROWS + 3);
    fflush(stdout);
}

static void
put_screen(FILE *f, unsigned char scr[ZSCR_ROWS][ZSCR_COLS], int ansi)
{
    int r, c, so;

    fprintf(f, ansi ? "\033[H+" : "+");
    for (c = 0; c < ZSCR_COLS; c++)
        fputc('-', f);
    fprintf(f, "+\n");
    for (r = 0; r < ZSCR_ROWS; r++)
    {
        so = 0;
        fputc('|', f);
        for (c = 0; c < ZSCR_COLS; c++)
        {
            int ch = scr[r][c];

            if ((ch & 0x7F) == ZW_PASSAGE)
            {
                if (pipemode && getenv("ZBOX"))
                {                       /* U+00D0 for test/z88vslinux */
                    fputc(0xC3, f);
                    fputc(0x90, f);
                    continue;
                }
                ch = (ch & A_STANDOUT) | '#';
            }
            if (ZW_ISBOX(ch))           /* a wall: see z_walls */
            {
                if (pipemode && getenv("ZBOX"))
                {                       /* exact shape for test/z88vslinux */
                    fputc(0xC3, f);     /* U+00C0 + directions, in UTF-8 */
                    fputc(0x80 + (ch & 0x0F), f);
                    continue;
                }
                ch = (ch & A_STANDOUT)
                     | ((ch & 0x0F) == (ZW_U | ZW_D) ? '|' : '-');
            }

            if (ansi && (ch & A_STANDOUT) != so)
            {
                so = ch & A_STANDOUT;
                fprintf(f, so ? "\033[7m" : "\033[0m");
            }
            fputc(ch & A_CHARTEXT, f);
        }
        if (so)
            fprintf(f, "\033[0m");
        fprintf(f, "|\n");
    }
    fputc('+', f);
    for (c = 0; c < ZSCR_COLS; c++)
        fputc('-', f);
    fprintf(f, "+\n");
}

void
zb_show(unsigned char scr[ZSCR_ROWS][ZSCR_COLS], unsigned char rows)
{
    (void) rows;
    if (have_last && memcmp(last, scr, sizeof last) == 0)
        return;
    memcpy(last, scr, sizeof last);
    have_last = 1;
    if (keyf == NULL && !pipemode)
    {
        put_screen(stdout, scr, 1);
        fflush(stdout);
    }
}

/* key files: one key per character; \e = ESC, \n newline, ^X ctrl, ~ shot */
int
zb_getkey(void)
{
    int c;

    if (keyf != NULL)
    {
        for (;;)
        {
            c = fgetc(keyf);
            if (c == EOF)
            {
                if (shotf)
                {
                    fprintf(shotf, "== end of keys\n");
                    put_screen(shotf, last, 0);
                    fclose(shotf);
                }
                zb_end();
                exit(0);
            }
            if (c == '~')           /* screenshot here */
            {
                if (shotf)
                    put_screen(shotf, last, 0);
                continue;
            }
            if (c == '#')           /* comment to end of line */
            {
                while ((c = fgetc(keyf)) != EOF && c != '\n')
                    ;
                continue;
            }
            if (c == '\n')
                continue;           /* newlines in the file are layout */
            if (c == '\\')
            {
                c = fgetc(keyf);
                return c == 'e' ? 27 : c == 'n' ? '\n' : c == 's' ? ' ' : c;
            }
            if (c == '^')
                return fgetc(keyf) & 037;
            return c;
        }
    }
    if (pipemode)
    {
        int r, x;

        {
            extern long seed;

            printf("@@SEED %08lx\n", (unsigned long) seed);
            if (getenv("ZMONS"))
                z_dump_monsters();
        }
        printf("@@SCREEN %d %d\n", stdscr->_cury, stdscr->_curx);
        for (r = 0; r < 24; r++)
        {
            for (x = 0; x < ZMAP_COLS; x++)
                putchar(stdscr->_buf[r * ZMAP_COLS + x] & A_CHARTEXT);
            putchar('\n');
        }
        put_screen(stdout, last, 0);
        printf("@@KEY\n");
        fflush(stdout);
        c = getchar();
        if (c == EOF)
            exit(0);
        return c;
    }
    c = getchar();
    if (c == 27)                    /* cursor keys -> hjkl */
    {
        int c2;

        fflush(stdout);
        c2 = getchar();
        if (c2 != '[')
            return 27;
        switch (getchar())
        {
        case 'A': return 'k';
        case 'B': return 'j';
        case 'C': return 'l';
        case 'D': return 'h';
        }
        return 27;
    }
    if (c == '\r')
        c = '\n';
    if (c == EOF)                   /* input closed: leave */
    {
        zb_end();
        exit(0);
    }
    return c;
}

void
z_beep(void)
{
    if (keyf == NULL && !pipemode)
        putchar(7);
}

/* the mini map is the Z88's (z88/zmini.asm) */
char z_mini;
unsigned char z_lastc = ZSCR_COLS - 1;
char zb_valid;
void z_mini_open(void) { }
void z_mini_close(void) { }
void z_mini_row(int y, unsigned char *row) { (void) y; (void) row; }
