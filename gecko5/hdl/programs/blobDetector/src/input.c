#include <platform.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <uart.h>

#include "input.h"
#include "binarize.h"
#include "cameraSelector.h"
#include "strobeControl.h"
#include "myLib.h"

int get_input(char * uartBase, char *inputString, const size_t maxLen)
{
  int index = 0;
  while (uart_rx_data_available(uartBase))
  {
    if (index >= maxLen)
    {
      uart_rx_flush(uartBase);
      return -1;
    }
    inputString[index] = uart_getc(uartBase);
    index++;
    // delay 100us which is greater than uart rate to make sure any pending chars are received and process in this loop
    // uart takes 10 cycles to transmit 1 byte
    // 115200 Hz  / 10 = 11.52 kHz
    // 1/(11.52 kHz) ~ 87 us -> 100us delay
    static const uint32_t DELAY_US = 100;
    asm volatile ("l.nios_rrc r0,%[in1],r0,0x6"::[in1]"r"(DELAY_US));

  }
  return index;
}

bool parse_bool(char b, bool* parsed){
  switch (b)
  {
  case '0':
    *parsed = false;
    return true;
  case '1':
    *parsed = true;
    return true;
  }  
  return false;
}

const char HELP_TEXT_HELP[] =
    "help text - 'h'\n"
    "  h - print help text\n";
const char HELP_TEXT_INPUT[] =
    "input selector - 'i'\n"
    "  io - ov9281 camera as input\n"
    "  is - fake static image as input\n"
    "  im - fake moving image as input\n";
const char HELP_TEXT_OUTPUT[] =
    "output selector - 'o'\n"
    "  or - raw image as output\n"
    "  ob - binary image as output\n";
const char HELP_TEXT_BIN_THRESHOLD[] =
    "bin threshold - 't'\n"
    "  t<value> - set bin threshold to <value>\n"
    "  <value>: [0-2^16-1]\n";
const char HELP_TEXT_STROBE_CONTROL[] =
    "strobe control - 's'\n"
    "  strobe trigger: camera vsync delayed for \"delay for\" then held for \"hold for\"\n"
    "  se<enable> - enable/disable strobe output\n"
    "  sd<value> - set \"delay for\" value to <value>\n"
    "  sh<value> - set \"hold for\" value to <value>\n"
    "  sc<enable> - enable/disable constant output\n"
    "  <enable>: [0-1], 0=disable, 1=enable\n"
    "  <value>: [0-2^32-1]\n";

int handle_input(char* uartBase)
{
  const size_t INPUT_STR_MAX_LEN = 16;
  char inputString[INPUT_STR_MAX_LEN];
  int inputLen = get_input(uartBase, inputString, INPUT_STR_MAX_LEN);
  if (inputLen == 0)
  {
    return INPUT_NO_DATA;
  }
  switch (inputString[0])
  {
  case 'i':
  {
    switch (inputString[1])
    {
    case 'o':
      cameraSelectorSetInput(CAM_SEL_IN_OV9281);
      break;
    case 's':
      cameraSelectorSetInput(CAM_SEL_IN_FAKE_STATIC);
      break;
    case 'm':
      cameraSelectorSetInput(CAM_SEL_IN_FAKE_MOVING);
      break;
    default:
      printf("unknown argument\n");
      uart_rx_flush(uartBase);
      printf(HELP_TEXT_INPUT);
      return INPUT_OPTION_INPUT_ERROR;
    }
  }
  break;
  case 'o':
  {
    switch (inputString[1])
    {
    case 'r':
      cameraSelectorSetOutput(CAM_SEL_OUT_RAW);
      break;
    case 'b':
      cameraSelectorSetOutput(CAM_SEL_OUT_BIN);
      break;
    default:
      printf("unknown argument\n");
      uart_rx_flush(uartBase);
      printf(HELP_TEXT_OUTPUT);
      return INPUT_OPTION_OUTPUT_ERROR;
    }
  }
  break;
  case 't':
  {
    int threshold = 0;
    if (!myAtoi(&inputString[1], &threshold))
    {
      uart_rx_flush(uartBase);
      printf("invalid threshold\n");
      printf(HELP_TEXT_BIN_THRESHOLD);
      return INPUT_OPTION_THRESHOLD_ERROR;
    }
    const uint8_t THRESHOLD_MIN = 0;
    const uint8_t THRESHOLD_MAX = 0xff; // refer to binarize.v
    if ((threshold < THRESHOLD_MIN) || (THRESHOLD_MAX < threshold))
    {
      uart_rx_flush(uartBase);
      printf("invalid threshold\n");
      printf(HELP_TEXT_BIN_THRESHOLD);
      return INPUT_OPTION_THRESHOLD_ERROR;
    }
    binarizeSetThreshold(threshold);
    printf("threshold set to : %d\n", binarizeGetThreshold());
  }
  break;
  case 's':
  {
    switch (inputString[1])
    {
    case 'e':
      bool enableStrobe = false;
      if(!parse_bool(inputString[2], &enableStrobe)){
        uart_rx_flush(uartBase);
        printf("unknown third argument\n");
        printf(HELP_TEXT_STROBE_CONTROL);
        return INPUT_OPTION_STROBE_CONTROL_ERROR;
      }
      strobeControlEnable(enableStrobe);
      printf("enable strobe set to : %d\n", enableStrobe);
      break;
    case 'd':
      int delayFor;
      if(!myAtoi(&inputString[2], &delayFor))
      {
        uart_rx_flush(uartBase);
        printf("unknown second argument\n");
        printf(HELP_TEXT_STROBE_CONTROL);
        return INPUT_OPTION_STROBE_CONTROL_ERROR;
      }
      strobeControlSetDelayFor(delayFor);
      printf("delay for set to : %d\n", strobeControlGetDelayFor());
      break;
    case 'h':
      int holdFor;
      if(!myAtoi(&inputString[2], &holdFor))
      {
        uart_rx_flush(uartBase);
        printf("unknown second argument\n");
        printf(HELP_TEXT_STROBE_CONTROL);
        return INPUT_OPTION_STROBE_CONTROL_ERROR;
      }
      strobeControlSetHoldFor(holdFor);
      printf("hold for set to : %d\n", strobeControlGetHoldFor());
      break;
    case 'c':
      bool enableConstant = false;
      if(!parse_bool(inputString[2], &enableConstant)){
        uart_rx_flush(uartBase);
        printf("unknown third argument\n");
        printf(HELP_TEXT_STROBE_CONTROL);
        return INPUT_OPTION_STROBE_CONTROL_ERROR;
      }
      strobeControlConstant(enableConstant);
      printf("enable constant set to : %d\n", enableConstant);
      break;
    default:
      printf("unknown argument\n");
      uart_rx_flush(uartBase);
      printf(HELP_TEXT_OUTPUT);
      return INPUT_OPTION_OUTPUT_ERROR;
    }
    break;
  }
  case 'h':
  {
    printf(HELP_TEXT_HELP);
    printf(HELP_TEXT_INPUT);
    printf(HELP_TEXT_OUTPUT);
    printf(HELP_TEXT_BIN_THRESHOLD);
    printf(HELP_TEXT_STROBE_CONTROL);
  }
  break;
  default:
  {
    uart_rx_flush(uartBase);
    printf("input unknown\n");
    printf(HELP_TEXT_HELP);
    return INPUT_OPTION_UNKNOWN;
  }
  }
  return INPUT_OK;
}