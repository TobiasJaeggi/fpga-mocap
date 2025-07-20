#include "uart.h"

int GetHexRS232(unsigned char initial) {
   int result = 0;
   unsigned char kar;
   if ((initial >= '0')&&(initial <= '9'))
      result = initial-'0';
   if ((initial >= 'A')&&(initial <= 'F'))
      result = initial-'A'+10;
   if ((initial >= 'a')&&(initial <= 'f'))
      result = initial-'a'+10;
   do {
      kar = get_rs232_blocking();
      if ((kar >= '0')&&(kar <= '9')){
         result <<= 4;
         result += kar-'0';
      }
      if ((kar >= 'A')&&(kar <= 'F')) {
         result <<= 4;
         result += kar-'A'+10;
      }
      if ((kar >= 'a')&&(kar <= 'f')) {
         result <<= 4;
         result += kar-'a'+10;
      }
   } while (((kar >= '0')&&(kar <= '9'))||
            ((kar >= 'A')&&(kar <= 'F'))||
            ((kar >= 'a')&&(kar <= 'f')));
   return result;
}

void init_rs232() {
   volatile unsigned char *rs232;
   unsigned int loop,old,result;
   rs232 = (unsigned char *)UART_BASE;
   rs232[LINE_CONTROL_REGISTER] = CL_8_BITS|CL_1_STOP|CL_NO_PARITY|CL_DLAB;
   rs232[0] = SPEED_115200_LOW;
   rs232[1] = SPEED_115200_HIGH;
   rs232[LINE_CONTROL_REGISTER] = CL_8_BITS|CL_1_STOP|CL_NO_PARITY;
}

void sendRs232Char(unsigned char kar) {
   volatile unsigned char *rs232;
   rs232 = (unsigned char *)UART_BASE;
   while ((rs232[LINE_STATUS_REGISTER]&TX_EMPTY_MASK)==0) {
      asm volatile("l.nop");
   }
   rs232[0] = kar;
}

unsigned char get_rs232_blocking() {
   volatile unsigned char *rs232;
   unsigned char kar;
   rs232 = (unsigned char *)UART_BASE;
   do {
     kar = rs232[LINE_STATUS_REGISTER];
   } while ((kar & RX_AVAILABLE_MASK)==0);
   return rs232[0];
}
