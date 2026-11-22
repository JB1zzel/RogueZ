Rogue for the Cambridge Z88 - step 1: the 8-row layout, prototyped on Linux
===========================================================================
Rogue 5.4.4 (Toy, Arnold, Wichman; BSD licence, see LICENSE.TXT) with its
screen code replaced by a small curses that composes the Z88's 8 x 94 screen.
It builds and plays on Linux now; the same curses, viewport and md code is
what goes to z88dk.  Only zterm.c (terminal output, keys) is Linux-specific:
on the Z88 it becomes the OZ layer (windows, Os_Tin).

Screen
  row 0, cols 0-79      message line (Rogue's own, with --More--)
  rows 1-7, cols 0-79   7 rows of the level
  cols 81-93            status panel: Level, Gold, Hp, Str, Arm, Exp, hunger
  Lists (inventory, help, discoveries) are full 8-row pages: Rogue pages them
  itself because LINES is 8.

Which 7 rows (zview.c)
  Rogue places every room inside one box of a 3 x 3 grid of 26 x 8 boxes;
  a room with its walls is 4-7 rows and always lies within rows top..top+6 of
  its box (rooms.c).  So:
    in a room or maze   the view snaps to the room's band: rows 1-7, 8-14, 16-22
                        - the whole room is always on screen
    in a passage        the view follows the hero, re-centring near the edge
  M (new command)       look at the rest of the level, a band at a time
                        (j/k or cursor keys, space to go back).  The panel
                        shows "Map 1/3" etc.  Detect magic / food views use it.

Build and play (Linux)
  cd src && make            -> rogue88
  ./rogue88                 cursor keys or hjklyubn, ? then * for help
  ZSEED=n ./rogue88         the same dungeon every time

Tests
  ZKEYS=keys.txt ZSHOTS=shots.txt ./rogue88   keys from a file; ~ in the file
                            appends the screen to shots.txt, # comments,
                            \s space, \e ESC, \n return, ^X ctrl-X
  test/bot.py SEED [N]      an exploring bot (ZPIPE mode: it sees the screen
                            before each key).  Checks every map frame: hero on
                            screen in the right place, the 7 rows are 7
                            consecutive level rows, and when the hero is in a
                            lit room all its walls are on screen.
                            12 seeds, ~22,000 map frames, levels 1-4: no errors.
  rogue88 -d                straight to the tombstone (death screen test)

Measuring the Z80 size
  sh tools/z88dk-size.sh                  (sccz80)
  COMPILER=sdcc sh tools/z88dk-size.sh    (zsdcc)
  -> build-size/report.txt: per-module sizes by section.  Results and the
  banking plan: SIZE-REPORT.txt.

Changes to the Rogue sources (all marked "Z88" where not obvious)
  extern.h/extern.c/rogue.h/io.c
      seed and experience are long: the generator did seed*11109 >> 16 in an
      int, which is 0 with a 16-bit int, and experience goes to 8,000,000.
      The generator is kept to 31 bits so it behaves the same on any host.
      MAXSTR 1024 -> 128 (it sizes a dozen static buffers).
  io.c        status() writes the side panel; show_win() uses the viewport
  main.c      no 80 x 24 check; hw is NUMLINES x COLS (map coordinates for
              show_win); no "Hello" printf; ZSEED; fixed Rogue's -d option,
              which looped 4 billion times when rnd(100) returned 0
  command.c   M command; help pages 2 x 7 entries with --More--
  extern.c    M in the help list
  rip.c       7-row tombstone; death waits for a key, not stdin
  save.c      hw size
  removed     mdport.c (Unix/Windows), xcrypt.c, state.c (save format)
  new         curses.h zcurses.c zview.c md.c zterm.c config.h Makefile

Still to do on the screen side
  * options (o): 10 options in a list; the last 2 are below row 7.  Cut the
    list to what matters on a Z88 (name, terse, tombstone, ...) or page it.
  * winner's screen (total_winner): a 13-row banner.
  * score table: still printed to the terminal after the game; needs an
    8-row screen and somewhere to live (an OZ file).
  * help: drop "! shell escape"; S (save) does nothing yet.

Next steps
  Step 2 (size): SIZE-REPORT.txt.  Step 3 (banking): BANKING.txt.
  Step 4 (the card): Z88.txt - build-z88/rogue.epr runs in the dev kit
  harness; Z88 and Linux play identically, screen for screen.
  5. Saving: dump the game's RAM to an OZ file (and load it at start).
  6. Score table as an OZ file; options screen and winner's banner for 8 rows.
  7. Test on OZ 4.7 / 3.0, OZvm, KLive and real hardware; confirm the stack.

Tests added in step 3
  test/samegame.py OLD NEW SEED N   drive two builds with the same random keys
                                    and compare every screen
  test/randplay.py BIN SEED N       random keys over all commands

Tests added in step 4
  test/z88vslinux.py CARD SEED KEYS...   Z88 test card against Linux, every
                                         screen and the random seed compared
  tools/sxtcheck.py DIR                  the sccz80 bool-cast problem (Z88.txt)
