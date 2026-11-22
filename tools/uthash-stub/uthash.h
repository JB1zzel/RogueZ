/* Minimal stand-in for Troy Hanson's uthash (the ext/uthash submodule was not
 * in the tarball).  Same macro API for what z88dk uses; a plain doubly linked
 * list in insertion order - lookups are linear, fine for compiling one file. */
#ifndef UTHASH_H
#define UTHASH_H
#include <string.h>
#include <stdlib.h>

typedef struct UT_hash_handle {
    void *next, *prev;          /* elements, not handles (as uthash) */
    const void *key;
    unsigned keylen;
    void *tail;                 /* valid in the head element only */
} UT_hash_handle;

#define HASH_FIND(hh, head, keyptr, keylen_in, out) do {                    \
    void *_e = (void *)(head);                                              \
    (out) = NULL;                                                           \
    while (_e) {                                                            \
        __typeof__(head) _t = (__typeof__(head))_e;                         \
        if (_t->hh.keylen == (unsigned)(keylen_in) &&                       \
            memcmp(_t->hh.key, (keyptr), (keylen_in)) == 0) {               \
            (out) = _t; break; }                                            \
        _e = _t->hh.next;                                                   \
    } } while (0)

#define HASH_ADD_KEYPTR(hh, head, keyptr, keylen_in, add) do {              \
    (add)->hh.key = (keyptr);                                               \
    (add)->hh.keylen = (unsigned)(keylen_in);                               \
    (add)->hh.next = NULL;                                                  \
    if (!(head)) {                                                          \
        (add)->hh.prev = NULL;                                              \
        (head) = (add);                                                     \
    } else {                                                                \
        __typeof__(head) _tl = (__typeof__(head))(head)->hh.tail;           \
        _tl->hh.next = (add);                                               \
        (add)->hh.prev = _tl;                                               \
    }                                                                       \
    (head)->hh.tail = (add);                                                \
    } while (0)

#define HASH_ADD(hh, head, fieldname, keylen_in, add)                       \
    HASH_ADD_KEYPTR(hh, head, &((add)->fieldname), keylen_in, add)

#define HASH_DELETE(hh, head, delptr) do {                                  \
    __typeof__(head) _d = (delptr);                                         \
    __typeof__(head) _p = (__typeof__(head))_d->hh.prev;                    \
    __typeof__(head) _n = (__typeof__(head))_d->hh.next;                    \
    void *_oldtail = (head)->hh.tail;                                       \
    if (_p) _p->hh.next = _n; else (head) = _n;                             \
    if (_n) _n->hh.prev = _p;                                               \
    if (head) (head)->hh.tail = (_oldtail == (void *)_d) ? (void *)_p : _oldtail; \
    } while (0)

#define HASH_FIND_STR(head, findstr, out)                                   \
    HASH_FIND(hh, head, findstr, strlen(findstr), out)
#define HASH_ADD_STR(head, strfield, add)                                   \
    HASH_ADD_KEYPTR(hh, head, &((add)->strfield[0]), strlen((add)->strfield), add)
#define HASH_FIND_INT(head, findint, out)                                   \
    HASH_FIND(hh, head, findint, sizeof(int), out)
#define HASH_ADD_INT(head, intfield, add)                                   \
    HASH_ADD(hh, head, intfield, sizeof(int), add)
#define HASH_FIND_PTR(head, findptr, out)                                   \
    HASH_FIND(hh, head, findptr, sizeof(void *), out)
#define HASH_ADD_PTR(head, ptrfield, add)                                   \
    HASH_ADD(hh, head, ptrfield, sizeof(void *), add)
#define HASH_DEL(head, delptr) HASH_DELETE(hh, head, delptr)

#define HASH_ITER(hh, head, el, tmp)                                        \
    for ((el) = (head), (tmp) = (el) ? (__typeof__(el))(el)->hh.next : NULL;\
         (el); (el) = (tmp),                                                \
         (tmp) = (el) ? (__typeof__(el))(el)->hh.next : NULL)

static inline unsigned ut_hash_count_(void *head, size_t off) {
    unsigned n = 0;
    while (head) { n++; head = ((UT_hash_handle *)((char *)head + off))->next; }
    return n;
}
#define HASH_CNT(hh, head)                                                  \
    ((head) ? ut_hash_count_((void *)(head),                                \
        (size_t)((char *)&(head)->hh - (char *)(head))) : 0u)
#define HASH_COUNT(head) HASH_CNT(hh, head)

/* stable insertion sort of the list, then relink */
#define HASH_SRT(hh, head, cmpfcn) do {                                     \
    unsigned _n = HASH_CNT(hh, head), _i, _j;                               \
    if (_n > 1) {                                                           \
        __typeof__(head) *_v = malloc(_n * sizeof *_v), _x;                 \
        _x = (head);                                                        \
        for (_i = 0; _i < _n; _i++) {                                       \
            _v[_i] = _x; _x = (__typeof__(head))_x->hh.next; }              \
        for (_i = 1; _i < _n; _i++) {                                       \
            _x = _v[_i];                                                    \
            for (_j = _i; _j > 0 && cmpfcn(_v[_j - 1], _x) > 0; _j--)       \
                _v[_j] = _v[_j - 1];                                        \
            _v[_j] = _x; }                                                  \
        for (_i = 0; _i < _n; _i++) {                                       \
            _v[_i]->hh.prev = _i ? _v[_i - 1] : NULL;                       \
            _v[_i]->hh.next = _i + 1 < _n ? _v[_i + 1] : NULL; }            \
        (head) = _v[0];                                                     \
        (head)->hh.tail = _v[_n - 1];                                       \
        free(_v);                                                           \
    } } while (0)
#define HASH_SORT(head, cmpfcn) HASH_SRT(hh, head, cmpfcn)

#define HASH_CLEAR(hh, head) do { (head) = NULL; } while (0)
#endif
