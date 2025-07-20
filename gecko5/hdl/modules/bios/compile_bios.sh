#!/bin/bash
echo "#define compiledate \"Build version: $(date)\n\n\"" > ../c/date.h
or1k-elf-gcc -Os -nostartfiles -Wl,-Ttext=0xF0000000 -o bios ../c/crt0.S ../c/exceptionHandlers.c ../c/flash.c ../c/or32Print.c ../c/uart.c ../c/vgaPrint.c ../c/bios.c
../bin/biosgen8k -8k bios

