/*
 * This file has all the code for the option command.  I would rather
 * this command were not necessary, but it is the only way to keep the
 * wolves off of my back.
 *
 * @(#)options.c	4.24 (Berkeley) 05/10/83
 *
 * Rogue: Exploring the Dungeons of Doom
 * Copyright (C) 1980-1983, 1985, 1999 Michael Toy, Ken Arnold and Glenn Wichman
 * All rights reserved.
 *
 * See the file LICENSE.TXT for full copyright and licensing information.
 */

#include <stdlib.h>
#include <curses.h>
#include <ctype.h>
#include <string.h>
#include "rogue.h"

#define	EQSTR(a, b, c)	(strncmp(a, b, c) == 0)

#define	NUM_OPTS	(sizeof optlist / sizeof (OPTION))

/*
 * description of an option and what to do with it
 */
struct optstruct {
    char	*o_name;	/* option name */
    char	*o_prompt;	/* prompt for interactive entry */
    void 	*o_opt;		/* pointer to thing to set */
				/* function to print value */
    void 	(*o_putfunc)(void *opt);
				/* function to get value interactively */
    int		(*o_getfunc)(void *opt, WINDOW *win);
};

typedef struct optstruct	OPTION;

void	pr_optname(OPTION *op);

#ifndef __Z88__
OPTION	optlist[] = {
    {"terse",	 "Terse output",
		 &terse,	put_bool,	get_bool	},
    {"flush",	 "Flush typeahead during battle",
		 &fight_flush,	put_bool,	get_bool	},
    {"jump",	 "Show position only at end of run",
		 &jump,		put_bool,	get_bool	},
    {"seefloor", "Show the lamp-illuminated floor",
		 &see_floor,	put_bool,	get_sf		},
    {"passgo",	"Follow turnings in passageways",
		 &passgo,	put_bool,	get_bool	},
    {"tombstone", "Print out tombstone when killed",
		 &tombstone,	put_bool,	get_bool	},
    {"inven",	"Inventory style",
		 &inv_type,	put_inv_t,	get_inv_t	},
    {"name",	 "Name",
		 whoami,	put_str,	get_str		},
    {"fruit",	 "Fruit",
		 fruit,		put_str,	get_str		},
    {"file",	 "Save file",
		 file_name,	put_str,	get_str		}
};
#endif

/*
 * option:
 *	Print and then set options from the terminal
 */

#ifndef __Z88__
void
option()
{
    OPTION	*op;
    int		retval;

    wclear(hw);
    /*
     * Display current values of options
     */
    for (op = optlist; op <= &optlist[NUM_OPTS-1]; op++)
    {
	pr_optname(op);
	(*op->o_putfunc)(op->o_opt);
	waddch(hw, '\n');
    }
    /*
     * Set values
     */
    wmove(hw, 0, 0);
    for (op = optlist; op <= &optlist[NUM_OPTS-1]; op++)
    {
	pr_optname(op);
	retval = (*op->o_getfunc)(op->o_opt, hw);
	if (retval)
	{
	    if (retval == QUIT)
		break;
	    else if (op > optlist) {	/* MINUS */
		wmove(hw, (int)(op - optlist) - 1, 0);
		op -= 2;
	    }
	    else	/* trying to back up beyond the top */
	    {
		z_beep();
		wmove(hw, 0, 0);
		op--;
	    }
	}
    }
    /*
     * Switch back to original screen
     */
    wmove(hw, LINES - 1, 0);
    waddstr(hw, "--Press space to continue--");
    wrefresh(hw);
    wait_for(' ');
    clearok(curscr, TRUE);
    touchwin(stdscr);
    after = FALSE;
}
#endif

#ifdef __Z88__
/*
 * z_option: an option chosen in the MENU's Options topic (z88/mth.asm):
 * flip it (or step it, or ask for the name) and say what it is now.
 * zb_getkey (zoz.c) puts the option's place in optlist in z_optcmd.
 */
int z_optcmd;

void
z_option(void)
{  /* the MENU offers the stairs (0) and the name (7) */
    int r;

    if (z_optcmd == 0)
    {
        z_upstairs = !z_upstairs;
        msg(z_upstairs ? "the stairs now lead up as well as down"
                       : "the stairs lead only down (up with the Amulet)");
        return;
    }
    if (z_optcmd != 7)
        return;
    msg("What is your name? ");
    r = get_str(whoami, stdscr);
    mpos = 0;                           /* the question needs no --More-- */
    if (r == NORM)
        msg("Your name is %s", whoami);
    else
        msg("");
}
#endif

