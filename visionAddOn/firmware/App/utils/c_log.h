#ifndef VISIONADDON_APP_UTILS_CLOG_H
#define VISIONADDON_APP_UTILS_CLOG_H

#ifdef __cplusplus
extern "C" {
#endif

void log_trace(const char* format, ...); //!< log message with severity trace
void log_debug(const char* format, ...); //!< log message with severity debug
void log_info(const char* format, ...); //!< log message with severity info
void log_warning(const char* format, ...); //!< log message with severity warning
void log_error(const char* format, ...); //!< log message with severity error

#ifdef __cplusplus
}
#endif

#endif //VISIONADDON_APP_UTILS_CLOG_H