#include <stdio.h>
#include <string.h>
#include <swap.h>
#include <vga.h>
#include <assert.h>
#include <uart.h>
#include <platform.h>

#include "binarize.h"
#include "busErrorCounter.h"
#include "input.h"
#include "myLib.h"

uint32_t sequenceCounter = 0;
int main()
{
  platform_init();
  uart_init((volatile char *)UART1_BASE);
  vga_clear();

  uint32_t busErrorCounter = busErrorCounterGet();
  printf("bus error counter: 0x%08x\n", busErrorCounter);

  binarizeSetThreshold(128);

  uart_rx_flush((volatile char *)UART0_BASE);
  uart_rx_flush((volatile char *)UART1_BASE);

  while (true)
  {
    int res = handle_input((char *)UART0_BASE);
    if (res < 0)
    {
      printf("error parsing user input: %d\n", res);
    }
  
    res = handle_input((char *)UART1_BASE);
    if (res < 0)
    {
      printf("error parsing Vision Add-On input: %d\n", res);
    }

    busErrorCounter = busErrorCounterGet();
    if (busErrorCounter != 0)
    {
      printf("bus error counter: 0x%08x\n", busErrorCounter);
    }
  }
}