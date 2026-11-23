Rogue for the Z88

  rogue.app + rogue.ap0 ... rogue.ap5   RAM application, any OZ: copy all seven
                                        files, then install rogue.app
                                        (OZ 4.7: Index; OZ 4.0: Garry Lancaster's
                                        BASIC Installer, Install, name ROGUE)
  rogue-oz5.app                         OZ 5: one compressed file, install it alone
  rogue.epr                             128K card image

The RAM application is 6 banks (96K): 5 code banks (the last also holds the
MENU and help) and the application bank.  The help is not tokenized, so it
reads on every OZ.  Installed, the banks can be anywhere: Rogue finds them at
start-up by the signature each carries.  It needs 24K of RAM ($2000-$7FFF);
if OZ gives less but at least $2000-$3FFF, it takes a 16K bank of its own for
the rest.  After installing, the copied files can be deleted.

Rebuild: sh tools/build88.sh (build-z88/rogue.epr), then
  python3 tools/mkramapp.py build-z88/rogue.epr <z88card> release/ramapp
