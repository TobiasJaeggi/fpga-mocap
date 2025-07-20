#ifndef VISIONADDON_APP_UTILS_SWO_H
#define VISIONADDON_APP_UTILS_SWO_H

#ifdef __cplusplus
extern "C" {
#endif

#include "stm32f7xx_hal.h"

// Function to send data to the debugger via SWO
int _write(int file, char *ptr, int len) {
    (void)file;
    const char PRINTF_LABEL[] {"\x1B[1;31mprintf might use heap!\x1B[2;0m "};
    for (size_t i = 0; i < sizeof(PRINTF_LABEL); i++) {
        ITM_SendChar(PRINTF_LABEL[i]);  // SWO output
    }
    for (int i = 0; i < len; i++) {
        ITM_SendChar(ptr[i]);  // SWO output
    }
    return len;
}

#ifdef __cplusplus
}
#endif

#endif //VISIONADDON_APP_UTILS_SWO_H