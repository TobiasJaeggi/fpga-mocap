#include <vga.h>

#define VGA_FOREGROUND_COLOR 0
#define VGA_BACKGROUND_COLOR 1
#define VGA_WRITE_CHAR 2
#define VGA_CLEAR_SCREEN 3
#define VGA_TEXT_OFFSET 6

void vga_clear() {
    asm volatile("l.nios_crr r0,%[in1],r0,0x0" ::[in1] "r"(VGA_CLEAR_SCREEN));
}

void vga_textcorr(unsigned int value) {
    asm volatile("l.nios_crr r0,%[in2],%[in1],0x0" ::[in1] "r"(value), [in2] "r"(VGA_TEXT_OFFSET));
}

void vga_putc(int c) {
    asm volatile("l.nios_crr r0,%[in2],%[in1],0x0" ::[in1] "r"(c), [in2] "r"(VGA_WRITE_CHAR));
}

void vga_puts(const char* str) {
    while (*str)
        vga_putc(*str++);
}
