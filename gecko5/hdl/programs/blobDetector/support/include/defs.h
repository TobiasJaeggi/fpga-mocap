#ifndef DEFS_H_INCLUDED
#define DEFS_H_INCLUDED

#include <stddef.h>
#include <stdint.h>

/**
 * @brief Marks a function to be always inline.
 *
 */
#define __always_inline __attribute__((always_inline))

/**
 * @brief Defines a weak symbol.
 *
 */
#define __weak __attribute__((weak))

/**
 * @brief Marks a function to be static and inline.
 * 
 */
#define __static_inline static inline __always_inline

/**
 * @brief Disables the optimizations.
 * 
 */
#define __no_optimize __attribute__((optimize("O0")))

/**
 * @brief Defines a packed struct.
 * 
 */
#define __packed __attribute__((packed))

/**
 * @brief Alignment.
 * 
 */
#define __aligned(x) __attribute__((aligned(x)))

#define STRINGIZE_DETAIL(x) #x
#define STRINGIZE(x) STRINGIZE_DETAIL(x)

#endif /* DEFS_H_INCLUDED */
