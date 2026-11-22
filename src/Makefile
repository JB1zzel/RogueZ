# Linux build of the Z88 layout prototype
GAME = armor.c chase.c command.c daemon.c daemons.c extern.c fight.c init.c \
       io.c list.c main.c misc.c monsters.c move.c new_level.c options.c \
       pack.c passages.c potions.c rings.c rip.c rooms.c scrolls.c sticks.c \
       things.c weapons.c wizard.c save.c mach_dep.c vers.c
Z88  = zcurses.c zcold.c zmap.c zview.c md.c resident.c
HOST = zterm.c
CFLAGS = -O1 -g -w -DHAVE_CONFIG_H -I.

rogue88: $(GAME) $(Z88) $(HOST) *.h
	$(CC) $(CFLAGS) -o $@ $(GAME) $(Z88) $(HOST)

clean:
	rm -f rogue88
