#ifndef MYLIB_H_INCLUDED
#define MYLIB_H_INCLUDED

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int myAbs(int v);
bool myAtoi(char *str, int *value);

#ifdef __cplusplus
}
#endif

#endif /* MYLIB_H_INCLUDED */