/*
 * pr_optname:
 *	Print out the option name prompt
 */

#ifndef __Z88__
void
pr_optname(OPTION *op)
{
    wprintw(hw, "%s (\"%s\"): ", op->o_prompt, op->o_name);
}
#endif

/*
 * put_bool
 *	Put out a boolean
 */

#ifndef __Z88__
void
put_bool(void *b)
{
    waddstr(hw, *(bool *) b ? "True" : "False");
}
#endif

/*
 * put_str:
 *	Put out a string
 */

#ifndef __Z88__
void
put_str(void *str)
{
    waddstr(hw, (char *) str);
}
#endif

/*
 * put_inv_t:
 *	Put out an inventory type
 */

#ifndef __Z88__
void
put_inv_t(void *ip)
{
    waddstr(hw, inv_t_name[*(int *) ip]);
}
#endif

/*
 * get_bool:
 *	Allow changing a boolean option and print it out
 */
#ifndef __Z88__
int
get_bool(void *vp, WINDOW *win)
{
    bool *bp = (bool *) vp;
    int oy, ox;
    bool op_bad;

    op_bad = TRUE;
    getyx(win, oy, ox);
    waddstr(win, *bp ? "True" : "False");
    while (op_bad)	
    {
	wmove(win, oy, ox);
	wrefresh(win);
	switch (readchar())
	{
	    case 't':
	    case 'T':
		*bp = TRUE;
		op_bad = FALSE;
		break;
	    case 'f':
	    case 'F':
		*bp = FALSE;
		op_bad = FALSE;
		break;
	    case '\n':
	    case '\r':
		op_bad = FALSE;
		break;
	    case ESCAPE:
		return QUIT;
	    case '-':
		return MINUS;
	    default:
		wmove(win, oy, ox + 10);
		waddstr(win, "(T or F)");
	}
    }
    wmove(win, oy, ox);
    waddstr(win, *bp ? "True" : "False");
    waddch(win, '\n');
    return NORM;
}
#endif

/*
 * get_sf:
 *	Change value and handle transition problems from see_floor to
 *	!see_floor.
 */
#ifndef __Z88__
int
get_sf(void *vp, WINDOW *win)
{
    bool	*bp = (bool *) vp;
    bool	was_sf;
    int		retval;

    was_sf = see_floor;
    retval = get_bool(bp, win);
    if (retval == QUIT) return(QUIT);
    if (was_sf != see_floor)
    {
	if (!see_floor) {
	    see_floor = TRUE;
	    erase_lamp(&hero, proom);
	    see_floor = FALSE;
	}
	else
	    look(FALSE);
    }
    return(NORM);
}
#endif

/*
 * get_str:
 *	Set a string option
 */
#define MAXINP	50	/* max string to read from terminal or environment */

int
get_str(void *vopt, WINDOW *win)
{
    char *opt = (char *) vopt;
    char *sp;
    int oy, ox;
    int i;
    signed char c;
    static char buf[MAXSTR];

    getyx(win, oy, ox);
    wrefresh(win);
    /*
     * loop reading in the string, and put it in a temporary buffer
     */
    for (sp = buf; (c = readchar()) != '\n' && c != '\r' && c != ESCAPE;
	wclrtoeol(win), wrefresh(win))
    {
	if (c == -1)
	    continue;
	else if (c == erasechar() || c == 127)	/* erase: BS, or DEL (the Z88) */
	{
	    if (sp > buf)
	    {
		int ey, ex;

		sp--;			/* back over it; wclrtoeol wipes it */
		getyx(win, ey, ex);
		wmove(win, ey, ex - (int) strlen(unctrl(*sp)));
	    }
	    continue;
	}
	else if (c == killchar())	/* process kill character */
	{
	    sp = buf;
	    wmove(win, oy, ox);
	    continue;
	}
	else if (sp == buf)
	{
	    if (c == '-' && win != stdscr)
		break;
	    else if (c == '~')
	    {
		strcpy(buf, home);
		waddstr(win, home);
		sp += strlen(home);
		continue;
	    }
	}
	if (sp >= &buf[MAXINP] || !(isprint(c) || c == ' '))
	    z_beep();
	else
	{
	    *sp++ = c;
	    waddstr(win, unctrl(c));
	}
    }
    *sp = '\0';
    if (sp > buf)	/* only change option if something has been typed */
	strucpy(opt, buf, (int) strlen(buf));
    mvwprintw(win, oy, ox, "%s\n", opt);
    wrefresh(win);
    if (win == stdscr)
	mpos += (int)(sp - buf);
    if (c == '-')
	return MINUS;
    else if (c == ESCAPE)
	return QUIT;
    else
	return NORM;
}

