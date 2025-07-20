#ifndef VISIONADDON_APP_UTILS_LOG_H
#define VISIONADDON_APP_UTILS_LOG_H

#include "c_log.h"

#include "lwip/api.h"
#include "utils/mutex/Mutex.h"
#include "utils/pool/CyclicPool.h"

#include <cstdint>
#include <memory>
#include <stdarg.h>
#include <stdio.h>


// DISCLAIMER: this class is not thread safe ... log output might get mangled
// TODO: set system time

class Log final {
public:
    Log() = delete;
    Log (const Log&) = delete;
    Log& operator=(const Log&) = delete;
    Log (const Log&&) = delete;
    Log& operator=(const Log&&) = delete;

    // avoid functional header because of conflict with lwip bind macro
    using TickKeeper = uint32_t (*)(void);
    static void registerTickKeeper(TickKeeper tickKeeper); //!< TickKeeper returns system ticks
    static void setTickrate(uint32_t ticksPerMs);
    enum Level : uint8_t {
        LOG_TRACE = 0,
        LOG_DEBUG = 1,
        LOG_INFO = 2,
        LOG_WARNING = 3,
        LOG_ERROR = 4,
        LOG_UNDEFINED = UINT8_MAX,
    };
    static Level toLevel(uint8_t);
    static void level(Level level);
    static Level level() {return _level;};

    static void trace(const char* format, ...); //!< log message with severity trace
    static void debug(const char* format, ...); //!< log message with severity debug
    static void info(const char* format, ...); //!< log message with severity info
    static void warning(const char* format, ...); //!< log message with severity warning
    static void error(const char* format, ...); //!< log message with severity error

    static void _vaListTrace(const char* format, va_list arglist);  //!< Do not use as entry point! Used by C-interface
    static void _vaListDebug(const char* format, va_list arglist);  //!< Do not use as entry point! Used by C-interface
    static void _vaListInfo(const char* format, va_list arglist);  //!< Do not use as entry point! Used by C-interface
    static void _vaListWarning(const char* format, va_list arglist);  //!< Do not use as entry point! Used by C-interface
    static void _vaListError(const char* format, va_list arglist);  //!< Do not use as entry point! Used by C-interface
private:
    static void log(const char* logPrefix, const char* format, va_list arglist);
    static void publishSwo(const char* p, int len);
    static void publishUdp(const char* p, int len);
    static const char* getTime();
    static TickKeeper _getTicks;
    static uint32_t _ticksPerMs;
    static constexpr size_t _TIMESTAMP_BUFFER_SIZE {sizeof("YYYY-MM-DD HH:MM:SS.mmm") + 1}; // + null terminator
    static char _timestampBuffer[_TIMESTAMP_BUFFER_SIZE];
    static Level _level;
    static struct sockaddr_in _socketAddr;
    static constexpr size_t _BUFFER_SIZE {512};
    static char _buffer[_BUFFER_SIZE];
};

#endif //VISIONADDON_APP_UTILS_LOG_H