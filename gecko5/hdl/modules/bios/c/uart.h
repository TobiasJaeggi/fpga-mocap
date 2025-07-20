#ifndef __UART_H__
#define __UART_H__

#define UART_BASE 0x50000000
#define LINE_CONTROL_REGISTER 3
#define MODEM_CONTROL_REGISTER 4
#define LINE_STATUS_REGISTER 5
#define INTERUPT_ENABLE_REGISTER (UART+1)

#define CL_5_BITS 0
#define CL_6_BITS 1
#define CL_7_BITS 2
#define CL_8_BITS 3

#define CL_1_STOP 0
#define CL_2_STOP 4

#define CL_NO_PARITY 0
#define CL_PARITY 8
#define CL_EVEN_PARITY 16
#define CL_STICKY_PARITY 32
#define CL_BREAK_CONTROL 64
#define CL_DLAB 128

#ifdef OR1420

#define SPEED_9600_LOW 0x87
#define SPEED_9600_HIGH 0x01
#define SPEED_4800_LOW 0x0D
#define SPEED_4800_HIGH 0x03
#define SPEED_38400_LOW 0x62
#define SPEED_38400_HIGH  0
#define SPEED_115200_LOW 0x28
#define SPEED_115200_HIGH  0

#else

#define SPEED_9600_LOW 0x17
#define SPEED_9600_HIGH 0x01
#define SPEED_4800_LOW 0x2E
#define SPEED_4800_HIGH 0x02
#define SPEED_38400_LOW 0x46
#define SPEED_38400_HIGH  0
#define SPEED_115200_LOW 0x17
#define SPEED_115200_HIGH  0

#endif

#define TX_EMPTY_MASK 0x40
#define RX_AVAILABLE_MASK 0x01
#define OVERRUN_ERROR 0x02

void init_rs232();
void send_rs232(unsigned char* str);
void sendRs232Char(unsigned char kar);
int GetHexRS232(unsigned char initial);
unsigned char get_rs232_blocking();
#endif
