#ifndef VISIONADDON_APP_UTILS_ASSERT_H
#define VISIONADDON_APP_UTILS_ASSERT_H

// based on https://barrgroup.com/blog/how-define-your-own-assert-macro-embedded-systems

#ifdef __cplusplus
extern "C" {
#endif

#include "utils/c_log.h"

#include <stdlib.h>

#define ASSERT(expr) \
    if (!(expr)) \
        assert_handler(__FILE__, __LINE__)

void assert_handler(const char *file, int line);

#ifdef __cplusplus
}
#endif

#endif // VISIONADDON_APP_UTILS_ASSERT_H