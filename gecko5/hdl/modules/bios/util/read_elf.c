/*==============================================================================
 * $RCSfile: read_elf.c,v $
 *
 * DESC    : OpenRisk 1300 single and multi-processor emulation platform on
 *           the UMPP Xilinx FPA based hardware
 *
 * EPFL    : LAP
 *
 * AUTHORS : T.J.H. Kluter and C. Favi
 *
 * CVS     : $Revision: 1.5 $
 *           $Date: 2009/11/13 08:58:06 $
 *           $Author: kluter $
 *           $Source: /home/lapcvs/projects/or1300/progs/utils/c/read_elf.c,v $
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
 *  $Log: read_elf.c,v $
 *  Revision 1.5  2009/11/13 08:58:06  kluter
 *  Changed power calculation to more realistic case.
 *
 *  Revision 1.4  2009/05/25 09:22:42  kluter
 *  Added support for the bios
 *
 *  Revision 1.3  2009/05/22 13:51:40  kluter
 *  Fixed heap end address.
 *  Dynamically writes the heap start and heap end addresses in little or big
 *  endian, depending on the endianess of the elf file.
 *
 *  Revision 1.2  2009/05/14 10:30:15  kluter
 *  Added heap start and end address calculation. These values are
 *  written to the end of the cacheable lock region.
 *
 *  Revision 1.1  2008/05/12 13:23:49  kluter
 *  Moved files to util directory
 *
 *  Revision 1.2  2008/02/22 15:54:36  kluter
 *  Added CVS header
 *
 *
 *============================================================================*/

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "read_elf.h"

static unsigned char file_format = 0;
static unsigned char output_endianness = ELFDATA2MSB; //default big-endian

/**
 * set_output_endianness
 *  use with ELFDATA2MSB for big-endian
 *  and      ELFDATA2LSB for little-endian
 */
void set_output_endianness(unsigned char end) {
  output_endianness = end;
  if(output_endianness == ELFDATA2MSB)
    printf("NOTE: Output endianness set to big-endian.\n");
  else
    printf("NOTE: Output endianness set to little-endian.\n");
}

unsigned int read_half( FILE* infile )
{
   unsigned int result = 0;
   if (file_format == ELFDATA2LSB)
   {
      result = fgetc(infile) | fgetc(infile)<<8;
   }
   else
   {
      result = fgetc(infile)<<8 | fgetc(infile);
   }
   return result;
}

unsigned int read_word( FILE* infile )
{
   unsigned int result = 0;
   if (file_format == ELFDATA2LSB)
   {
      result = fgetc(infile)| fgetc(infile)<<8 | fgetc(infile)<<16 | fgetc(infile)<<24;
   }
   else
   {
      result = fgetc(infile)<<24| fgetc(infile)<<16 | fgetc(infile)<<8 | fgetc(infile);
   }
   return result;
}


