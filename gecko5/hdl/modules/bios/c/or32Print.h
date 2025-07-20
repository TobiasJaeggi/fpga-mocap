#ifndef OR32_PRINT_H
#define OR32_PRINT_H

// define a pointer function to the device that can output a character
typedef void (*char_output_provider)(unsigned char kar);

void or32Print( char_output_provider provider, char *format, ... );
void or32PrintMultiple(char_output_provider provider1, char_output_provider provider2, char *format, ... );

#endif
