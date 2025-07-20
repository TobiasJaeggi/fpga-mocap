#include "or32Print.h"
#include "vgaPrint.h"
#include "uart.h"
#include "flash.h"
#include "date.h"
#include <stddef.h>

#define swapBytes( source , dest ) asm volatile ("l.nios_rrr %[out1],%[in1],r0,0x1":[out1]"=r"(dest):[in1]"r"(source));

void *memcpy(void *dest, const void *src, size_t len) {
  switch (__builtin_object_size(dest,0)) {
    case 1  : short *ds = dest;
              const short *ss = src;
              while (len--)
                *ds++ = *ss++;
              return dest;
    case 2  : int *di = dest;
              const int *si = src;
              while (len--)
                *di++ = *si++;
              return dest;
    default : char *d = dest;
              const char *s = src;
              while (len--)
                *d++ = *s++;
              return dest;
  }
}

void helpscreen() {
  const char *helpText[] =  {
    "Known RS232 commands:\n",
    "$  Start the program loaded in target\n",
    "*p Set programming mode (default)\n",
    "*v Set verification mode\n",
    "*i Show info on program in target\n",
    "*t Toggle target between SDRam (default) and Flash\n",
    "*m Perform simple SDRam memcheck\n",
    "*s Check SPI-flash chip\n",
    "*e Erase SPI-Flash chip\n",
    "*f Store program loaded in SDRAM to SPI-Flash\n",
    "*c Compare program loaded in SDRAM with SPI-Flash\n",
    "*h This helpscreen\n\n",
    0};
  unsigned int reg;
  vgaClear();
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "CS-476 Embedded System Design\n");
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Openrisc based virtual Prototype.\n");
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, compiledate);
  do {
    asm volatile ("l.nios_rrr %[out1],r0,r0,0x4":[out1]"=r"(reg));
  } while ((reg & 0xFFFFFF) == 0);
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "I am CPU %d of %d running at ", (reg&0xF), (reg >> 4)&0xF);
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "%d%d.%d%d MHz.\n\n", (reg >> 24)&0xF, (reg >> 20)&0xF, (reg >> 16)&0xF, (reg >> 12)&0xF );
  reg = 0;
  while (helpText[reg] != 0) {
    or32PrintMultiple(&vgaPrintChar, &sendRs232Char, (char *) helpText[reg++]);
  }
}

