/*
 * zview.c - which 7 rows of the level the Z88 shows.
 *
 * Rogue lays a level out as a 3 x 3 grid of boxes 26 x 8 (rooms.c: bsze =
 * NUMCOLS/3, NUMLINES/3).  A room, walls included, is 4-7 rows and always lies
 * within rows top..top+6 of its box (top = 0, 8, 16; top 0 rooms start at row
 * 1).  Mazes fill rows top..top+6.  So a 7-row viewport snapped to the box
 * shows any room whole:
 *     in a room or maze   snap to its band: map rows 1-7, 8-14 or 16-22
 *     in a passage        follow the hero, re-centring near the edge
 * Row 0 is the message line; row 23 (status) is not used on the Z88.
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <curses.h>
#include "rogue.h"

#define VROWS   7
#define VTOP_MIN 1
#define VTOP_MAX (NUMLINES - 1 - VROWS)     /* 16: rows 16-22 */

static int band_top[3] = { 1, 8, 16 };
static int vtop = VTOP_MIN;

static int
clamp_top(int t)
{
    if (t < VTOP_MIN)
        return VTOP_MIN;
    if (t > VTOP_MAX)
        return VTOP_MAX;
    return t;
}

int
z_view_top(void)
{
    struct room *rp = proom;
    int y = hero.y;

    if (rp != NULL && rp >= rooms && rp < &rooms[MAXROOMS]
        && !(rp->r_flags & ISGONE))
        vtop = band_top[(rp - rooms) / 3];          /* room or maze */
    else if (y < vtop || y >= vtop + VROWS
             || (y == vtop && vtop > VTOP_MIN)
             || (y == vtop + VROWS - 1 && vtop < VTOP_MAX))
        vtop = clamp_top(y - VROWS / 2);            /* passage */
    return vtop;
}

/*
 * Show a level view a band at a time: up/down (k/j or cursor keys) move
 * between the three bands, space or ESC finishes.  Row 0 of w is the message.
 */
void
z_show_map(WINDOW *w, const char *message)
{
    int b, top = z_view_top(), c;

    (void) message;
    for (b = 0; b < 2 && top >= band_top[b + 1]; b++)
        ;
    if (top != band_top[b])         /* in a passage: start where we are */
        b = -1;
    for (;;)
    {
        if (b < 0)
            strcpy(z_panel_note, "Map (here)");
        else
            sprintf(z_panel_note, "Map %d/3", b + 1);
        z_compose_map(w, b < 0 ? top : band_top[b]);
        c = zb_getkey();
        if (c == ' ' || c == ESCAPE || c == '\n' || c == '\r')
            break;
        if (c == 'k' || c == 'K' || c == '8')
        {
            if (b < 0)
                for (b = 2; b > 0 && band_top[b] >= top; b--)
                    ;
            else if (b > 0)
                b--;
        }
        else if (c == 'j' || c == 'J' || c == '2')
        {
            if (b < 0)
                for (b = 0; b < 2 && band_top[b] <= top; b++)
                    ;
            else if (b < 2)
                b++;
        }
    }
    z_panel_note[0] = '\0';
}

/*
 * M command: look at the rest of the level.
 */
void
z_peek(void)
{
    static char save[NUMCOLS];
    int x;

    for (x = 0; x < NUMCOLS; x++)
        save[x] = (char) mvinch(0, x);
    move(0, 0);
    clrtoeol();
    addstr("Level map: j/k or up/down to look, space to go on");
    z_show_map(stdscr, NULL);
    for (x = 0; x < NUMCOLS; x++)
        mvaddch(0, x, save[x]);
    move(hero.y, hero.x);
    refresh();
}
