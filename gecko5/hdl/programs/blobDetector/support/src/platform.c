#include <platform.h>

#include <uart.h>
#include <vga.h>

#include <stdio.h>

void platform_init() {
    uart_init((volatile char*)IO_UART_BASE);
}

// this is the link to printf
void _putchar(char c) {
    uart_putc((volatile char*)IO_UART_BASE, c);
    vga_putc(c);
}

int putchar(int c) {
    _putchar(c);
    return 0;
}

int puts(const char *s) {
    uart_puts((volatile char*)IO_UART_BASE, s);
    uart_putc((volatile char*)IO_UART_BASE, (int) '\n');

    vga_puts(s);
    vga_putc((int)'\n');
    return 0;
}

int getchar(void) {
    return uart_getc((volatile char*)IO_UART_BASE);
}
