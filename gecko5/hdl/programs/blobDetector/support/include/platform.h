#ifndef PLATFORM_H_INCLUDED
#define PLATFORM_H_INCLUDED

#ifdef __cplusplus
extern "C" {
#endif

#define UART0_BASE 0x50000000
#define UART1_BASE 0x50000010

#define IO_UART_BASE UART0_BASE

void platform_init();

#ifdef __cplusplus
}
#endif

#endif /* PLATFORM_H_INCLUDED */
