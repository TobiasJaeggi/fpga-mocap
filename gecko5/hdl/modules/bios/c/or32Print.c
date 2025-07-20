#include <stdarg.h>
#include "or32Print.h"

void or32_print_hex(char_output_provider provider, unsigned int value ) {
   register unsigned char val;

   int loop,digit;
   for (loop = 28 ; loop >= 0 ; loop -= 4) {
      digit = (value >> loop)&0xF;
      if (digit < 10) {
         val = digit+'0';
      } else {
         val = digit - 10 + 'A';
      }
      (*provider)(val);
   }
}

void or32_print_dec(char_output_provider provider,  unsigned int value ) {
   unsigned char ascii[10];
   unsigned char nr_of_asciis;
   
   unsigned int current_result,loop;
   
   current_result = value;
   nr_of_asciis = 0;
   
   for (loop = 0 ; loop < 10 ; loop++) {
      ascii[loop] = (current_result%10)+'0';
      if ((loop == 0) ||
          (current_result != 0))
          nr_of_asciis++;
      current_result /= 10;
   }
   
   for (loop = nr_of_asciis ; loop > 0 ; loop--) {
      (*provider)(ascii[loop-1]);
   }
}

void or32PrintMultiple(char_output_provider provider1, char_output_provider provider2, char *format, ... ) {
   va_list ap;
   va_start(ap,format);
   char *c;
   unsigned char val = 0;
   unsigned int value;
   
   for ( c = format; *c != '\0' ; c++ ) {
      if (*c == '%') {
        c++;
        switch (*c) {
           case '\0' : val = '%';
                       (*provider1)(val);
                       if (provider2 != 0) (*provider2)(val);
                       return;
           case 'X'  : value = va_arg(ap,int);
                       or32_print_hex(provider1, value );
                       if (provider2 != 0) or32_print_hex(provider2, value );
                       break;
           case 'd'  : value = va_arg(ap,int);
                       or32_print_dec(provider1, value );
                       if (provider2 != 0) or32_print_dec(provider2, value );
                       break;
           case 'c'  : val = va_arg(ap,int);
                       (*provider1)(val);
                       if (provider2 != 0) (*provider2)(val);
                       return;
           default   : val = '%';
                       (*provider1)(val);
                       if (provider2 != 0) (*provider2)(val);
                       val = *c;
                       (*provider1)(val);
                       if (provider2 != 0) (*provider2)(val);
                       break;
        }
      } else {
         val = *c;
         (*provider1)(val);
         if (provider2 != 0) (*provider2)(val);
      }
   }
   va_end(ap);
}

