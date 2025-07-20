#ifndef STROBECONTROL_H_INCLUDED
#define STROBECONTROL_H_INCLUDED

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

void strobeControlEnable(bool enable);
void strobeControlSetDelayFor(uint32_t delayFor);
void strobeControlSetHoldFor(uint32_t holdFor);
uint32_t strobeControlGetDelayFor();
uint32_t strobeControlGetHoldFor();
void strobeControlConstant(bool enable);


#ifdef __cplusplus
}
#endif

#endif /* STROBECONTROL_H_INCLUDED */
