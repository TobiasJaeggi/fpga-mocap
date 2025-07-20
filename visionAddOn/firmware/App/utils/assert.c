#ifdef __cplusplus
extern "C" {
#endif

#include "utils/assert.h"
#include  "FreeRTOS.h"
#include "task.h"

void assert_handler(const char *file, int line) {
    taskDISABLE_INTERRUPTS();
    vTaskSuspendAll();
    log_error("[ASSERT] assertion failed in file: %s, line: %d", file, line);
    abort();
}

#ifdef __cplusplus
}
#endif
