/* Minimal stand-in for utstring.h (dynamic strings). */
#ifndef UTSTRING_H
#define UTSTRING_H
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { char *d; size_t n; size_t i; } UT_string;

#define utstring_reserve(s, amt) do {                                       \
    if ((s)->n - (s)->i < (size_t)(amt)) {                                  \
        char *_t = realloc((s)->d, (s)->n + (amt));                         \
        if (!_t) abort();                                                   \
        (s)->d = _t; (s)->n += (amt); } } while (0)
#define utstring_init(s) do {                                               \
    (s)->n = 0; (s)->i = 0; (s)->d = NULL;                                  \
    utstring_reserve(s, 100); (s)->d[0] = '\0'; } while (0)
#define utstring_done(s) do { free((s)->d); (s)->n = 0; } while (0)
#define utstring_free(s) do { utstring_done(s); free(s); } while (0)
#define utstring_new(s) do {                                                \
    (s) = (UT_string *)malloc(sizeof(UT_string));                           \
    if (!(s)) abort();                                                      \
    utstring_init(s); } while (0)
#define utstring_renew(s) do {                                              \
    if (s) utstring_clear(s); else utstring_new(s); } while (0)
#define utstring_clear(s) do { (s)->i = 0; (s)->d[0] = '\0'; } while (0)
#define utstring_bincpy(s, b, l) do {                                       \
    utstring_reserve((s), (l) + 1);                                         \
    if (l) memcpy(&(s)->d[(s)->i], b, l);                                   \
    (s)->i += (l); (s)->d[(s)->i] = '\0'; } while (0)
#define utstring_concat(dst, src) do {                                      \
    utstring_reserve((dst), ((src)->i) + 1);                                \
    if ((src)->i) memcpy(&(dst)->d[(dst)->i], (src)->d, (src)->i);          \
    (dst)->i += (src)->i; (dst)->d[(dst)->i] = '\0'; } while (0)
#define utstring_len(s) ((s)->i)
#define utstring_body(s) ((s)->d)

static inline void utstring_printf_va(UT_string *s, const char *fmt, va_list ap) {
    int n;
    va_list cp;
    for (;;) {
        va_copy(cp, ap);
        n = vsnprintf(&s->d[s->i], s->n - s->i, fmt, cp);
        va_end(cp);
        if (n > -1 && (size_t)n < s->n - s->i) { s->i += n; return; }
        if (n > -1) utstring_reserve(s, n + 1);
        else utstring_reserve(s, s->n * 2);
    }
}
static inline void utstring_printf(UT_string *s, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    utstring_printf_va(s, fmt, ap);
    va_end(ap);
}
#endif
