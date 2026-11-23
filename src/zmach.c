/*
 * zmach.c - the Z88 build's replacement for mach_dep.c (Unix scorefile,
 * locking, terminal modes, signals: none of which exist on the Z88).
 */
#include <stdio.h>
#include <curses.h>
#include "rogue.h"

unsigned int numscores = NUMSCORES;
char *Numname = NUMNAME;

void init_check(void) { }
void open_score(void) { }
void setup(void) { }
void getltchars(void) { }
void resetltchars(void) { }
void flush_type(void) { }

#ifndef __Z88__
void playltchars(void) { }
void start_score(void) { }
bool is_symlink(char *sp) { (void) sp; return FALSE; }
bool lock_sc(void) { return FALSE; }
void unlock_sc(void) { }
#endif
