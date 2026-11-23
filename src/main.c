/*
 * Rogue: Exploring the Dungeons of Doom
 * Copyright (C) 1980-1983, 1985, 1999 Michael Toy, Ken Arnold and Glenn Wichman
 * All rights reserved.
 *
 * See the file LICENSE.TXT for full copyright and licensing information.
 *
 * @(#)main.c	4.22 (Berkeley) 02/05/99
 */

#include <stdlib.h>
#include <string.h>
#ifdef __Z88__
#include "zsignal.h"
#else
#include <signal.h>
#endif
#include <time.h>
#include <curses.h>
#include "rogue.h"

/*
 * main:
 *	The main program, of course
 */
int
main(int argc, char **argv, char **envp)
{
    char *env;
    int lowtime;

    md_init();

#ifdef MASTER
    /*
     * Check to see if he is a wizard
     */
    if (argc >= 2 && argv[1][0] == '\0')
	if (strcmp(PASSWD, md_crypt(md_getpass("wizard's password: "), "mT")) == 0)
	{
	    wizard = TRUE;
	    player.t_flags |= SEEMONST;
	    argv++;
	    argc--;
	}

#endif

    /*
     * get home and options from environment
     */

    strncpy(home, md_gethomedir(), MAXSTR);

    strcpy(file_name, home);
    strcat(file_name, "rogue.save");

#ifndef __Z88__
    if ((env = getenv("ROGUEOPTS")) != NULL)
	parse_opts(env);
#else
    env = NULL;		/* Z88: no environment; options from the o command */
#endif
    if (env == NULL || whoami[0] == '\0')
        strucpy(whoami, md_getusername(), (int) strlen(md_getusername()));
    lowtime = (int) time(NULL);
#ifdef MASTER
    if (wizard && getenv("SEED") != NULL)
	dnum = atoi(getenv("SEED"));
    else
#endif
	dnum = lowtime + md_getpid();
#ifndef __Z88__
    if (getenv("ZSEED") != NULL)	/* repeatable dungeons for tests */
	dnum = atoi(getenv("ZSEED"));
#elif defined(Z88_TEST_SEED)
    dnum = Z88_TEST_SEED;		/* test card: the dungeon of ZSEED=n */
#endif
    seed = dnum;

    open_score();

	/* 
     * Drop setuid/setgid after opening the scoreboard file. 
     */ 

    md_normaluser();

    /*
     * check for print-score option
     */

	md_normaluser(); /* we drop any setgid/setuid priveldges here */

    if (argc == 2)
    {
	if (strcmp(argv[1], "-s") == 0)
	{
	    noscore = TRUE;
	    score(0, -1, 0);
	    exit(0);
	}
	else if (strcmp(argv[1], "-d") == 0)
	{
	    dnum = rnd(100) + 1;	/* throw away some rnd()s (+1: rnd can be 0) */
	    while (--dnum)
		rnd(100);
	    purse = rnd(100) + 1;
	    level = rnd(100) + 1;
	    initscr();
	    getltchars();
	    death(death_monst());
	    exit(0);
	}
    }

    init_check();			/* check for legal startup */
    if (argc == 2)
	if (!restore(argv[1], envp))	/* Note: restore will never return */
	    my_exit(1);
#ifdef MASTER
    if (wizard)
	printf("Hello %s, welcome to dungeon #%d", whoami, dnum);
    else
#endif
	;

    initscr();				/* Start up cursor package */
#ifdef __Z88__
    mvaddstr(0, 0, "Descending into darkness...");	/* the level takes a */
    refresh();				/* moment: show it has not crashed */
#endif
    init_probs();			/* Set up prob tables for objects */
    init_player();			/* Set up initial player stats */
    init_names();			/* Set up names of scrolls */
    init_colors();			/* Set up colors of potions */
    init_stones();			/* Set up stone settings of rings */
    init_materials();			/* Set up materials of wands */
    setup();

    /*
     * Set up windows.  Z88: the screen is 8 x 94 (LINES x COLS); hw has
     * NUMLINES rows so level views (show_win) can use map coordinates.
     */
    hw = newwin(NUMLINES, COLS, 0, 0);
    idlok(stdscr, TRUE);
    idlok(hw, TRUE);
#ifdef __Z88__
    z_try_restore();			/* a saved game: carries on, no return */
#endif
#ifdef MASTER
    noscore = wizard;
#endif
#ifdef Z88_TEST_LEVEL
    level = Z88_TEST_LEVEL;		/* test card: start deep (mazes) */
#endif
#ifdef Z88_TEST_FLAGS
    player.t_flags |= Z88_TEST_FLAGS;	/* test card: blind, hallucinating... */
#endif
#ifdef Z88_TEST_HP
    pstats.s_hpt = Z88_TEST_HP;		/* test card: die soon */
#endif
#ifndef __Z88__
    if (getenv("ZFLAGS") != NULL)	/* the same on Linux (test/z88vslinux) */
	player.t_flags |= (short) strtol(getenv("ZFLAGS"), NULL, 0);
#endif
    new_level();			/* Draw current level */
    /*
     * Start up daemons and fuses
     */
    start_daemon(runners, 0, AFTER);
    start_daemon(doctor, 0, AFTER);
    fuse(swander, 0, WANDERTIME, AFTER);
    start_daemon(stomach, 0, AFTER);
    playit();
    return(0);
}

