#include "busErrorCounter.h"

// bus error counter ci
static const int CI_ERROR_COUNTER_A_READ = 0;
static const int CI_ERROR_COUNTER_A_RESET = 1;

uint32_t busErrorCounterGet(){
  uint32_t counter = 0;
  asm volatile("l.nios_rrr %[res],%[ra],r0,0xA" : [res] "=r"(counter) : [ra] "r"(CI_ERROR_COUNTER_A_READ));
  return counter;
}

void busErrorCounterReset(){
  asm volatile("l.nios_rrr r0,%[ra],r0,0xA" :: [ra] "r"(CI_ERROR_COUNTER_A_RESET));
}