int read_elf_header( FILE *infile , Elf32_Ehdr *elf_header )
{
   int loop;

   for (loop = 0 ; loop < EI_NIDENT ; loop++)
      elf_header->e_ident[loop] = (unsigned char)fgetc( infile );
   
   
   if ((elf_header->e_ident[0] != ELFMAG0)||
       (elf_header->e_ident[1] != ELFMAG1)||
       (elf_header->e_ident[2] != ELFMAG2)||
       (elf_header->e_ident[3] != ELFMAG3))
   {
      printf( "File is not an ELF-formated file!\nEXITING!\n" );
      return -1;
   }
   switch (elf_header->e_ident[EI_DATA])
   {
      case ELFDATA2LSB : file_format = ELFDATA2LSB;
                         printf( "ELF file is little-endian formatted.\n" );
                         break;
      case ELFDATA2MSB : file_format = ELFDATA2MSB;
                         printf( "ELF file is big-endian formatted.\n" );
                         break;
      default          : printf( "Unknown ELF file format!\nEXITING!\n" );
                         return -1;
   }
   if (elf_header->e_ident[EI_CLASS] != ELFCLASS32)
   {
      printf( "File is not of type ELFCLASS32!\nEXITING!\n" );
      return -1;
   }
   
   elf_header->e_type = (Elf32_Half)read_half(infile);
   
   if (elf_header->e_type != ET_EXEC)
   {
      printf( "Choosen file is not a executable file!\nEXITING!\n");
      return -1;
   }
   
   elf_header->e_machine = (Elf32_Half)read_half(infile);
   
   if ((elf_header->e_machine != EM_ARM)&&
       (elf_header->e_machine != EM_OR32))
   {
      printf( "Choosen file is not an ARM or Open Risk executable file!\nEXITING!\n");
      printf( "0x%08X\n" , elf_header->e_machine );
      return -1;
   }
   



   if( output_endianness == ELFDATA2LSB )
     printf( "Writing resulting %s file in little-endian format.\n" ,
	     (elf_header->e_machine == EM_ARM) ? "ARM" : "OpenRisk" );
   else 
     printf( "Writing resulting %s file in big-endian format.\n" ,
	     (elf_header->e_machine == EM_ARM) ? "ARM" : "OpenRisk" );

   
   elf_header->e_version = (Elf32_Word)read_word(infile);
   
   if (elf_header->e_version != 1)
   {
      printf( "Unknown ELF version:%d!\nEXITING!\n" , elf_header->e_version);
      return -1;
   }
   elf_header->e_entry = (Elf32_Addr)read_word(infile);
   elf_header->e_phoff = (Elf32_Off)read_word(infile);
   elf_header->e_shoff = (Elf32_Off)read_word(infile);
   elf_header->e_flags = (Elf32_Word)read_word(infile);
   elf_header->e_ehsize = (Elf32_Half)read_half(infile);
   elf_header->e_phentsize = (Elf32_Half)read_half(infile);
   elf_header->e_phnum = (Elf32_Half)read_half(infile);
   elf_header->e_shentsize = (Elf32_Half)read_half(infile);
   elf_header->e_shnum = (Elf32_Half)read_half(infile);
   elf_header->e_shstrndx = (Elf32_Half)read_half(infile);
   
   
   return 0;
}

Elf32_Shdr *read_section_header_table_entry(FILE *infile)
{
   Elf32_Shdr *shdr;
   
   shdr = (Elf32_Shdr *)malloc( sizeof(Elf32_Shdr) );
   if (shdr == NULL)
      return NULL;

   shdr->sh_name  =    (Elf32_Word)read_word(infile); 
   shdr->sh_type  =    (Elf32_Word)read_word(infile);  
   shdr->sh_flags =    (Elf32_Word)read_word(infile); 
   shdr->sh_addr  =    (Elf32_Addr)read_word(infile); 
   shdr->sh_offset=    (Elf32_Off)read_word(infile); 
   shdr->sh_size  =    (Elf32_Word)read_word(infile); 
   shdr->sh_link  =    (Elf32_Word)read_word(infile); 
   shdr->sh_info  =    (Elf32_Word)read_word(infile);  
   shdr->sh_addralign= (Elf32_Word)read_word(infile); 
   shdr->sh_entsize =  (Elf32_Word)read_word(infile); 

   return shdr;
}

Elf32_Shdr **read_section_header_table( FILE *infile , Elf32_Ehdr elf_header )
{
   Elf32_Shdr **table;
   int loop,i;
   
   if (elf_header.e_shoff == 0)
      return NULL;
   table = (Elf32_Shdr **)malloc( elf_header.e_shnum * sizeof(Elf32_Shdr*) );
   if (table == NULL)
      return NULL;
   fseek( infile , elf_header.e_shoff , 0 );
   for (loop = 0 ; loop < elf_header.e_shnum ; loop++)
   {
      table[loop] = read_section_header_table_entry(infile);
      if (table[loop] == NULL)
      {
         for ( i = 0 ; i < loop ; i++)
            free( table[i] );
         free( table );
         return NULL;
      }
   }
   return table;
}

char *read_section_header_string_table( FILE *infile , Elf32_Ehdr elf_header ,
                                        Elf32_Shdr ** section_table )
{
   char *table;
   int loop,i;
   
   if (elf_header.e_shstrndx == SHN_UNDEF)
      return NULL;
   i = section_table[elf_header.e_shstrndx]->sh_size;
   fseek( infile , section_table[elf_header.e_shstrndx]->sh_offset , 0 );
   table = (char *) malloc( (i) * sizeof( char ) );
   assert( table != NULL );
   for (loop = 0 ; loop < i ; loop++)
      table[loop] = fgetc( infile );
   return table;
}

