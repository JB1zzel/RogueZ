/* zsignal.h - the Z88 has no signals: Rogue's signal() calls do nothing */
#ifndef ZSIGNAL_H
#define ZSIGNAL_H
#define SIGHUP  1
#define SIGINT  2
#define SIGQUIT 3
#define SIGTERM 15
#define SIG_DFL ((void (*)(int)) 0)
#define SIG_IGN ((void (*)(int)) 1)
#define signal(s, f) ((void) (s), (void (*)(int)) 0)
#endif
