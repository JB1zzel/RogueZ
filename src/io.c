/*
 * Various input/output functions
 *
 * @(#)io.c	4.32 (Berkeley) 02/05/99
 */

#include <stdarg.h>
#include <curses.h>
#include <ctype.h>
#include <string.h>
#include "rogue.h"

/*
 * msg:
 *	Display a message at the top of the screen.
 */
#define MAXMSG	(NUMCOLS - sizeof "--More--")

static char msgbuf[2*MAXMSG+1];
static int newpos = 0;

/*
 * Z88: msg() and addmsg() are macros (rogue.h) that format with sprintf into
 * msgtmp and call msg_s()/addmsg_s() with the result.  sccz80 cannot reach the
 * named arguments of a variadic function of our own (it pushes arguments left
 * to right), and a far-call stub would overwrite the count it passes in A.
 */
char msgtmp[MAXSTR];

int
msg_s(char *str)
{
    /*
     * if the string is "", just clear the line
     */
    if (*str == '\0')
    {
	move(0, 0);
	clrtoeol();
	mpos = 0;
	return ~ESCAPE;
    }
    /*
     * otherwise add to the message and flush it out
     */
    doadd(str);
    return endmsg();
}

/*
 * addmsg:
 *	Add things to the current message
 */
void
addmsg_s(char *str)
{
    doadd(str);
}

/*
 * endmsg:
 *	Display a new msg (giving him a chance to see the previous one
 *	if it is up there with the --More--)
 */
int
endmsg()
{
    char ch;

    if (save_msg)
	strcpy(huh, msgbuf);
    if (mpos)
    {
	look(FALSE);
	mvaddstr(0, mpos, "--More--");
	refresh();
	if (!msg_esc)
	    wait_for(' ');
	else
	{
	    while ((ch = readchar()) != ' ')
		if (ch == ESCAPE)
		{
		    msgbuf[0] = '\0';
		    mpos = 0;
		    newpos = 0;
		    msgbuf[0] = '\0';
		    return ESCAPE;
		}
	}
    }
    /*
     * All messages should start with uppercase, except ones that
     * start with a pack addressing character
     */
    if (islower(msgbuf[0]) && !lower_msg && msgbuf[1] != ')')
	msgbuf[0] = (char) toupper(msgbuf[0]);
    mvaddstr(0, 0, msgbuf);
    clrtoeol();
    mpos = newpos;
    newpos = 0;
    msgbuf[0] = '\0';
    refresh();
    return ~ESCAPE;
}

/*
 * doadd:
 *	Perform an add onto the message buffer
 */
void
doadd(char *str)
{
    if (strlen(str) + newpos >= MAXMSG)
        endmsg(); 
    strcat(msgbuf, str);
    newpos = (int) strlen(msgbuf);
}

/*
 * step_ok:
 *	Returns true if it is ok to step on ch
 */
#ifndef __Z88__	/* Z88: in z88/hot.asm */
int
step_ok(int ch)
{
    switch (ch)
    {
	case ' ':
	case '|':
	case '-':
	    return FALSE;
	default:
	    return (!isalpha(ch));
    }
}
#endif

/*
 * readchar:
 *	Reads and returns a character, checking for gross input errors
 */
char
readchar()
{
    char ch;

    ch = (char) md_readchar();

    if (ch == 3)
    {
	quit(0);
        return(27);
    }

    return(ch);
}

/*
 * status:
 *	Display the important stats line.  Keep the cursor where it was.
 */
void
status()
{
    register int oy, ox, temp;
    static int hpwidth = 0;
    static int s_hungry = 0;
    static int s_lvl = 0;
    static int s_pur = -1;
    static int s_hp = 0;
    static int s_arm = 0;
    static str_t s_str = 0;
    static long s_exp = 0;
    static char *state_name[] =
    {
	"", "Hungry", "Weak", "Faint"
    };

    /*
     * If nothing has changed since the last status, don't
     * bother.
     */
    temp = (cur_armor != NULL ? cur_armor->o_arm : pstats.s_arm);
    if (s_hp == pstats.s_hpt && s_exp == pstats.s_exp && s_pur == purse
	&& s_arm == temp && s_str == pstats.s_str && s_lvl == level
	&& s_hungry == hungry_state
	&& !stat_msg
	)
	    return;

    s_arm = temp;

    getyx(stdscr, oy, ox);
    if (s_hp != max_hp)
    {
	temp = max_hp;
	s_hp = max_hp;
	for (hpwidth = 0; temp; hpwidth++)
	    temp /= 10;
    }

    /*
     * Save current status
     */
    s_lvl = level;
    s_pur = purse;
    s_hp = pstats.s_hpt;
    s_str = pstats.s_str;
    s_exp = pstats.s_exp; 
    s_hungry = hungry_state;

    if (stat_msg)
    {
	move(0, 0);
        msg("Level: %d  Gold: %-5d  Hp: %*d(%*d)  Str: %2d(%d)  Arm: %-2d  Exp: %d/%ld  %s",
	    level, purse, hpwidth, pstats.s_hpt, hpwidth, max_hp, pstats.s_str,
	    max_stats.s_str, 10 - s_arm, pstats.s_lvl, pstats.s_exp,
	    state_name[hungry_state]);
    }
    else
    {
	/* Z88: status goes in the side panel, not on line 23 */
	z_status(level, purse, pstats.s_hpt, max_hp, pstats.s_str,
	    max_stats.s_str, 10 - s_arm, pstats.s_lvl, pstats.s_exp,
	    state_name[hungry_state]);
	move(oy, ox);
	return;
    }

    clrtoeol();
    move(oy, ox);
}

/*
 * wait_for
 *	Sit around until the guy types the right key
 */
void
wait_for(int ch)
{
    register char c;

    if (ch == '\n')
        while ((c = readchar()) != '\n' && c != '\r')
	    continue;
    else
        while (readchar() != ch)
	    continue;
}

/*
 * show_win:
 *	Function used to display a window and wait before returning
 */
void
show_win(char *message)
{
    WINDOW *win;

    win = hw;
    wmove(win, 0, 0);
    waddstr(win, message);
    touchwin(win);
    z_show_map(win, message);
    clearok(curscr, TRUE);
    touchwin(stdscr);
}
