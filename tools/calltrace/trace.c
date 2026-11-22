/* -finstrument-functions hooks: count caller->callee pairs, dump at exit */
#include <stdio.h>
#include <stdlib.h>
#define N 65536
static void *ka[N], *kb[N];
static unsigned long cnt[N];
static void *stack[4096];
static int sp;
static void dump(void) __attribute__((no_instrument_function));
static void dump(void)
{
    FILE *f = fopen(getenv("ZTRACE") ? getenv("ZTRACE") : "calls.txt", "a");
    int i;
    for (i = 0; i < N; i++)
        if (cnt[i]) fprintf(f, "%p %p %lu\n", ka[i], kb[i], cnt[i]);
    fclose(f);
}
void __cyg_profile_func_enter(void *fn, void *site) __attribute__((no_instrument_function));
void __cyg_profile_func_exit(void *fn, void *site) __attribute__((no_instrument_function));
void __cyg_profile_func_enter(void *fn, void *site)
{
    static int inited;
    void *caller = sp ? stack[sp - 1] : 0;
    unsigned h;
    (void) site;
    if (!inited) { inited = 1; atexit(dump); }
    if (sp < 4096) stack[sp++] = fn;
    h = (unsigned) (((unsigned long) caller * 31 + (unsigned long) fn) >> 2) & (N - 1);
    while (cnt[h] && (ka[h] != caller || kb[h] != fn)) h = (h + 1) & (N - 1);
    ka[h] = caller; kb[h] = fn; cnt[h]++;
}
void __cyg_profile_func_exit(void *fn, void *site)
{
    (void) fn; (void) site;
    if (sp) sp--;
}