Elf32_Phdr *read_program_header_table_entry(FILE *infile)
{
   Elf32_Phdr *phdr;
   
   phdr = (Elf32_Phdr *)malloc( sizeof(Elf32_Phdr) );
   if (phdr == NULL)
      return NULL;

   phdr->p_type   = (Elf32_Word)read_word(infile);  
   phdr->p_offset = (Elf32_Off)read_word(infile); 
   phdr->p_vaddr  = (Elf32_Addr)read_word(infile); 
   phdr->p_paddr  = (Elf32_Addr)read_word(infile); 
   phdr->p_filesz = (Elf32_Word)read_word(infile); 
   phdr->p_memsz  = (Elf32_Word)read_word(infile); 
   phdr->p_flags  = (Elf32_Word)read_word(infile); 
   phdr->p_align  = (Elf32_Word)read_word(infile); 
   
   return phdr;
}

Elf32_Phdr **read_program_header_table( FILE *infile , Elf32_Ehdr elf_header )
{
   Elf32_Phdr **table;
   int loop,i;
   
   if (elf_header.e_phoff == 0)
      return NULL;
   table = (Elf32_Phdr **)malloc( elf_header.e_phnum * sizeof(Elf32_Phdr*) );
   if (table == NULL)
      return NULL;
   fseek( infile , elf_header.e_phoff , 0 );
   for (loop = 0 ; loop < elf_header.e_phnum ; loop++)
   {
      table[loop] = read_program_header_table_entry(infile);
      if (table[loop] == NULL)
      {
         for ( i = 0 ; i < loop ; i++)
            free( table[i] );
         free( table );
         return NULL;
      }
   }
   return table;
}

urlap_memory_segments_chain_t *determine_heap( urlap_virtual_memory_t *root ) {
   urlap_memory_segments_chain_t *return_ptr;
   uint32_t heap_start,heap_end;
   
#ifdef __NO_ADD_HEAP__
   return NULL;
#endif
   return_ptr = root->memory_map;
   
   if (return_ptr == NULL)
      return NULL;
   
   while (return_ptr->next != NULL)
      return_ptr = return_ptr->next;
   heap_end = 32*1024*1024-8*512-4;
   heap_start = return_ptr->info.base_address+(return_ptr->info.block_size<<2);
   if (heap_start > heap_end)
      return NULL;
   printf( "\nHeap start: 0x%08X\n" , heap_start );
   printf( "Heap end  : 0x%08X\n" , heap_end );
   printf( "Heap size : %d kB\n" , (heap_end-heap_start)/1024 );
   return_ptr = (urlap_memory_segments_chain_t *) malloc( 
                    sizeof(urlap_memory_segments_chain_t) );
   
   if (return_ptr == NULL)
   {
      printf( "ERROR! Cannot allocate memory!\n" );
      return NULL;
   }
   return_ptr->next = NULL;
   return_ptr->info.base_address = HEAP_INFO_ADDRESS;
   return_ptr->info.block_size = 2;
   return_ptr->info.empty_data = 0;
   return_ptr->info.read_only = 0;
   return_ptr->info.memory_content = (uint32_t *)malloc(2*sizeof(uint32_t));
   if (return_ptr->info.memory_content == NULL) {
      printf( "ERROR! Cannot allocate memory!\n" );
      free( return_ptr );
      return NULL;
   }
   if (output_endianness == ELFDATA2LSB) {
      return_ptr->info.memory_content[0] = heap_start;
      return_ptr->info.memory_content[1] = heap_end;
   } else {
      /* put the addresses in big endian format */
      return_ptr->info.memory_content[0] = (heap_start&0xFF) << 24;
      return_ptr->info.memory_content[0] |= ((heap_start>>8)&0xFF) << 16;
      return_ptr->info.memory_content[0] |= ((heap_start>>16)&0xFF) << 8;
      return_ptr->info.memory_content[0] |= ((heap_start>>24)&0xFF);
      return_ptr->info.memory_content[1] = (heap_end&0xFF) << 24;
      return_ptr->info.memory_content[1] |= ((heap_end>>8)&0xFF) << 16;
      return_ptr->info.memory_content[1] |= ((heap_end>>16)&0xFF) << 8;
      return_ptr->info.memory_content[1] |= ((heap_end>>24)&0xFF);
   }      
   printf( "Heap start address inserted at address : 0x%08X\n" , HEAP_INFO_ADDRESS );
   printf( "Heap end address inserted at address   : 0x%08X\n" , HEAP_INFO_ADDRESS+4 );
   return return_ptr;
}
                                               

