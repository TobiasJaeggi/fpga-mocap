#ifndef STDLIB_H_INCLUDED
#define STDLIB_H_INCLUDED

#include <defs.h>

#ifdef __cplusplus
extern "C" {
#endif

void* memcpy(void* dest, const void* src, size_t n);
void* memmove(void* s1, const void* s2, size_t n);
void bcopy(const void* s1, void* s2, size_t n);
void* memset(void* dest, register int val, register size_t len);

#ifdef __cplusplus
}
#endif

#endif /* STDLIB_H_INCLUDED */