/*
 * endit:
 *	Exit the program abnormally.
 */

void
endit(int sig)
{
    NOOP(sig);
    fatal("Okay, bye bye!\n");
}

/*
 * fatal:
 *	Exit the program, printing a message.
 */

void
fatal(char *s)
{
    mvaddstr(LINES - 2, 0, s);
    refresh();
    endwin();
    my_exit(0);
}

/*
 * tstp:
 *	Handle stop and start signals
 */

#ifndef __Z88__
void
tstp(int ignored)
{
#ifndef __Z88__
    int y, x;
    int oy, ox;

	NOOP(ignored);

    /*
     * leave nicely
     */
    getyx(curscr, oy, ox);
    mvcur(0, COLS - 1, LINES - 1, 0);
    endwin();
    resetltchars();
    fflush(stdout);
	md_tstpsignal();

    /*
     * start back up again
     */
	md_tstpresume();
    raw();
    noecho();
    keypad(stdscr,1);
    playltchars();
    clearok(curscr, TRUE);
    wrefresh(curscr);
    getyx(curscr, y, x);
    mvcur(y, x, oy, ox);
    fflush(stdout);
    curscr->_cury = oy;
    curscr->_curx = ox;
#endif
}
#endif

/*
 * playit:
 *	The main loop of the program.  Loop until the game is over,
 *	refreshing things and looking at the proper times.
 */

void
playit()
{
    char *opts;

    /*
     * set up defaults for slow terminals
     */

    if (baudrate() <= 1200)
    {
	terse = TRUE;
	jump = TRUE;
	see_floor = FALSE;
    }

    if (md_hasclreol())
	inv_type = INV_CLEAR;

    /*
     * parse environment declaration of options
     */
#ifndef __Z88__
    if ((opts = getenv("ROGUEOPTS")) != NULL)
	parse_opts(opts);
#endif


    oldpos = hero;
    oldrp = roomin(&hero);
    while (playing)
	command();			/* Command execution */
    endit(0);
}

/*
 * quit:
 *	Have player make certain, then exit.
 */

void
quit(int sig)
{
    int oy, ox;

    NOOP(sig);

    /*
     * Reset the signal in case we got here via an interrupt
     */
    if (!q_comm)
	mpos = 0;
    getyx(curscr, oy, ox);
    msg("really quit?");
    if (readchar() == 'y')
    {
	signal(SIGINT, leave);
	z_mapmode = 0;
	clear();
	mvprintw(LINES - 2, 0, "You quit with %d gold pieces", purse);
	move(LINES - 1, 0);
	refresh();
	score(purse, 1, 0);
	my_exit(0);
    }
    else
    {
	move(0, 0);
	clrtoeol();
	status();
	move(oy, ox);
	refresh();
	mpos = 0;
	count = 0;
	to_death = FALSE;
    }
}

/*
 * leave:
 *	Leave quickly, but curteously
 */

#ifndef __Z88__
void
leave(int sig)
{
#ifndef __Z88__
    static char buf[BUFSIZ];
#endif

    NOOP(sig);

#ifndef __Z88__
    setbuf(stdout, buf);	/* throw away pending output */
#endif

    if (!isendwin())
    {
	mvcur(0, COLS - 1, LINES - 1, 0);
	endwin();
    }

#ifndef __Z88__
    putchar('\n');
#endif
    my_exit(0);
}
#endif

/*
 * shell:
 *	Let them escape for a while
 */

void
shell()
{
#ifdef __Z88__
    msg("there is no shell on the Z88");
#else
    /*
     * Set the terminal back to original mode
     */
    move(LINES-1, 0);
    refresh();
    endwin();
    resetltchars();
    putchar('\n');
    in_shell = TRUE;
    after = FALSE;
    fflush(stdout);
    /*
     * Fork and do a shell
     */
    md_shellescape();

    printf("\n[Press return to continue]");
    fflush(stdout);
    noecho();
    raw();
    keypad(stdscr,1);
    playltchars();
    in_shell = FALSE;
    wait_for('\n');
    clearok(stdscr, TRUE);
#endif
}

/*
 * my_exit:
 *	Leave the process properly
 */

void
my_exit(int st)
{
    resetltchars();
    exit(st);
}

