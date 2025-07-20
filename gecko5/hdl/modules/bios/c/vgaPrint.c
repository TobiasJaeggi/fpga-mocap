#define FORE_GROUND_COLOR 0
#define BACK_GROUND_COLOR 1
#define WRITE_CHAR 2
#define CLEAR_SCREEN 3
#define TEXT_OFFSET 6

void vgaPrintChar( unsigned char kar ) {
  asm volatile ("l.nios_crr r0,%[in2],%[in1],0x0"::[in1]"r"(kar),[in2]"r"(WRITE_CHAR));
}

