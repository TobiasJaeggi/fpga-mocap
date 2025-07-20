#ifndef BUSERRORCOUNTER_H_INCLUDED
#define BUSERRORCOUNTER_H_INCLUDED

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

uint32_t busErrorCounterGet();
void busErrorCounterReset();

#ifdef __cplusplus
}
#endif

#endif /* BUSERRORCOUNTER_H_INCLUDED */
