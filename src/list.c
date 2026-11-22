/*
 * Functions for dealing with linked lists of goodies
 *
 * @(#)list.c	4.12 (Berkeley) 02/05/99
 *
 * Rogue: Exploring the Dungeons of Doom
 * Copyright (C) 1980-1983, 1985, 1999 Michael Toy, Ken Arnold and Glenn Wichman
 * All rights reserved.
 *
 * See the file LICENSE.TXT for full copyright and licensing information.
 */

#include <stdlib.h>
#include <curses.h>
#include <string.h>
#include "rogue.h"

THING things_pool[NTHINGS];		/* Z88: every monster and object */

/*
 * Z88 map access (rogue.h macros chat, flat, moat, INDEX use these)
 */
#ifdef __Z88__
/* place_at() and thing_of() are in z88/hot.asm; it assumes these sizes */
typedef char check_place_size[sizeof (PLACE) == 3 ? 1 : -1];
typedef char check_thing_size[sizeof (THING) == 49 ? 1 : -1];
#else
PLACE *
place_at(int y, int x)
{
    return &places[(x << 4) + (x << 3) + y];	/* x * NUMLINES + y */
}

THING *
thing_of(int i)
{
    return i ? &things_pool[i - 1] : NULL;
}
#endif

void
set_moat(int y, int x, THING *tp)
{
    place_at(y, x)->p_mi = tp ? (unsigned char) (tp - things_pool + 1) : 0;
}
static THING *free_things;
static bool pool_ready;

#ifdef MASTER
int total = 0;			/* total dynamic memory bytes */
#endif

/*
 * detach:
 *	takes an item out of whatever linked list it might be in
 */

void
_detach(THING **list, THING *item)
{
    if (*list == item)
	*list = next(item);
    if (prev(item) != NULL)
	item->l_prev->l_next = next(item);
    if (next(item) != NULL)
	item->l_next->l_prev = prev(item);
    item->l_next = NULL;
    item->l_prev = NULL;
}

/*
 * _attach:
 *	add an item to the head of a list
 */

void
_attach(THING **list, THING *item)
{
    if (*list != NULL)
    {
	item->l_next = *list;
	(*list)->l_prev = item;
	item->l_prev = NULL;
    }
    else
    {
	item->l_next = NULL;
	item->l_prev = NULL;
    }
    *list = item;
}

/*
 * _free_list:
 *	Throw the whole blamed thing away
 */

void
_free_list(THING **ptr)
{
    THING *item;

    while (*ptr != NULL)
    {
	item = *ptr;
	*ptr = next(item);
	discard(item);
    }
}

/*
 * discard:
 *	Free up an item
 */

void
discard(THING *item)
{
#ifdef MASTER
    total--;
#endif
    /* Z88: back on the pool's free list */
    item->l_next = free_things;
    free_things = item;
}

/*
 * new_item
 *	Get a new item with a specified size
 */
THING *
new_item()
{
    THING *item;

    /*
     * Z88: monsters and objects come from a fixed pool (no heap, and the
     * map can hold a monster as a one-byte pool number)
     */
    if (!pool_ready)
    {
	int i;

	for (i = NTHINGS - 1; i >= 0; i--)
	{
	    things_pool[i].l_next = free_things;
	    free_things = &things_pool[i];
	}
	pool_ready = TRUE;
    }
    if ((item = free_things) == NULL)
	fatal("Out of room for monsters and objects\n");
    free_things = item->l_next;
    memset(item, 0, sizeof *item);
#ifdef MASTER
    total++;
#endif
    item->l_next = NULL;
    item->l_prev = NULL;
    return item;
}

#ifndef __Z88__
/* test aid (zterm.c pipe mode, ZMONS=1): monsters as the Z88 test reads them */
void
z_dump_monsters(void)
{
    THING *tp;

    for (tp = mlist; tp != NULL; tp = next(tp))
        printf("@@MON %c y%d x%d flags %04x dest %s room %d oldch %c\n", tp->t_type,
            tp->t_pos.y, tp->t_pos.x, (unsigned) (tp->t_flags & 0xffff),
            tp->t_dest == &hero ? "hero" : tp->t_dest == NULL ? "-" : "other",
            tp->t_room ? (int) (tp->t_room - rooms) : -1, tp->t_oldch);
}
#endif
