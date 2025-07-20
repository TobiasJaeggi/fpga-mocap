#ifndef UART_H_INCLUDED
#define UART_H_INCLUDED

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>


#define UART_LINE_CONTROL_REGISTER 3
#define UART_MODEM_CONTROL_REGISTER 4
#define UART_LINE_STATUS_REGISTER 5
#define UART_INTERUPT_ENABLE_REGISTER (UART + 1)  // todo: where is UART defined?

#define UART_CL_5_BITS 0
#define UART_CL_6_BITS 1
#define UART_CL_7_BITS 2
#define UART_CL_8_BITS 3

#define UART_CL_1_STOP 0
#define UART_CL_2_STOP 4

#define UART_CL_NO_PARITY 0
#define UART_CL_PARITY 8
#define UART_CL_EVEN_PARITY 16
#define UART_CL_STICKY_PARITY 32
#define UART_CL_BREAK_CONTROL 64
#define UART_CL_DLAB 128

#ifdef OR1420

#define UART_SPEED_9600_LO 0x87
#define UART_SPEED_9600_HI 0x01
#define UART_SPEED_4800_LO 0x0D
#define UART_SPEED_4800_HI 0x03
#define UART_SPEED_38400_LO 0x62
#define UART_SPEED_38400_HI  0
#define UART_SPEED_115200_LO 0x28
#define UART_SPEED_115200_HI  0

#else

#define UART_SPEED_9600_LO 0x17
#define UART_SPEED_9600_HI 0x01
#define UART_SPEED_4800_LO 0x2E
#define UART_SPEED_4800_HI 0x02
#define UART_SPEED_38400_LO 0x46
#define UART_SPEED_38400_HI  0
#define UART_SPEED_115200_LO 0x17
#define UART_SPEED_115200_HI  0

#endif

#define UART_TX_EMPTY_MASK 0x40
#define UART_RX_AVAILABLE_MASK 0x01
#define UART_OVERRUN_ERROR 0x02

// TODO make uart_init more flexible

void uart_init(volatile char* uart);
void uart_wait_rx(volatile char* uart);
void uart_wait_tx(volatile char* uart);
void uart_putc(volatile char* uart, int c);
void uart_puts(volatile char* uart, const char* str);
int uart_getc(volatile char* uart);
bool uart_rx_data_available(volatile char* uart);
void uart_rx_flush(volatile char* uart);

#ifdef __cplusplus
}
#endif

#endif /* UART_H_INCLUDED */
