/*
 * md.c - the machine-dependent calls Rogue makes, cut down for the Z88 port.
 * Replaces mdport.c (1400 lines of Unix/Windows code).  Most are no-ops on a
 * single-user machine with no signals, shell or uids.
 */
#include <stdio.h>
#include <string.h>
#include <curses.h>
#include "rogue.h"

#ifdef __Z88__
#include <malloc.h>
long heap;			/* z88dk classic heap */
static unsigned char z88heap[3072];	/* hw window, scroll names, guesses */

void
md_init(void)
{
    mallinit();
    sbrk(z88heap, sizeof z88heap);
}
#else
void md_init(void) { }
#endif
void md_normaluser(void) { }
int  md_getpid(void) { return 1; }
char *md_getusername(void) { return "Rogue"; }
char *md_gethomedir(void) { return ""; }
int  md_hasclreol(void) { return TRUE; }    /* gives INV_CLEAR: full-page lists */

int
md_readchar(void)
{
    return zb_getkey();
}

#ifndef __Z88__
/* not called on the Z88 (the host build's Unix code still calls them) */
int  md_getuid(void) { return 42; }
char *md_getrealname(int uid) { (void) uid; return "Rogue"; }
char *md_getpass(char *prompt) { (void) prompt; return ""; }
char *md_crypt(char *key, char *salt) { (void) salt; return key; }
int  md_chmod(char *filename, int mode) { (void) filename; (void) mode; return 0; }
int  md_unlink(char *file) { return remove(file); }
int  md_unlink_open_file(char *file, FILE *inf) { fclose(inf); return remove(file); }
int  md_issymlink(char *sp) { (void) sp; return 0; }
int  md_erasechar(void) { return 8; }
int  md_killchar(void) { return 21; }
int  md_suspchar(void) { return 0; }
int  md_dsuspchar(void) { return 0; }
int  md_setdsuspchar(int c) { (void) c; return 0; }
int  md_shellescape(void) { return 0; }
void md_sleep(int s) { (void) s; }
void md_raw_standout(void) { }
void md_raw_standend(void) { }
void md_tstpsignal(void) { }
void md_tstphold(void) { }
void md_tstpresume(void) { }
void md_ignoreallsignals(void) { }
void md_onsignal_autosave(void) { }
void md_onsignal_exit(void) { }
void md_onsignal_default(void) { }
void md_start_checkout_timer(int t) { (void) t; }
void md_stop_checkout_timer(void) { }

int
rs_save_file(FILE *savef)
{
    (void) savef;
    return 1;
}

int
rs_restore_file(FILE *inf)
{
    (void) inf;
    return 1;
}
#endif