urlap_memory_segments_chain_t *read_memory_segment( FILE *infile ,
                                                    Elf32_Phdr *phdr )
{
   urlap_memory_segments_chain_t *return_pointer,*empty_block;
   unsigned long int loop,block_size;
   unsigned int value;
   
   if (phdr == NULL)
   {
      printf( "ERROR! Empty phdr provided!\n" );
      return NULL;
   }
   if (phdr->p_type != PT_LOAD)
   {
      printf( "ERROR! Unsupported phdr type provided!\n" );
      return NULL;
   }
   return_pointer = (urlap_memory_segments_chain_t *) malloc( 
                    sizeof(urlap_memory_segments_chain_t) );
   if (return_pointer == NULL)
   {
      printf( "ERROR! Cannot allocate memory!\n" );
      return NULL;
   }
   return_pointer->next = NULL;
   return_pointer->info.base_address = phdr->p_vaddr;
   if (phdr->p_filesz != 0)
   {

     /* CFAVI quick hack for OR32 non conform program sections */
/*       if ((phdr->p_filesz % 4) != 0) */
/*       { */
/*          printf( "ERROR! Memory segment is not WORD aligned!\n" ); */
/*          free( return_pointer ); */
/*          return NULL; */
/*       } */
      return_pointer->info.block_size = (phdr->p_filesz / 4) + (phdr->p_filesz%4>0?1:0);
      /* CFAVI */
      return_pointer->info.empty_data = 0;
      return_pointer->info.read_only = 1;
      return_pointer->info.memory_content = (unsigned int *) malloc(
                                             return_pointer->info.block_size *
                                             sizeof (unsigned int));
      if (return_pointer->info.memory_content == NULL)
      {
         printf( "ERROR! Unable to allocate memory for virtual memory segment!\n" );
         free( return_pointer );
         return NULL;
      }
      fseek( infile , phdr->p_offset , 0 );
      for (loop = 0 ; loop < return_pointer->info.block_size ; loop++)
      {
         value = read_word(infile);


	 if( output_endianness == ELFDATA2LSB ) 
	   return_pointer->info.memory_content[loop] = value;
	 else 
	   return_pointer->info.memory_content[loop] = (((value&0xFF) << 24) |
							(((value>>8)&0xFF) << 16) |
							(((value>>16)&0xFF) << 8) |
							((value>>24)&0xFF));




      }
      if (phdr->p_filesz != phdr->p_memsz)
      {
         if (phdr->p_memsz < phdr->p_filesz)
         {
            printf( "ERROR! memsize < filesize!\n" );
            free( return_pointer->info.memory_content );
            free( return_pointer );
            return NULL;
         }
         block_size = phdr->p_memsz - phdr->p_filesz;
         if ((block_size % 4) != 0)
         {
            printf( "ERROR! Memory segment is not WORD aligned!\n" );
            free( return_pointer->info.memory_content );
            free( return_pointer );
            return NULL;
         }
         block_size /= 4;
         empty_block = (urlap_memory_segments_chain_t *) malloc( 
                        sizeof(urlap_memory_segments_chain_t) );
         if (empty_block == NULL)
         {
            printf( "ERROR! Cannot allocate memory!\n" );
            free( return_pointer->info.memory_content );
            free( return_pointer );
            return NULL;
         }
         return_pointer->next = empty_block;
         empty_block->next = NULL;
         empty_block->info.base_address = return_pointer->info.base_address +
                                          (return_pointer->info.block_size << 2);
         empty_block->info.block_size = block_size;
         empty_block->info.empty_data = 1;
         empty_block->info.read_only = 0;
         empty_block->info.memory_content = (unsigned int *)malloc(
                                            block_size *
                                            sizeof( unsigned int ) );
         if (empty_block->info.memory_content == NULL)
         {
            printf( "ERROR! Cannot allocate memory!\n" );
            free( empty_block );
            free( return_pointer->info.memory_content );
            free( return_pointer );
            return NULL;
         }
         for (loop = 0 ; loop < block_size ; loop++)
            empty_block->info.memory_content[loop] = 0;
      }
   }
   else
   {
      if ((phdr->p_memsz % 4) != 0)
      {
         printf( "ERROR! Memory segment is not WORD aligned!\n" );
         free( return_pointer );
         return NULL;
      }
      return_pointer->info.block_size = phdr->p_memsz / 4;
      return_pointer->info.empty_data = 1;
      return_pointer->info.read_only = 0;
      return_pointer->info.memory_content = (unsigned int *) malloc(
                                             return_pointer->info.block_size *
                                             sizeof (unsigned int));
      if (return_pointer->info.memory_content == NULL)
      {
         printf( "ERROR! Unable to allocate memory for virtual memory segment!\n" );
         free( return_pointer );
         return NULL;
      }
      for (loop = 0 ; loop < return_pointer->info.block_size ; loop++)
         return_pointer->info.memory_content[loop] = 0;
   }
   return return_pointer;
};

