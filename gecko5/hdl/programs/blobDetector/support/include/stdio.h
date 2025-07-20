#ifndef STDIO_H_INCLUDED
#define STDIO_H_INCLUDED

#ifdef __cplusplus
extern "C" {
#endif

int putchar(int c);
int puts(const char *s);
int getchar(void);

#ifdef __cplusplus
}
#endif

#include "printf.h"

#endif /* STDIO_H_INCLUDED */
