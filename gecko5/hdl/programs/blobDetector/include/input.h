#ifndef INPUT_H_INCLUDED
#define INPUT_H_INCLUDED

#ifdef __cplusplus
extern "C" {
#endif

static const int INPUT_NO_DATA = 1;
static const int INPUT_OK = 0;
static const int INPUT_OPTION_INPUT_ERROR = -1;
static const int INPUT_OPTION_OUTPUT_ERROR = -2;
static const int INPUT_OPTION_THRESHOLD_ERROR = -3;
static const int INPUT_OPTION_FRAME_TRANSFER_ERROR = -4;
static const int INPUT_OPTION_STROBE_CONTROL_ERROR = -5;
static const int INPUT_OPTION_UNKNOWN = -255;

int handle_input(char *uartBase);

#ifdef __cplusplus
}
#endif

#endif /* INPUT_H_INCLUDED */
