#include <stdio.h>
#include <defs.h>

__weak void i_cache_error_handler() {
    puts("I$ error!");
}

__weak void d_cache_error_handler() {
    puts("D$ error!");
}

__weak void illegal_instruction_handler() {
    puts("????");
}

__weak void external_interrupt_handler() {
    puts("ping");
}

__weak void system_call_handler() {
    puts("Syscall");
}

