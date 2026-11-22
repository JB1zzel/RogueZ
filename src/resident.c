/*
 * resident.c - game functions that must not be banked (BANKING.txt).
 *
 * They are called from every bank and either read string arguments that live
 * in the caller's bank, or return string literals of their own, or are called
 * so often that a far call would cost too much (rnd, roll).  This module goes
 * in the fixed bank with io.c, zcurses.c and list.c.
 *
 * Rogue: Exploring the Dungeons of Doom
 * Copyright (C) 1980-1983, 1985, 1999 Michael Toy, Ken Arnold and Glenn Wichman
 * All rights reserved.  See the file LICENSE.TXT for full licensing information.
 */
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <curses.h>
#include "rogue.h"

/* from main.c */
/*
 * rnd:
 *	Pick a very random number.
 */
#ifndef __Z88__	/* Z88: in z88/hot.asm */
int
rnd(int range)
{
    return range == 0 ? 0 : abs((int) RN) % range;
}
#endif


/* from main.c */
/*
 * roll:
 *	Roll a number of dice
 */
int 
roll(int number, int sides)
{
    int dtotal = 0;

    while (number--)
	dtotal += rnd(sides)+1;
    return dtotal;
}


/* from pack.c */
/*
 * get_item:
 *	Pick something out of a pack for a purpose
 */
THING *
get_item(char *purpose, int type)
{
    THING *obj;
    char ch;

    if (pack == NULL)
	msg("you aren't carrying anything");
    else if (again)
	if (last_pick)
	    return last_pick;
	else
	    msg("you ran out");
    else
    {
	for (;;)
	{
	    if (!terse)
		addmsg("which object do you want to ");
	    addmsg(purpose);
	    if (terse)
		addmsg(" what");
	    msg("? (* for list): ");
	    ch = readchar();
	    mpos = 0;
	    /*
	     * Give the poor player a chance to abort the command
	     */
	    if (ch == ESCAPE)
	    {
		reset_last();
		after = FALSE;
		msg("");
		return NULL;
	    }
	    n_objs = 1;		/* normal case: person types one char */
	    if (ch == '*')
	    {
		mpos = 0;
		if (inventory(pack, type) == 0)
		{
		    after = FALSE;
		    return NULL;
		}
		continue;
	    }
	    for (obj = pack; obj != NULL; obj = next(obj))
		if (obj->o_packch == ch)
		    break;
	    if (obj == NULL)
	    {
		msg("'%s' is not a valid item",unctrl(ch));
		continue;
	    }
	    else 
		return obj;
	}
    }
    return NULL;
}


/* from misc.c */
/*
 * vowelstr:
 *      For printfs: if string starts with a vowel, return "n" for an
 *	"an".
 */
char *
vowelstr(char *str)
{
    switch (*str)
    {
	case 'a': case 'A':
	case 'e': case 'E':
	case 'i': case 'I':
	case 'o': case 'O':
	case 'u': case 'U':
	    return "n";
	default:
	    return "";
    }
}


/* from misc.c */
/*
 str str:
 *	Choose the first or second string depending on whether it the
 *	player is tripping
 */
char *
choose_str(char *ts, char *ns)
{
	return (on(player, ISHALU) ? ts : ns);
}

/* from fight.c */
/*
 * set_mname:
 *	return the monster name for the given monster
 */
char *
set_mname(THING *tp)
{
    int ch;
    char *mname;
    static char tbuf[MAXSTR] = { 't', 'h', 'e', ' ' };

    if (!see_monst(tp) && !on(player, SEEMONST))
	return (terse ? "it" : "something");
    else if (on(player, ISHALU))
    {
	move(tp->t_pos.y, tp->t_pos.x);
	ch = toascii(inch());
	if (!isupper(ch))
	    ch = rnd(26);
	else
	    ch -= 'A';
	mname = monsters[ch].m_name;
    }
    else
	mname = monsters[tp->t_type - 'A'].m_name;
    strcpy(&tbuf[4], mname);
    return tbuf;
}


/* from init.c */
/*
 * pick_color:
 *	If he is halucinating, pick a random color name and return it,
 *	otherwise return the given color.
 */
char *
pick_color(char *col)
{
    return (on(player, ISHALU) ? rainbow[rnd(NCOLORS)] : col);
}