/*
 * get_inv_t
 *	Get an inventory type name
 */
#ifndef __Z88__
int
get_inv_t(void *vp, WINDOW *win)
{
    int *ip = (int *) vp;
    int oy, ox;
    bool op_bad;

    op_bad = TRUE;
    getyx(win, oy, ox);
    waddstr(win, inv_t_name[*ip]);
    while (op_bad)	
    {
	wmove(win, oy, ox);
	wrefresh(win);
	switch (readchar())
	{
	    case 'o':
	    case 'O':
		*ip = INV_OVER;
		op_bad = FALSE;
		break;
	    case 's':
	    case 'S':
		*ip = INV_SLOW;
		op_bad = FALSE;
		break;
	    case 'c':
	    case 'C':
		*ip = INV_CLEAR;
		op_bad = FALSE;
		break;
	    case '\n':
	    case '\r':
		op_bad = FALSE;
		break;
	    case ESCAPE:
		return QUIT;
	    case '-':
		return MINUS;
	    default:
		wmove(win, oy, ox + 15);
		waddstr(win, "(O, S, or C)");
	}
    }
    mvwprintw(win, oy, ox, "%s\n", inv_t_name[*ip]);
    return NORM;
}
#endif
	

#ifdef MASTER
/*
 * get_num:
 *	Get a numeric option
 */
int
get_num(void *vp, WINDOW *win)
{
    short *opt = (short *) vp;
    int i;
    static char buf[MAXSTR];

    if ((i = get_str(buf, win)) == NORM)
	*opt = (short) atoi(buf);
    return i;
}
#endif

/*
 * parse_opts:
 *	Parse options from string, usually taken from the environment.
 *	The string is a series of comma seperated values, with booleans
 *	being stated as "name" (true) or "noname" (false), and strings
 *	being "name=....", with the string being defined up to a comma
 *	or the end of the entire option string.
 */

#ifndef __Z88__
void
parse_opts(char *str)
{
    char *sp;
    OPTION *op;
    int len;
    char **i;
    char *start;

    while (*str)
    {
	/*
	 * Get option name
	 */
	for (sp = str; isalpha(*sp); sp++)
	    continue;
	len = (int)(sp - str);
	/*
	 * Look it up and deal with it
	 */
	for (op = optlist; op <= &optlist[NUM_OPTS-1]; op++)
	    if (EQSTR(str, op->o_name, len))
	    {
		if (op->o_putfunc == put_bool)	/* if option is a boolean */
		    *(bool *)op->o_opt = TRUE;	/* NOSTRICT */
		else				/* string option */
		{
		    /*
		     * Skip to start of string value
		     */
		    for (str = sp + 1; *str == '='; str++)
			continue;
		    if (*str == '~')
		    {
			strcpy((char *) op->o_opt, home);	  /* NOSTRICT */
			start = (char *) op->o_opt + strlen(home);/* NOSTRICT */
			while (*++str == '/')
			    continue;
		    }
		    else
			start = (char *) op->o_opt;	/* NOSTRICT */
		    /*
		     * Skip to end of string value
		     */
		    for (sp = str + 1; *sp && *sp != ','; sp++)
			continue;
		    /*
		     * check for type of inventory
		     */
		    if (op->o_putfunc == put_inv_t)
		    {
			if (islower(*str))
			    *str = (char) toupper(*str);
			for (i = inv_t_name; i <= &inv_t_name[INV_CLEAR]; i++)
			    if (strncmp(str, *i, sp - str) == 0)
			    {
				inv_type = (int)(i - inv_t_name);
				break;
			    }
		    }
		    else
			strucpy(start, str, (int)(sp - str));
		}
		break;
	    }
	    /*
	     * check for "noname" for booleans
	     */
	    else if (op->o_putfunc == put_bool
	      && EQSTR(str, "no", 2) && EQSTR(str + 2, op->o_name, len - 2))
	    {
		*(bool *)op->o_opt = FALSE;	/* NOSTRICT */
		break;
	    }

	/*
	 * skip to start of next option name
	 */
	while (*sp && !isalpha(*sp))
	    sp++;
	str = sp;
    }
}
#endif

/*
 * strucpy:
 *	Copy string using unctrl for things
 */

void
strucpy(char *s1, char *s2, int len)
{
    if (len > MAXINP)
	len = MAXINP;
    while (len--)
    {
	if (isprint(*s2) || *s2 == ' ')
	    *s1++ = *s2;
	s2++;
    }
    *s1 = '\0';
}
