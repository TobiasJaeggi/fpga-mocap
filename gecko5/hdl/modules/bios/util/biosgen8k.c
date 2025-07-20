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

const char *help_text[] = 
  {"\n\n\nbiosgen help screen\n",
   "===========================\n\n",
   "This utility can be used to convert an ELF executable into a bios ucf,\n",
   "a simulation file for the bios module and a mem file for Xilinx \n", 
   "data2mem tool.\n",
   "The output files are bios.ucf, bram.simulation.vhdl and bios.mem in \n",
   "the current directory\n\n",
   "Command line usage:\n",
   "-------------------\n\n",
   "biosgen [-eb|-el] [-8k] <input filename>\n\n",
   "With:\n",
   "   -el => little endian output\n",
   "   -eb => big endian output (default) \n",
   "   -cl => clocked rom\n",
   "   -8k => generate the 8k bios files instead of 4k (default) \n",
   "   <input filename> => This is the name of the URLAP ARM ELF executable file\n",
   NULL };

void printBin( FILE *fpointer, unsigned int value ) {
  unsigned int mask = 1<<31;
  while (mask > 0) {
    fprintf( fpointer, ((mask&value) == 0) ? "0" : "1" );
    mask >>= 1;
  }
  fprintf( fpointer , "\n" );
}
 
