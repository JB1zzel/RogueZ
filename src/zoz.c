/*
 * zoz.c - the Z88 backend of the screen layer: OZ window 1, 94 x 8, written
 * with GN_Sop (only the changed part of each row); keys with OS_In.
 * Replaces zterm.c in the Z88 build.  OZ calls are in z88/ozcalls.asm.
 */
#include <string.h>
#include "curses.h"

extern void oz_sop(char *s);
extern int oz_in(void);

extern unsigned char zb_shown[ZSCR_ROWS][ZSCR_COLS];   /* what OZ shows now (in
                                * z88/zsave.asm: outside a saved game) */
unsigned char (*zb_last)[ZSCR_COLS];             /* last screen given */
char zb_valid;                                   /* zb_shown is right */
extern int z_optcmd;                             /* options.c */
extern char zb_obuf[ZSCR_COLS * 4 + 16];         /* VDU string for GN_Sop */

/*
 * window 1: whole screen, no border; clear; cursor and scrolling off.
 * User-defined character '@': a 50% dither for passages (ZW_PASSAGE).
 * Rows top to bottom, bit 7 set, bit 5 the left pixel.  Defined again
 * whenever the screen comes back, as another application may have
 * redefined it.
 */
static char winit[] = {
    1, '7', '#', '1', 32, 32, 32 + ZSCR_COLS, 32 + ZSCR_ROWS, (char) 128,
    1, '2', 'C', '1', 1, '2', '-', 'C', 1, '2', '-', 'S',
    1, (char) 138, '=', '@',
    (char) 0xAA, (char) 0x95, (char) 0xAA, (char) 0x95,
    (char) 0xAA, (char) 0x95, (char) 0xAA, (char) 0x95, 0
};

void
zb_init(void)
{
    oz_sop(winit);
    zb_valid = 0;
    z_mini_init();                      /* zmap.c: the mini map, if on */
}

void
zb_end(void)
{
}

/* zb_show(scr, rows) is in z88/hot.asm: for each row in rows (bit r) that
 * differs from zb_shown, send the changed span with GN_Sop */

int
zb_getkey(void)
{
    int k;

    for (;;)
    {
        k = oz_in();
        if (k == 0)                     /* extended key: 0 then a code */
        {
            switch (k = oz_in())
            {
            case 0xFC: return 'h';      /* cursor keys move */
            case 0xFD: return 'l';
            case 0xFE: return 'j';
            case 0xFF: return 'k';
            case 0xF8: return 'H';      /* shift: run */
            case 0xF9: return 'L';
            case 0xFA: return 'J';
            case 0xFB: return 'K';
            case 0xF4: return 'H' & 037;    /* diamond: run till adjacent */
            case 0xF5: return 'L' & 037;
            case 0xF6: return 'J' & 037;
            case 0xF7: return 'K' & 037;
            case 0x81: return 'S';      /* MENU commands (z88/mth.asm) */
            case 0x82: return 'o';
            case 0x83: return 'M';
            case 0x84: return 'R' & 037;
            case 0x85: return 'Q';
            case 0x8E:                  /* MENU Mini map: no turn */
                z_mini_toggle();
                continue;
            }
            if (k >= 0x86 && k <= 0x8D)   /* MENU Options: command.c, ^^ */
            {
                z_optcmd = k - 0x86;
                return 036;
            }
            continue;
        }
        if (k < 256)
            return k == 13 ? '\n' : k;
        if (k == 0x200)                 /* another application used the screen */
        {
            zb_init();
            if (zb_last)
                zb_show(zb_last, 0xFF);
            continue;
        }
        return 27;                      /* escape, or anything else */
    }
}

void
z_beep(void)
{
    static char bell[] = { 7, 0 };

    oz_sop(bell);
}
