#include <rtc.h>
#include <stdio.h>

#define i2cReadAddress  0xD1000000
#define i2cWriteAddress 0xD0000000

int readRtcRegister( int reg ) {
  volatile int value, result, retry;
  retry = 0;
  value = i2cReadAddress | (reg &0xFF) << 8;
  do {
      asm volatile ("l.nios_rrc %[out1],%[in1],r0,0x5":[out1]"=r"(result):[in1]"r"(value));
      retry++;
  } while (retry < 4 && (result & 0x80000000) != 0);
  return result;
}

void writeRtcRegister(int reg , int value) {
  int val = i2cWriteAddress | ((reg&0xFF) << 8) | (value&0xFF);
  asm volatile ("l.nios_rrc r0,%[in1],r0,0x5"::[in1]"r"(val));
}

void printTimeComplete() {
  int old,new;
  old = new = readRtcRegister(0);
  do {
    new = readRtcRegister(0);
    if (old != new) {
      printf("%02X-%02X-20%02X %02X:%02X:%02X\n", readRtcRegister(4), readRtcRegister(5), readRtcRegister(6), readRtcRegister(2), readRtcRegister(1), new);
      old = new;
    }
  } while (1);
}
