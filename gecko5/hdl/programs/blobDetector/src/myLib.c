#include "myLib.h"

int myAbs(int v)
{
  if (v >= 0)
  {
    return v;
  }
  else
  {
    return (v * (-1));
  }
}


// string must be terminated with ASCII_LF or ASCII_NUL
// first char can be +/- or start of digit
// returns false if a char is not in digit range
bool myAtoi(char *str, int *value)
{
  // based on https://www.geeksforgeeks.org/write-your-own-atoi/
  const uint8_t ASCII_NUL = 0; // '\0'
  const uint8_t ASCII_LF = 10;
  const uint8_t ASCII_NUM_START = 48; // '0'
  const uint8_t ASCII_NUM_END = 57;   // '9'
  *value = 0;
  int sign = 1;
  int i = 0;
  if (str[0] == '-')
  {
    sign = -1;
    i++;
  }
  else if (str[0] == '+')
  {
    sign = 1;
    i++;
  }
  for (; (str[i] != ASCII_LF) && (str[i] != ASCII_NUL); ++i)
  {
    if ((str[i] < ASCII_NUM_START) || (ASCII_NUM_END < str[i]))
    {
      return false;
    }
    *value = (*value) * 10 + str[i] - ASCII_NUM_START;
  }
  *value = sign * (*value);
  return true;
}

