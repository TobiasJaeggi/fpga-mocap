#include <stdio.h>
#include <stdlib.h>


int main() {
  char codeTable[256][3];
  FILE* fpointer,*wpointer;
  int repeat = 1;
  char str[3];
  int bytecount = 0, count = 0;
  unsigned int data;
  
  fpointer = fopen("hello.elf.cmem","r");
  wpointer = fopen("control.mem","w");
  while (!feof(fpointer)) {
    char kar = fgetc(fpointer);
    switch (kar) {
      case '#': printf( "Upload done\n");
                break;
      case '&': kar = fgetc(fpointer);
                printf("Reading code table\n");
                int index = 0, karCnt;
                do {
                  while (kar == ' ') kar = fgetc(fpointer);
                  karCnt = 0;
                  do {
                    codeTable[index][karCnt++] = kar;
                    kar = fgetc(fpointer);
                  } while (kar != ' ');
                  codeTable[index][karCnt] = 0;
                  index++;
                } while (index < 256);
                break;
      case '@': unsigned int result = 0;
                do {
                  kar = fgetc(fpointer);
                  if ((kar >= '0')&&(kar <= '9')){
                    result <<= 4;
                    result += kar-'0';
                  }
                  if ((kar >= 'A')&&(kar <= 'F')) {
                    result <<= 4;
                    result += kar-'A'+10;
                  }
                  if ((kar >= 'a')&&(kar <= 'f')) {
                    result <<= 4;
                    result += kar-'a'+10;
                  }
                } while (((kar >= '0')&&(kar <= '9'))||
                         ((kar >= 'A')&&(kar <= 'F'))||
                         ((kar >= 'a')&&(kar <= 'f')));
                bytecount = 0;
                printf("Downloading: set address = 0x%X\n", result);
                fprintf(wpointer,"\n@%x\n", result);
                break;
      case '\r' :
      case '\n' :
      case ' '  : break;
      case '\'' : kar = fgetc(fpointer);
                  repeat = kar - '0';
                  kar = fgetc(fpointer);
                  repeat *= 10;
                  repeat += (kar - '0');
                  break;
      case '-':
      case '+':
      case '=': str[1] = fgetc(fpointer);
      default : str[0] = kar;
                int value = -1;
                for (int i = 0; i < 256; i++) {
                  if (str[0] == codeTable[i][0] && str[1] == codeTable[i][1]) {
                    value = i;
                    i = 256;
                  }
                }
                str[1] = 0;
                if (value < 0) {
                  printf("Unknown code!");
                } else {
                  while (repeat > 0) {
                    data = (bytecount == 0) ? 0 : data << 8;
                    data += value;
                    bytecount++;
                    if (bytecount == 4) {
                      fprintf(wpointer,"%08X ", data);
                      count++;
                      if (count >= 8) {
                        fprintf(wpointer,"\n");
                        count = 0;
                      }
                      bytecount = 0;
                    }
                    repeat --;
                  }
                  repeat = 1;
                }
                break;
    }
  }
  fclose(fpointer);
  fclose(wpointer);
}
