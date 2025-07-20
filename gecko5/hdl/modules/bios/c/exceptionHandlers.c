#include "or32Print.h"
#include "vgaPrint.h"
#include "uart.h"

#ifdef OR1420

void icache_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "I$ error!\n");
}

void dcache_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "D$ error\n");
}

void irq_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "irq\n");
}

void invalid_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "???\n");
}

void system_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "system!\n");
}

#else
void bus_error_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "bus error!\n");
}

void data_page_fault_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Data page fault\n");
}

void instruction_page_fault_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "i page fault\n");
}

void tick_timer_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "tick\n");
}

void allignment_exception_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "allign!\n");
}

void illegal_instruction_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "????\n");
}

void external_interrupt_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "ping\n");
}

void dtlb_miss_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "dtlb\n");
}

void itlb_miss_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "itlb\n");
}

void range_exception_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Range!\n");
}

void system_call_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Syscall\n");
}

void trap_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Trap!\n");
}

void break_point_handler() {
  or32PrintMultiple(&vgaPrintChar, &sendRs232Char, "Break\n");
}
#endif
