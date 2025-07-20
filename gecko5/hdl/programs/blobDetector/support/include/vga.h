#ifndef VGA_H_INCLUDED
#define VGA_H_INCLUDED

#ifdef __cplusplus
extern "C" {
#endif

void vga_clear();
void vga_textcorr(unsigned int value);
void vga_putc(int c);
void vga_puts(const char* str);

#ifdef __cplusplus
}
#endif

#endif /* VGA_H_INCLUDED */
