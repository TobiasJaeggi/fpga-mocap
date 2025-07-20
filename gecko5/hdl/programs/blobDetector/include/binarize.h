#ifndef BINARIZE_H_INCLUDED
#define BINARIZE_H_INCLUDED

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

bool binarizeSetThreshold(uint32_t threshold);
uint32_t binarizeGetThreshold();

#ifdef __cplusplus
}
#endif

#endif /* BINARIZE_H_INCLUDED */
