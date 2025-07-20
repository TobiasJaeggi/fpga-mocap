#!/bin/bash
echo "#define compiledate \"Build version: $(date)\n\n\"" > ../c/date.h
or1k-elf-gcc -D OR1420 -msoft-div -Os -nostartfiles -Wl,-Ttext=0xF0000000 -o bios1 ../c/crt0.S ../c/exceptionHandlers.c ../c/flash.c ../c/or32Print.c ../c/uart.c ../c/vgaPrint.c ../c/bios1.c
../bin/biosgen8k -cl -8k bios1

