#ifndef __VGA_PRINT_H__
#define __VGA_PRINT_H__

#define CLEAR_SCREEN 3
#define TEXT_OFFSET 6

#define vgaClear() asm volatile ("l.nios_crr r0,%[in1],r0,0x0"::[in1]"r"(CLEAR_SCREEN));
#define vgaTextCorrection(value) asm volatile ("l.nios_crr r0,%[in2],%[in1],0x0"::[in1]"r"(value),[in2]"r"(TEXT_OFFSET));
void vgaPrintChar( unsigned char kar );

#endif
