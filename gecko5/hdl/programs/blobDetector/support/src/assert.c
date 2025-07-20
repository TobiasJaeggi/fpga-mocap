#include <assert.h>
#include <stdio.h>

int (*assert_printf)(const char*, ...) = &printf_;

void assert_die() {
    puts("dead!");
    while (1);
}
