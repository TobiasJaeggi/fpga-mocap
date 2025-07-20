/*==============================================================================
 * $RCSfile: read_elf.h,v $
 *
 * DESC    : OpenRisk 1300 single and multi-processor emulation platform on
 *           the UMPP Xilinx FPA based hardware
 *
 * EPFL    : LAP
 *
 * AUTHORS : T.J.H. Kluter and C. Favi
 *
 * CVS     : $Revision: 1.2 $
 *           $Date: 2009/05/14 10:30:15 $
 *           $Author: kluter $
 *           $Source: /home/lapcvs/projects/or1300/progs/utils/c/include/read_elf.h,v $
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
 *  $Log: read_elf.h,v $
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

#ifndef __READ_ELF_H__
#define __READ_ELF_H__

#include "elf.h"
#define EM_ARM   40                /* the identity of ARM processor on ELF format object files, though not a standard yet*/
#define EM_OR32  0x5C              /* the identity of the open risk processor family, not a standard yet*/
#define HEAP_INFO_ADDRESS (0x04000000+2040)
#define __NO_ADD_HEAP__

#include <stdint.h> /*for uint32_t*/
#include <stdio.h>
#include <stdlib.h>

typedef struct urlap_memory_segment
{
   uint32_t base_address;
   uint32_t block_size;
   char empty_data;
   char read_only;
   uint32_t *memory_content;
} urlap_memory_segment_t;

typedef struct urlap_memory_segments_chain
{
   urlap_memory_segment_t info;
   struct urlap_memory_segments_chain *next;
} urlap_memory_segments_chain_t;

typedef struct urlap_virtual_memory
{
    uint32_t entry_point;
    urlap_memory_segments_chain_t *memory_map;
} urlap_virtual_memory_t;

void free_virtual_memory_list( urlap_virtual_memory_t *root );
urlap_virtual_memory_t *get_virtual_memory_list( FILE *fpointer );

int read_elf_header( FILE *infile , Elf32_Ehdr *elf_header );
Elf32_Shdr **read_section_header_table( FILE *infile , Elf32_Ehdr elf_header );
char *read_section_header_string_table( FILE *infile , Elf32_Ehdr elf_header ,
                                        Elf32_Shdr ** section_table );
void set_output_endianness(unsigned char end);
#endif