char *input_filename = NULL;
char bios8k = 0;
int clocked = 0;
void helpscreen(int start_line)
{
  char loop; 
   
  for (loop = start_line ; help_text[loop] != NULL ; loop++)
    printf( help_text[loop] );
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
    } else if( strcmp(argv[i], "-cl") == 0) {
      clocked = 1;
    } else if( strcmp(argv[i], "-8k") == 0) {
      bios8k = 1;
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


void print_svn_header(FILE *fptr) {
   fprintf(fptr,"--------------------");
   fprintf(fptr,"--------------------");
   fprintf(fptr,"--------------------");
   fprintf(fptr,"--------------------\n");
   fprintf(fptr,"-- $RCSfile: $\n");
   fprintf(fptr,"--\n");
   fprintf(fptr,"-- DESC    : OpenRisk 1420 \n");
   fprintf(fptr,"--\n");
   fprintf(fptr,"-- AUTHOR  : Dr. Theo Kluter\n");
   fprintf(fptr,"--\n");
   fprintf(fptr,"-- CVS     : $Revision: $\n");
   fprintf(fptr,"--           $Date: $\n");
   fprintf(fptr,"--           $Author: $\n");
   fprintf(fptr,"--           $Source: $\n");
   fprintf(fptr,"--\n");
   fprintf(fptr,"--------------------");
   fprintf(fptr,"--------------------");
   fprintf(fptr,"--------------------");
   fprintf(fptr,"--------------------\n");
   fprintf(fptr,"--\n");
   fprintf(fptr,"--  HISTORY :\n");
   fprintf(fptr,"--\n");
   fprintf(fptr,"--  $Log: \n");
   fprintf(fptr,"--------------------");
   fprintf(fptr,"--------------------");
   fprintf(fptr,"--------------------");
   fprintf(fptr,"--------------------\n\n");
}

void fprint_bitmap( FILE *fptr,
                    int value,
                    int nrOfBits ) {
   int mask = (1<<(nrOfBits-1));
   while (mask != 0) {
      if ((value&mask)!= 0) 
         fprintf(fptr,"1");
      else
         fprintf(fptr,"0");
      mask >>=1;
   }
}

int main(int argc , char **argv)
{
  FILE *fpointer, *mem_pointer,*rom_pointer, *verilog_pointer, *memcont;
  urlap_virtual_memory_t *root;
  unsigned int loop,count,line,rom;
  char values[9][9];
  char *fname;
   
  input_filename = NULL;
   
  if (interpret_command_line_options( argc , argv ) != 0)
    return -1;
  fpointer = fopen( input_filename , "rb" );
  if (fpointer == NULL)
    {
      printf( "ERROR! Cannot open ARM ELF executable file:\n\"%s\"!\n" ,
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
  if (root->memory_map->next != NULL)
    {
      if ((root->memory_map->next->next != NULL) ||
	  (root->memory_map->next->info.empty_data == 0))
	{
	  printf( "This version does not support segmented programs!\n\n" );
	  free_virtual_memory_list( root );
	  return -1;
	}
    }
  loop = root->memory_map->info.block_size*4;
  if (loop > 0x1000 && bios8k == 0)
    {
      printf( "WARNING! Specified ELF-file is bigger than 4k byte (%d bytes),\n", loop);
      printf( "         This does not fit into the bios!\n\n" );
    }
  else if ( loop > 0x2000 && bios8k == 1)
    {
      printf( "WARNING! Specified ELF-file is bigger than 8k byte (%d bytes),\n", loop);
      printf( "         This does not fit into the bios!\n\n" );
    }
  fname = (char *)malloc( strlen(input_filename)+17 );
  strcpy(fname,input_filename);
  strcat(fname,"_rom-entity.vhdl");
  rom_pointer = fopen( fname , "w" );
  if (rom_pointer == NULL)
    {
      printf( "ERROR! Unable to create file:\n\"%s\"!\n",fname );
      free_virtual_memory_list( root );
      free(fname);
      return -1;
    }
  free(fname);
  fname = (char *)malloc( strlen(input_filename)+7 );
  strcpy(fname,input_filename);
  strcat(fname,"_rom.v");
  verilog_pointer = fopen( fname , "w" );
  if (verilog_pointer == NULL)
    {
      printf( "ERROR! Unable to create file:\n\"%s\"!\n",fname );
      free_virtual_memory_list( root );
      free(fname);
      return -1;
    }
  free(fname);
  fname = (char *)malloc( strlen(input_filename)+7 );
  strcpy(fname,input_filename);
  strcat(fname,"_rom.txt");
  memcont = fopen( fname , "w" );
  if (memcont == NULL)
    {
      printf( "ERROR! Unable to create file:\n\"%s\"!\n",fname );
      free_virtual_memory_list( root );
      free(fname);
      return -1;
    }
  free(fname);
  print_svn_header(rom_pointer);
  fprintf( rom_pointer , "LIBRARY ieee;\n" );
  fprintf( rom_pointer , "USE ieee.std_logic_1164.all;\n" );
  fprintf( rom_pointer , "USE ieee.numeric_std.all;\n\n" );
  fprintf( rom_pointer , "ENTITY bios_rom IS\n" );
  fprintf( rom_pointer , "   PORT ( address : IN  unsigned( %d DOWNTO 0 );\n" ,
              (bios8k == 1) ? 10 : 9 );
  fprintf( rom_pointer , 
              "          data    : OUT std_logic_vector(31 DOWNTO 0));\n");
  fprintf( rom_pointer , "END bios_rom;\n" );
  fclose( rom_pointer );
  fname = (char *)malloc( strlen(input_filename)+19 );
  strcpy(fname,input_filename);
  strcat(fname,"_rom-behavior.vhdl");
  rom_pointer = fopen( fname , "w" );
  if (rom_pointer == NULL)
    {
      printf( "ERROR! Unable to create file:\n\"%s\"!\n",fname );
      free_virtual_memory_list( root );
      free(fname);
      return -1;
    }
  free(fname);
  print_svn_header(rom_pointer);
  fprintf( verilog_pointer , "module biosRom ( input wire        clock,\n");
  fprintf( verilog_pointer , "                 input wire [%d:0] address,\n" , (bios8k == 1) ? 10 : 9 );
  fprintf( verilog_pointer , "                 output reg [31:0] romData);\n\n" );
  if (clocked == 1) fprintf( verilog_pointer , "  always @(negedge clock)\n" );
  else fprintf( verilog_pointer , "  always @*\n" );
  fprintf( verilog_pointer , "    case (address)\n" );
  fprintf( rom_pointer , 
             "ARCHITECTURE platform_independent OF bios_rom IS\n\n" );
  fprintf( rom_pointer , "BEGIN\n\n" );
  fprintf( rom_pointer , "   TheRom : PROCESS( address )\n" );
  fprintf( rom_pointer , "   BEGIN\n" );
  fprintf( rom_pointer , "      CASE (address) IS\n" );
  unsigned int mem_size = (bios8k == 1) ? 0x800: 0x400;
  for (loop = 0 ; loop < mem_size ; loop++ ) {
     if (loop < (unsigned int)root->memory_map->info.block_size) {
//        fprintf(memcont,"%08X\n" , root->memory_map->info.memory_content[loop]);
        printBin(memcont, root->memory_map->info.memory_content[loop]);
        if (root->memory_map->info.memory_content[loop] != 0) {
           fprintf( verilog_pointer , "      %d'b" , (bios8k == 1) ? 11 : 10 );
           fprint_bitmap( verilog_pointer , loop , (bios8k == 1) ? 11 : 10 );
           fprintf( verilog_pointer , " : romData <= 32'h%08X;\n" , (unsigned int)root->memory_map->info.memory_content[loop] );
           fprintf( rom_pointer , "         WHEN \"" );
           fprint_bitmap( rom_pointer , loop , (bios8k == 1) ? 11 : 10 );
           fprintf( rom_pointer , "\" => data <= X\"%08X\";\n" ,
                     (unsigned int)root->memory_map->info.memory_content[loop]);
        }
     }
  }
  fclose( memcont );
  fprintf( verilog_pointer , "      default : romData <= 32'd0;\n");
  fprintf( verilog_pointer , "    endcase\n\n");
  fprintf( verilog_pointer , "endmodule\n\n");
  fclose( verilog_pointer );
  fprintf( rom_pointer , "         WHEN OTHERS => data <= X\"00000000\";\n" );
  fprintf( rom_pointer , "      END CASE;\n" );
  fprintf( rom_pointer , "   END PROCESS TheRom;\n\n" );
  fprintf( rom_pointer , "END platform_independent;\n" );
  fclose( rom_pointer );
    
    

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
  count = 0;
  line = 0;
  rom = 0;

  printf("info.block_size = 0x%x\n",  (unsigned int)root->memory_map->info.block_size );
  mem_size = (unsigned int)root->memory_map->info.block_size;
  for (loop = 0 ; loop < mem_size ; loop++ )
    {
      if(loop % (0x800/4) == 0)
	fprintf( mem_pointer, "\n@%x\n", (loop/0x200)*0x800);


      if( loop < (unsigned int)root->memory_map->info.block_size ) {      
	sprintf( values[count] , "%08X" , (unsigned int)root->memory_map->info.memory_content[loop] );
	fprintf( mem_pointer, "%08X ", (unsigned int)root->memory_map->info.memory_content[loop] );
      } else {
	sprintf( values[count] , "%08X" , (unsigned int) 0);
	fprintf( mem_pointer, "%08X ", (unsigned int) 0 );
      }
      
      count++;
      if (count == 8)
	{


	  fprintf( mem_pointer, "\n" );
	  line++;
	  count = 0;
	}

      if (line == 0x40)
	{
	  line = 0;
	  rom++;
	}
      
    }

  printf( "Total program size (.text + .bss) = 0x%08X\n" , (unsigned int)root->memory_map->info.block_size*4 );
  fclose( mem_pointer );
  free_virtual_memory_list( root );
  return 0;
}
