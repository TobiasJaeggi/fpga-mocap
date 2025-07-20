#include "binarize.h"

// binarization ci
static const int CI_BIN_A_READ_THRESHOLD = 0;
static const int CI_BIN_A_WRITE_THRESHOLD = 1;

bool binarizeSetThreshold(uint32_t threshold){
  static const uint32_t THRESHOLD_MAX = 0xff; 
  if (threshold > THRESHOLD_MAX) {
    return false;
  }
  asm volatile ("l.nios_rrr r0,%[ra],%[rb],0xB"::[ra]"r"(CI_BIN_A_WRITE_THRESHOLD),[rb]"r"(threshold));
  return true;
}

uint32_t binarizeGetThreshold(){
    uint32_t threshold;
    asm volatile ("l.nios_rrr %[res],%[ra],r0,0xB":[res]"=r"(threshold):[ra]"r"(CI_BIN_A_READ_THRESHOLD));
    return threshold;
} 
