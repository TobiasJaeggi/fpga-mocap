#ifndef EXCEPTION_H_INCLUDED
#define EXCEPTION_H_INCLUDED

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*exception_handler_t)(void);

enum {
    EXCEPTION_RESET,
    EXCEPTION_I_CACHE,
    EXCEPTION_D_CACHE,
    EXCEPTION_IRQ,
    EXCEPTION_ILLEGAL_INSTRUCTION,
    EXCEPTION_SYSTEM_CALL,
    EXCEPTION_COUNT
};

extern exception_handler_t _vectors[EXCEPTION_COUNT];

#define SYSCALL(n) \
    asm volatile("l.sys " #n::)

#ifdef __cplusplus
}
#endif

#endif /* EXCEPTION_H_INCLUDED */
