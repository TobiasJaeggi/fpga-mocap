#include <uart.h>

void uart_init(volatile char* uart) {
    uart[UART_LINE_CONTROL_REGISTER] = UART_CL_8_BITS | UART_CL_1_STOP | UART_CL_NO_PARITY | UART_CL_DLAB;
    uart[0] = UART_SPEED_115200_LO;
    uart[1] = UART_SPEED_115200_HI;
    uart[UART_LINE_CONTROL_REGISTER] = UART_CL_8_BITS | UART_CL_1_STOP | UART_CL_NO_PARITY;
}

void uart_wait_rx(volatile char* uart) {
    while ((uart[UART_LINE_STATUS_REGISTER] & UART_RX_AVAILABLE_MASK) == 0)
        asm volatile("l.nop");
}

void uart_wait_tx(volatile char* uart) {
    while ((uart[UART_LINE_STATUS_REGISTER] & UART_TX_EMPTY_MASK) == 0)
        asm volatile("l.nop");
}

void uart_putc(volatile char* uart, int c) {
    uart_wait_tx(uart);
    *uart = c;
}

void uart_puts(volatile char* uart, const char* str) {
    while (*str)
        uart_putc(uart, *str++);
}

int uart_getc(volatile char* uart) {
    uart_wait_rx(uart);
    return *uart;
}

bool uart_rx_data_available(volatile char* uart){
    return ((uart[UART_LINE_STATUS_REGISTER] & UART_RX_AVAILABLE_MASK) == 1);
}

void uart_rx_flush(volatile char* uart){
    while(uart_rx_data_available(uart)){
        uart_getc(uart);
    }
}