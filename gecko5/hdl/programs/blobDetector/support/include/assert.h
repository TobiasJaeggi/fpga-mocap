#ifndef ASSERT_H_INCLUDED
#define ASSERT_H_INCLUDED

#include <defs.h>

#ifdef __cplusplus
extern "C" {
#endif

extern int (*assert_printf)(const char*, ...);
extern void assert_die();

#define die_if_not(expr, ...)                                                               \
    do {                                                                                    \
        if (!(expr)) {                                                                      \
            assert_printf(                                                                  \
                "[ ASSERT ] " #expr                                                         \
                " (from " __FILE__ ":" STRINGIZE(__LINE__) ")\n" __VA_OPT__(, ) __VA_ARGS__ \
            );                                                                              \
            assert_die();                                                                   \
        }                                                                                   \
    } while (0)

#ifndef NDEBUG
#define assert(...) die_if_not(__VA_ARGS__)
#else
#define assert
#endif

#ifdef __cplusplus
}
#endif

#endif /* ASSERT_H_INCLUDED */
