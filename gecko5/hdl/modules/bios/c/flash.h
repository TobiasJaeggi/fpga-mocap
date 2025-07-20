#ifndef FLASH_H
#define FLASH_H

#define FLASH_BASE 0x04000000
#define BUSY_FLAG 1
#define WRITE_ERROR_FLAG 2
#define ERASE_ERROR_FLAG 4
#define BUTTON_MASK 8
#define START_ERASE 2
#define START_WRITE 1

void flashBusyWait();
int flashGetRegister(int index);
void flashErase(unsigned int address);
void flashWrite(unsigned int *source, int nrOfWords);
unsigned int flashChangeEndian( unsigned int data );
void checkFlash();
#endif
