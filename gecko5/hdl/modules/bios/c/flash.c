#include "flash.h"
#include "or32Print.h"
#include "vgaPrint.h"
#include "uart.h"

#define swapBytes( source , dest ) asm volatile ("l.nios_rrc %[out1],%[in1],r0,0x1":[out1]"=r"(dest):[in1]"r"(source));

void flashBusyWait() {
   int value;
   do {
      asm volatile("l.nios_rrr %[out],%[in1],%[in2],0x2":[out]"=r"(value):[in1]"r"(0),[in2]"r"(7));
      value &= BUSY_FLAG;
   } while (value != 0);
}

int flashGetRegister(int index) {
   int value;
   asm volatile("l.nios_rrr %[out],%[in1],%[in2],0x2":[out]"=r"(value):[in1]"r"(0),[in2]"r"(index));
   return value;
}

void flashErase(unsigned int address) {
   asm volatile("l.nios_crr r0,%[in1],%[in2],0x2"::[in1]"r"(address),[in2]"r"(22));
   asm volatile("l.nios_crr r0,%[in1],%[in2],0x2"::[in1]"r"(START_ERASE),[in2]"r"(7));
   flashBusyWait();
}

void flashWrite(unsigned int *source, int nrOfWords) {
   int addr,loop;
   unsigned int data;
   for (addr = 0 ; addr < nrOfWords ; addr+=8) {
      asm volatile("l.nios_crr r0,%[in1],%[in2],0x2"::[in1]"r"(addr<<2),[in2]"r"(22));
      for (loop = 0 ; loop < 8 ; loop++) {
        swapBytes(source[addr+loop], data);
        asm volatile("l.nios_crr r0,%[in1],%[in2],0x2"::[in1]"r"(data),[in2]"r"(loop+24));
      }
      asm volatile("l.nios_crr r0,%[in1],%[in2],0x2"::[in1]"r"(START_WRITE),[in2]"r"(7));
      flashBusyWait();
   }
}

void checkFlash() {
   int i;
   unsigned int * flash = (unsigned int *)FLASH_BASE;
   unsigned int pagesize = 4*1024;
   unsigned int flashsize = 8*1024*1024;
   unsigned int lastStart = (flashsize-pagesize)>>2;
   unsigned int lastEnd = flashsize>>2;
   unsigned int erased = 0;
   unsigned int values[] = {0xDEADBEEF,0x1,0x2,0x3,0x4,0x5,0x6,0x7};
   unsigned int data;
   or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Checking last page of flash empty\n");
   for ( i = lastStart ; i < lastEnd ; i++ ) {
      if (flash[i] != 0xFFFFFFFF) {
         if (erased > 0) {
            or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Flash error!\n");
            return;
         }
         or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Erasing last page of Flash\n");
         erased ++;
         flashErase((int)&flash[i]);
         i = lastStart;
      }
   }
   or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Writing test sequence to flash.\n");
   for (i = 0 ; i < 8 ; i++) {
      swapBytes( values[i] , data )
      asm volatile("l.nios_crr r0,%[in1],%[in2],0x2"::[in1]"r"(data),[in2]"r"(i+24));
   }
   asm volatile("l.nios_crr r0,%[in1],%[in2],0x2"::[in1]"r"(lastStart<<2),[in2]"r"(22));
   asm volatile("l.nios_crr r0,%[in1],%[in2],0x2"::[in1]"r"(START_WRITE),[in2]"r"(7));
   flashBusyWait();
   or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Verifying test sequence from flash.\n");
   for (i = 0 ; i < 8 ; i++) {
      data = flash[lastStart+i];
      if (data != values[i]) {
         or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Test failed: %d : 0x%X /= 0x%X\n",i,data,values[i]);
         return;
      }
   }
   or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Flash test okay.\n\n");
}


