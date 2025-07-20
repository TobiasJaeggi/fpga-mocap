/*==============================================================================
 * $RCSfile: biosgen8k.c,v $
 *
 * DESC    : OpenRisk 1300 single and multi-processor emulation platform on
 *           the UMPP Xilinx FPA based hardware
 *
 * EPFL    : LAP
 *
 * AUTHORS : T.J.H. Kluter and C. Favi
 *
 * CVS     : $Revision: 1.2 $
 *           $Date: 2009/02/15 17:54:58 $
 *           $Author: kluter $
 *           $Source: /home/lapcvs/projects/or1300/progs/utils/c/biosgen8k.c,v $
 *
 *==============================================================================
 *
 * Copyright (C) 2007/2008 Theo Kluter <ties.kluter@epfl.ch> EPFL-ISIM-LAP
 * Copyright (C) 2007/2008 Claudio Favi <claudio.favi@epfl.ch> EPFL-ISIM-GR-CH
 *
 *  This file is subject to the terms and conditions of the GNU General Public
 *  License.
 *
 *==============================================================================
 *
 *  HISTORY :
 *
 *  $Log: biosgen8k.c,v $
 *  Revision 1.2  2009/02/15 17:54:58  kluter
 *  Updated for sdram memory distance support
 *
 *  Revision 1.1  2008/05/12 13:23:49  kluter
 *  Moved files to util directory
 *
 *  Revision 1.2  2008/02/22 15:54:36  kluter
 *  Added CVS header
 *
 *
 *============================================================================*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "read_elf.h"

char* initialCodeTable[] = {
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s",
    "t", "u", "v", "w", "x", "y", "z", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L",
    "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "0", "1", "2", "3", "4",
    "5", "6", "7", "8", "9", "(", ")", "+a", "+b", "+c", "+d", "+e", "+f", "+g", "+h", "+i", "+j",
    "+k", "+l", "+m", "+n", "+o", "+p", "+q", "+r", "+s", "+t", "+u", "+v", "+w", "+x", "+y", "+z",
    "+A", "+B", "+C", "+D", "+E", "+F", "+G", "+H", "+I", "+J", "+K", "+L", "+M", "+N", "+O", "+P",
    "+Q", "+R", "+S", "+T", "+U", "+V", "+W", "+X", "+Y", "+Z", "+0", "+1", "+2", "+3", "+4", "+5",
    "+6", "+7", "+8", "+9", "+(", "+)", "-a", "-b", "-c", "-d", "-e", "-f", "-g", "-h", "-i", "-j",
    "-k", "-l", "-m", "-n", "-o", "-p", "-q", "-r", "-s", "-t", "-u", "-v", "-w", "-x", "-y", "-z",
    "-A", "-B", "-C", "-D", "-E", "-F", "-G", "-H", "-I", "-J", "-K", "-L", "-M", "-N", "-O", "-P",
    "-Q", "-R", "-S", "-T", "-U", "-V", "-W", "-X", "-Y", "-Z", "-0", "-1", "-2", "-3", "-4", "-5",
    "-6", "-7", "-8", "-9", "-(", "-)", "=a", "=b", "=c", "=d", "=e", "=f", "=g", "=h", "=i", "=j",
    "=k", "=l", "=m", "=n", "=o", "=p", "=q", "=r", "=s", "=t", "=u", "=v", "=w", "=x", "=y", "=z",
    "=A", "=B", "=C", "=D", "=E", "=F", "=G", "=H", "=I", "=J", "=K", "=L", "=M", "=N", "=O", "=P",
    "=Q", "=R", "=S", "=T", "=U", "=V", "=W", "=X", "=Y", "=Z", "=0", "=1", "=2", "=3", "=4", "=5",
    "=6", "=7", "=8", "=9", "=(", "=)"};

const char *help_text[] = 
  {"\n\n\nconvert_or32 help screen\n",
   "===========================\n\n",
   "This utility can be used to convert an ELF executable into \n",
   "a .mem file.\n", 
   "Command line usage:\n",
   "-------------------\n\n",
   "convert_or32 [-eb|-el] <input filename>\n\n",
   "With:\n",
   "   -el => little endian output\n",
   "   -eb => big endian output (default) \n"
   "   <input filename> => This is the name of the openRISC ELF executable file\n",
   NULL };
 
char *input_filename = NULL;
char bios8k = 0;
void helpscreen(int start_line)
{
  char loop; 
   
  for (loop = start_line ; help_text[loop] != NULL ; loop++)
    printf( "%s", help_text[loop] );
}

int interpret_command_line_options(int argc , char **argv)
{
  int i;

  if (argc < 2 ) {
    helpscreen(0);
    return -1;
  }

  for(i=1; i<argc;i++) {
    if( strcmp(argv[i], "-eb") == 0) {
      set_output_endianness(ELFDATA2MSB);
    } else if( strcmp(argv[i], "-el") == 0) {
      set_output_endianness(ELFDATA2LSB);
    } else {
      if (input_filename != NULL) {
	printf( "\n\n\"%s\"\n===>>> ERROR in command line usage detected!\n" ,
		argv[0] );
	printf( "       Multiple input file command line options specified!\n\n" );
	helpscreen(4);
	return -1;
      }
      input_filename = (char *)malloc( (strlen(argv[i])+1)*sizeof( char ) );
      if (input_filename == NULL) {
	printf( "\n\n\"%s\"\n===>>> ERROR! Cannot allocate memory\n       ABORTING!\n\n" ,
		argv[0] );
	return -1;
      }
      strcpy( input_filename , argv[i] );
    }
  }
  
  if (input_filename == NULL) {
    printf("ERROR! Missing filename!\n");
    helpscreen(4);
    return -1;
  }
  
  return 0;
}

void determineCodeTable(urlap_memory_segments_chain_t *data, char **codeTable) {
  long ocurances[256];
  int  index[256];
  urlap_memory_segments_chain_t *current = data;
  for (int i = 0; i < 256; i++) {
    ocurances[i] = 0;
    index[i] = i;
  }
  do {
    for (unsigned int loop = 0 ; loop < (unsigned int) current->info.block_size; loop++) {
      if (current->info.empty_data != 0) break;
      unsigned int value = (unsigned int)current->info.memory_content[loop];
      ocurances[value&0xFF]++;
      ocurances[(value>>8)&0xFF]++;
      ocurances[(value>>16)&0xFF]++;
      ocurances[(value>>24)&0xFF]++;
    }
    current = current->next;
  } while (current != NULL);
  int swapped = 1;
  while (swapped == 1) {
    swapped = 0;
    for (int i = 0 ; i < 255; i++) {
      if (ocurances[i] < ocurances[i+1]) {
        swapped = 1;
        int temp = index[i];
        index[i] = index[i+1];
        index[i+1] = temp;
        long temp1 = ocurances[i];
        ocurances[i] = ocurances[i+1];
        ocurances[i+1] = temp1;
      }
    }
  }
  for (int i = 0 ; i < 256; i++)
    codeTable[index[i]] = initialCodeTable[i];
}

int main(int argc , char **argv)
{
  FILE *fpointer, *mem_pointer, *cmem_pointer;
  urlap_virtual_memory_t *root;
  unsigned int loop,count,line,rom,baseAddress;
  char *fname;
  char *codeTable[256];
   
  input_filename = NULL;
   
  if (interpret_command_line_options( argc , argv ) != 0)
    return -1;
  fpointer = fopen( input_filename , "rb" );
  if (fpointer == NULL)
    {
      printf( "ERROR! Cannot open openRISC ELF executable file:\n\"%s\"!\n" ,
	      input_filename );
      return -1;
    }
  root = get_virtual_memory_list( fpointer );
  fclose( fpointer );
  if (root == NULL)
    {
      printf( "ERROR! The input file does not contain proper information!\n" );
      return -1;
    }
  printf( "\nWARNING: This version does not check for possible runtime errors\n" );
  printf( "         like stack heap collisions, memory range violations, etc.\n" );
  printf( "         It simply creates a ucf file!\n\n" );

  fname = (char *)malloc( strlen(input_filename)+5 );
  strcpy(fname,input_filename);
  strcat(fname,".mem");
  mem_pointer = fopen( fname, "wb" );
  if (mem_pointer == NULL)
    {
      printf( "ERROR! Unable to create file:\n\"%s\"!\n",fname );
      free_virtual_memory_list( root );
      free(fname);
      return -1;
    }
  free(fname);
  fname = (char *)malloc( strlen(input_filename)+6 );
  strcpy(fname,input_filename);
  strcat(fname,".cmem");
  cmem_pointer = fopen( fname, "wb" );
  if (cmem_pointer == NULL)
    {
      printf( "ERROR! Unable to create file:\n\"%s\"!\n",fname );
      free_virtual_memory_list( root );
      free(fname);
      return -1;
    }
  free(fname);

  urlap_memory_segments_chain_t *current = root->memory_map;
  determineCodeTable(current, codeTable);
  fprintf( cmem_pointer, "& ");
  for (int i = 0; i < 256; i++) {
    if (i==8) fprintf( cmem_pointer, "  " );
    fprintf( cmem_pointer, "%s ",codeTable[i]);
  }
  fprintf( cmem_pointer, "\n");
  do {
    count = 0;
    baseAddress = current->info.base_address;
    fprintf( cmem_pointer, "@%x\n", baseAddress);
    int lastvalue = -1;
    int repeatcount = 1;
    int linelength = 0;
    for (loop = 0; loop < (unsigned int) current->info.block_size; loop++) {
      if (current->info.empty_data != 0) break;
      int value = (unsigned int)current->info.memory_content[loop];
      if ((loop % 0x200) == 0)
        fprintf( mem_pointer, "\n@%x\n", (loop*4)+baseAddress);
      fprintf( mem_pointer, "%08X ", value);
      count++;
      if (count >= 8) {
        fprintf( mem_pointer, "\n" );
        count = 0;
      }
      int shiftAmount = 24;
      for (int byteCnt = 0; byteCnt < 4; byteCnt++) {
        int byte = (value >> shiftAmount)&0xFF;
        shiftAmount -= 8;
        if (byte == lastvalue) {
          if (repeatcount==99) {
            char str[256];
            sprintf( str, "'%02d%s", repeatcount, codeTable[lastvalue] );
            fprintf( cmem_pointer, "%s", str );
            linelength += strlen(str);
            repeatcount = 1;
          } else repeatcount++;
        } else {
          if (repeatcount > 1) {
            char str[256];
            sprintf( str, "'%02d%s", repeatcount, codeTable[lastvalue] );
            if (repeatcount <= 3) {
              int length = repeatcount*strlen(codeTable[lastvalue]);
              if (length < strlen(str)) {
                if (repeatcount == 2) 
                  sprintf( str, "%s%s", codeTable[lastvalue], codeTable[lastvalue] );
                else
                  sprintf( str, "%s%s%s", codeTable[lastvalue], codeTable[lastvalue], codeTable[lastvalue] );
              }
            }
            fprintf( cmem_pointer, "%s", str );
            linelength += strlen(str);
          } else {
            fprintf( cmem_pointer, "%s", codeTable[lastvalue] );
            linelength += strlen(codeTable[lastvalue]);
          }
          repeatcount = 1;
          lastvalue = byte;
        }
        if (linelength >= 80) {
          fprintf( cmem_pointer, "\n" );
          linelength = 0;
        }
      }
    }
    if (repeatcount > 1) {
      char str[256];
      sprintf( str, "'%02d%s", repeatcount, codeTable[lastvalue] );
      if (repeatcount <= 3) {
        int length = repeatcount*strlen(codeTable[lastvalue]);
        if (length < strlen(str)) {
          if (repeatcount == 2) 
            sprintf( str, "%s%s", codeTable[lastvalue], codeTable[lastvalue] );
          else
            sprintf( str, "%s%s%s", codeTable[lastvalue], codeTable[lastvalue], codeTable[lastvalue] );
        }
      }
      fprintf( cmem_pointer, "%s\n", str );
    } else {
      fprintf( cmem_pointer, "%s", codeTable[lastvalue] );
    }
    current = current->next;
  } while (current != NULL);

  fprintf( mem_pointer , "\n#\n");
  fprintf( cmem_pointer , "\n#\n");
  printf( "Done\n");
  fclose( mem_pointer );
  fclose( cmem_pointer );
  free_virtual_memory_list( root );
  return 0;
}
