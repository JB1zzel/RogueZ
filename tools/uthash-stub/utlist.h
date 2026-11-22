/* Minimal stand-in for utlist.h (singly/doubly linked list macros).
 * DL lists: head->prev is the tail, tail->next is NULL (as utlist). */
#ifndef UTLIST_H
#define UTLIST_H

#define LL_APPEND(head, add) LL_APPEND2(head, add, next)
#define LL_APPEND2(head, add, next) do {                                    \
    __typeof__(head) _t;                                                    \
    (add)->next = NULL;                                                     \
    if (head) { _t = (head); while (_t->next) _t = _t->next; _t->next = (add); } \
    else (head) = (add);                                                    \
    } while (0)
#define LL_PREPEND(head, add) do { (add)->next = (head); (head) = (add); } while (0)
#define LL_DELETE(head, del) LL_DELETE2(head, del, next)
#define LL_DELETE2(head, del, next) do {                                    \
    __typeof__(head) _t;                                                    \
    if ((head) == (del)) (head) = (head)->next;                             \
    else { _t = (head); while (_t->next && _t->next != (del)) _t = _t->next;\
           if (_t->next) _t->next = (del)->next; }                          \
    } while (0)
#define LL_FOREACH(head, el) LL_FOREACH2(head, el, next)
#define LL_FOREACH2(head, el, next) for ((el) = (head); el; (el) = (el)->next)
#define LL_FOREACH_SAFE(head, el, tmp) LL_FOREACH_SAFE2(head, el, tmp, next)
#define LL_FOREACH_SAFE2(head, el, tmp, next)                               \
    for ((el) = (head); (el) && ((tmp) = (el)->next, 1); (el) = (tmp))
#define LL_COUNT(head, el, counter)                                         \
    do { (counter) = 0; LL_FOREACH(head, el) ++(counter); } while (0)

#define DL_APPEND(head, add) DL_APPEND2(head, add, prev, next)
#define DL_APPEND2(head, add, prev, next) do {                              \
    if (head) {                                                             \
        (add)->prev = (head)->prev;                                         \
        (head)->prev->next = (add);                                         \
        (head)->prev = (add);                                               \
        (add)->next = NULL;                                                 \
    } else {                                                                \
        (head) = (add);                                                     \
        (head)->prev = (head);                                              \
        (head)->next = NULL;                                                \
    } } while (0)
#define DL_PREPEND(head, add) do {                                          \
    (add)->next = (head);                                                   \
    if (head) { (add)->prev = (head)->prev; (head)->prev = (add); }         \
    else (add)->prev = (add);                                               \
    (head) = (add); } while (0)
#define DL_DELETE(head, del) DL_DELETE2(head, del, prev, next)
#define DL_DELETE2(head, del, prev, next) do {                              \
    if ((del)->prev == (del)) {                                             \
        (head) = NULL;                                                      \
    } else if ((del) == (head)) {                                           \
        (del)->next->prev = (del)->prev;                                    \
        (head) = (del)->next;                                               \
    } else {                                                                \
        (del)->prev->next = (del)->next;                                    \
        if ((del)->next) (del)->next->prev = (del)->prev;                   \
        else (head)->prev = (del)->prev;                                    \
    } } while (0)
#define DL_FOREACH(head, el) DL_FOREACH2(head, el, next)
#define DL_FOREACH2(head, el, next) for ((el) = (head); el; (el) = (el)->next)
#define DL_FOREACH_SAFE(head, el, tmp) DL_FOREACH_SAFE2(head, el, tmp, next)
#define DL_FOREACH_SAFE2(head, el, tmp, next)                               \
    for ((el) = (head); (el) && ((tmp) = (el)->next, 1); (el) = (tmp))
#define DL_COUNT(head, el, counter)                                         \
    do { (counter) = 0; DL_FOREACH(head, el) ++(counter); } while (0)
#endif
