.section .vectors,"ax"
.org 0x0
_error:
    .word       0xDEADBEEF
    l.nop
    l.j         _exception_handler
    l.nop
    l.j         _exception_handler
    l.nop
    l.j         _exception_handler
    l.nop
    l.j         _exception_handler
    l.nop
    l.j         _exception_handler
    l.nop
_start:
    l.movhi     r1,0x007F
    l.ori       r1,r1,0xFFFC # stack in SDRAM
#    l.movhi     r1,0xC000  
#    l.ori       r1,r1,0x1FFC  # stack in spm
    l.xor       r3,r0,r0
    l.jal       main
    l.xor       r4,r0,r0
_loop_end:
    l.j         _loop_end
    l.nop
_exception_handler:
    l.addi      r1,r1,-124
    l.sw        0x00(r1),r2
    l.sw        0x04(r1),r3
    l.sw        0x08(r1),r4
    l.sw        0x0C(r1),r5
    l.sw        0x10(r1),r6
    l.sw        0x14(r1),r7
    l.sw        0x18(r1),r8
    l.sw        0x1C(r1),r9
    l.sw        0x20(r1),r10
    l.sw        0x24(r1),r11
    l.sw        0x28(r1),r12
    l.sw        0x2C(r1),r13
    l.sw        0x30(r1),r14
    l.sw        0x34(r1),r15
    l.sw        0x38(r1),r16
    l.sw        0x3C(r1),r17
    l.sw        0x40(r1),r18
    l.sw        0x44(r1),r19
    l.sw        0x48(r1),r20
    l.sw        0x4C(r1),r21
    l.sw        0x50(r1),r22
    l.sw        0x54(r1),r23
    l.sw        0x58(r1),r24
    l.sw        0x5C(r1),r25
    l.sw        0x60(r1),r26
    l.sw        0x64(r1),r27
    l.sw        0x68(r1),r28
    l.sw        0x6C(r1),r29
    l.sw        0x70(r1),r30
    l.sw        0x74(r1),r31
    l.mfspr     r31,r0,0x12
    l.slli      r31,r31,2
    l.movhi     r30,hi(_vectors)
    l.ori       r30,r30,lo(_vectors)
    l.add       r30,r30,r31
    l.lwz       r31,0x0(r30)
    l.jalr      r31
    l.nop
    l.lwz       r2,0x00(r1)
    l.lwz       r3,0x04(r1)
    l.lwz       r4,0x08(r1)
    l.lwz       r5,0x0C(r1)
    l.lwz       r6,0x10(r1)
    l.lwz       r7,0x14(r1)
    l.lwz       r8,0x18(r1)
    l.lwz       r9,0x1C(r1)
    l.lwz       r10,0x20(r1)
    l.lwz       r11,0x24(r1)
    l.lwz       r12,0x28(r1)
    l.lwz       r13,0x2C(r1)
    l.lwz       r14,0x30(r1)
    l.lwz       r15,0x34(r1)
    l.lwz       r16,0x38(r1)
    l.lwz       r17,0x3C(r1)
    l.lwz       r18,0x40(r1)
    l.lwz       r19,0x44(r1)
    l.lwz       r20,0x48(r1)
    l.lwz       r21,0x4C(r1)
    l.lwz       r22,0x50(r1)
    l.lwz       r23,0x54(r1)
    l.lwz       r24,0x58(r1)
    l.lwz       r25,0x5C(r1)
    l.lwz       r26,0x60(r1)
    l.lwz       r27,0x64(r1)
    l.lwz       r28,0x68(r1)
    l.lwz       r29,0x6C(r1)
    l.lwz       r30,0x70(r1)
    l.lwz       r31,0x74(r1)
    l.addi      r1,r1,124
    l.rfe
    l.nop
.global _vectors
_vectors:
    .word       _start
    .word       i_cache_error_handler
    .word       d_cache_error_handler
    .word       external_interrupt_handler
    .word       illegal_instruction_handler
    .word       system_call_handler

