#include "strobeControl.h"

// strobe control ci
static const int CI_STROBE_CONTROL_A_ENABLE_STROBE = 0;
static const int CI_STROBE_CONTROL_A_SET_DELAY_FOR = 1;
static const int CI_STROBE_CONTROL_A_SET_HOLD_FOR = 2;
static const int CI_STROBE_CONTROL_A_GET_DELAY_FOR = 3;
static const int CI_STROBE_CONTROL_A_GET_HOLD_FOR = 4;
static const int CI_STROBE_CONTROL_A_ENABLE_CONSTANT = 5;

void strobeControlEnable(bool enable){
  asm volatile("l.nios_rrr r0,%[ra],%[rb],0xE" ::[ra] "r"(CI_STROBE_CONTROL_A_ENABLE_STROBE), [rb] "r"(enable));
}

void strobeControlSetDelayFor(uint32_t delayFor){
  asm volatile("l.nios_rrr r0,%[ra],%[rb],0xE" ::[ra] "r"(CI_STROBE_CONTROL_A_SET_DELAY_FOR), [rb] "r"(delayFor));
}

void strobeControlSetHoldFor(uint32_t holdFor){
  asm volatile("l.nios_rrr r0,%[ra],%[rb],0xE" ::[ra] "r"(CI_STROBE_CONTROL_A_SET_HOLD_FOR), [rb] "r"(holdFor));
}

uint32_t strobeControlGetDelayFor(){
  uint32_t delayFor = 0;
  asm volatile("l.nios_rrr %[res],%[ra],r0,0xE" : [res] "=r"(delayFor) : [ra] "r"(CI_STROBE_CONTROL_A_GET_DELAY_FOR));
  return delayFor;
}

uint32_t strobeControlGetHoldFor(){
  uint32_t holdFor = 0;
  asm volatile("l.nios_rrr %[res],%[ra],r0,0xE" : [res] "=r"(holdFor) : [ra] "r"(CI_STROBE_CONTROL_A_GET_HOLD_FOR));
  return holdFor;
}

void strobeControlConstant(bool enable){
  asm volatile("l.nios_rrr r0,%[ra],%[rb],0xE" ::[ra] "r"(CI_STROBE_CONTROL_A_ENABLE_CONSTANT), [rb] "r"(enable));
}
