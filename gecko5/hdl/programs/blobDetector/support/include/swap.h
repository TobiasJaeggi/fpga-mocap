#ifndef SWAP_H_INCLUDED
#define SWAP_H_INCLUDED

#include <defs.h>

#ifdef __cplusplus
extern "C" {
#endif

__static_inline uint32_t swap_u32(uint32_t src) {
    uint32_t dest;
    asm volatile("l.nios_rrr %[out1],%[in1],r0,0x1" : [out1] "=r"(dest) : [in1] "r"(src));
    return dest;
}

__static_inline uint16_t swap_u16(uint16_t src) {
    uint16_t dest;
    asm volatile("l.nios_rrr %[out1],%[in1],%[in2],0x1" : [out1] "=r"(dest) : [in1] "r"(src), [in2] "r"(1));
    return dest;
}

#ifdef __cplusplus
}
#endif

#endif /* SWAP_H_INCLUDED */