int bios() {
  volatile unsigned int supervisor;
  volatile unsigned int *sdram = (unsigned int *) 0;
  volatile unsigned int *softRom = (unsigned int *) 0xF0002000;
  volatile unsigned int *flash = (unsigned int *) FLASH_BASE;
  volatile unsigned int *target = (unsigned int *) 0;
  unsigned char kar, progmode;
  unsigned int max, addr, data, errorcount, count, value, address, reg, size, magic;
  progmode = 1;
  max = 0;

  init_rs232();
  helpscreen();
  do {
    kar = get_rs232_blocking();
    switch (kar) {
      case '#': or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Upload done\n");
                break;
      case '@': data = GetHexRS232(' ');
                address = (data &0xFFFFFF) >> 2;
                or32PrintMultiple(&vgaPrintChar, 0, "Downloading: set address = 0x%X\n", data);
                if (address == 0) max = 0;
                break;
      case '$': if (target[0] != 0xDEADBEEF) {
                  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Error, no program loaded!\n");
                } else {
                  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Executing loaded program...\n");
                  asm volatile ("l.jumps");
                }
                break;
      case '*': kar = get_rs232_blocking();
                switch (kar) {
                  case 'h': or32PrintMultiple(&sendRs232Char, 0, "\n\n");
                            helpscreen();
                            break;
                  case 's': checkFlash();
                            break;
                  case 'd': for (addr = 0 ; addr < max; addr++) {
                              if ((addr%8) == 0) or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "\n");
                              or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "0x%X ", target[addr]);
                            }
                            or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "\n");
                            break;
                  case 'p': or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Setting prog. mode\n");
                            progmode = 1;
                            break;
                  case 'v': or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Setting verif. mode\n");
                            progmode = 0;
                            break;
                  case 'i': if (target[0] != 0xDEADBEEF) {
                              or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "No program present\n", 0 , target[1]); 
                            } else {
                              or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Program in mem from 0x%X to 0x%X\n", (unsigned int) target , 
                                                ((unsigned int) target | (target[1] <<2))-1 );
                            }
                            break;
                  case 't': if (target == sdram) {
                              or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Switched to Flash\n");
                              target = flash;
                            } else {
                              or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Switched to SDRam\n");
                              target = sdram;
                            }
                            max = 0;
                            break;
                  case 'c': if (target == flash) or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Please change to the SDRAM by *t\n");
                            else if (target[0] != 0xDEADBEEF) or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "No program loaded in SDRam!\n");
                            else if (target[1] >= 4*1024*1024) or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Program does not fit in Flash!\n");
                            else {
                              for (reg = 0; reg < sdram[1]; reg++) {
                                if (flash[reg] != sdram[reg]) {
                                  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Compare error at 0x%X : 0x%X != 0x%X\n", (reg << 2)|FLASH_BASE , flash[reg], sdram[reg] ); 
                                }
                              }
                              or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Compare done\n" );
                            }
                            break;
                  case 'f': if (target == flash) or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Please change to the SDRAM by *t\n");
                            else if (target[0] != 0xDEADBEEF) or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "No program loaded in SDRam!\n");
                            else if (target[1] >= 4*1024*1024) or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Program does not fit in Flash!\n");
                            else {
                              or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Checking if the flash is empty...\n"); 
                              for (reg = 0; reg < sdram[1]; reg++) {
                                if (flash[reg] != 0xFFFFFFFF) {
                                  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Start flash erase cycle for page 0x%X\n", reg<<2);
                                  flashErase(reg << 2);
                                }
                              }
                              or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Start programming flash\n" );
                              flashWrite((unsigned int *) sdram, sdram[1]);
                              or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Programming finished\n" );
                            }
                            break;
                  case 'e': or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Checking if flash is 'dirty'\n");
                            for (reg = 0; reg < 4*1024*1024; reg++) {
                              if (flash[reg] != 0xFFFFFFFF) {
                                or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Start flash erase cycle for page 0x%X\n", reg<<2);
                                flashErase(reg << 2);
                              }
                            }
                            or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Flash is empty (erased).\n\n");
                            break;
                  case 'y': asm volatile ("l.trap 15");
                            break;
                  case 'z': asm volatile ("l.sys 0xAA");
                            break;
                  case 'm': or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Starting simple SDRam memcheck.\n\n");
                            max = 0;
                            for (count = 0 ; count < 3 ; count ++) {
                              or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Writing...\n");
                              for (addr = 0; addr < 8*1024*1024; addr++) {
                                switch (count) {
                                  case 0 : value = 0xFFFFFFFF;
                                  case 1 : swapBytes(addr<<2, value);
                                  default: value = addr<<2;
                                }
                                sdram[addr] = value;
                              }
                              or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Verifying...\n");
                              errorcount = 0;
                              for (addr = 0; addr < 8*1024*1024; addr++) {
                                switch (count) {
                                  case 0 : value = 0xFFFFFFFF;
                                  case 1 : swapBytes(addr<<2, value);
                                  default: value = addr<<2;
                                }
                                if (sdram[addr] != value)
                                  if (errorcount++ < 30) or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Error @0x%X : 0x%X != 0x%X\n", addr << 2, sdram[addr], value );
                              }
                              if (errorcount > 0) {
                                or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Nr of errors found : %d\n", errorcount );
                                break;
                              }
                            }
                            or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Memcheck done, %d errors\n\n", errorcount);
                            break;
                  default : break;
                }
                break;
      default : if ( ((kar >= '0') && (kar <= '9')) ||
                     ((kar >= 'A') && (kar <= 'F')) ||
                     ((kar >= 'a') && (kar <= 'f')) ) {
                  data = GetHexRS232(kar);
                  if (target == flash && address == 0 && progmode == 1) {
                    or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Cannot program flash, aborting!\n");
                    address++;
                    break;
                  }
                  if (target == flash && address > 0 && progmode == 1) break;
                  if (progmode == 1) {
                    swapBytes(data, target[address]);
                  } else {
                    swapBytes(target[address], value);
                    if (value != data)
                      or32PrintMultiple(&vgaPrintChar, 0, "Verification error at 0x%X : 0x%X != 0x%X\n", address << 2 , value , data);
                  }
                  address++;
                  if (address > max) {
                    max = address;
                    target[1] = max;
                  }
                }
                break;
    }
  } while (1);
}