void insert_sorted_into_list( urlap_virtual_memory_t *root ,
                              urlap_memory_segments_chain_t *entry )
{
   urlap_memory_segments_chain_t *current_entry;
   
   if (root->memory_map == NULL)
   {
      root->memory_map = entry;
   }
   else
   {
      if (entry->info.base_address < root->memory_map->info.base_address)
      {
         if (entry->next != NULL)
            entry->next->next = root->memory_map;
         else
            entry->next = root->memory_map;
         root->memory_map = entry;
      }
      else
      {
         current_entry = root->memory_map;
         while ((current_entry != NULL)&&(current_entry->next != NULL))
         {
            if (current_entry->next->info.base_address >
                entry->info.base_address )
            {
               if (entry->next != NULL)
                  entry->next->next = current_entry->next;
               else
                  entry->next = current_entry->next;
               current_entry->next = entry;
               current_entry = NULL;
            }
            else
               current_entry = current_entry->next;
         }
         if (current_entry != NULL)
            current_entry->next = entry;
      }
   }
}

void free_virtual_memory_list( urlap_virtual_memory_t *root )
{
   urlap_memory_segments_chain_t *current_entry;
   
   if (root == NULL)
      return;
   
   while (root->memory_map != NULL)
   {
      current_entry = root->memory_map;
      root->memory_map = root->memory_map->next;
      if (current_entry->info.memory_content != NULL)
         free( current_entry->info.memory_content );
      free( current_entry );
   }
   free( root );
}

urlap_virtual_memory_t *get_virtual_memory_list( FILE *fpointer )
{
   Elf32_Ehdr elf_header;
   urlap_virtual_memory_t *mem_root;
   urlap_memory_segments_chain_t *new_entry;
   Elf32_Phdr **program_table;
   Elf32_Word loop;

   mem_root = NULL;
   
   if (read_elf_header( fpointer , &elf_header ) != 0)
   {
      printf( "ERROR! Cannot read elf header!\n" );
      return NULL;
   }
   program_table = read_program_header_table( fpointer , elf_header );
   if (program_table == NULL)
   {
      printf( "STRANGE, the file has no program table!\n" );
      return NULL;
   }
   
   mem_root = (urlap_virtual_memory_t *)malloc( sizeof( urlap_virtual_memory_t));
   if (mem_root == NULL)
   {
      printf( "ERROR! Cannot allocate memory!\n" );
      return NULL;
   }
   
   mem_root->entry_point = elf_header.e_entry;
   mem_root->memory_map = NULL;
   
   for (loop = 0 ; loop < elf_header.e_phnum ; loop++)
   {
      new_entry = read_memory_segment( fpointer , program_table[loop] );
      if (new_entry == NULL)
      {
         printf( "Strange, program header table entry contains no info!\n" );
         free_virtual_memory_list( mem_root );
         return NULL;
      }
      insert_sorted_into_list( mem_root , new_entry );
   }
   new_entry = determine_heap( mem_root );
   if (new_entry != NULL) {
      insert_sorted_into_list( mem_root , new_entry );
   }
      
   return mem_root;
}
