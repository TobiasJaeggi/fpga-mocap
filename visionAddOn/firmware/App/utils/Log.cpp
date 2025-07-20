#include "Log.h"
#include "lwip.h"
#include "lwip/sockets.h"
#include "stm32f7xx_hal.h"
#include "utils/assert.h"
#include "utils/constants.h"

#include <cstdio>
#include <ctime>
#include <utility>

Log::TickKeeper Log::_getTicks = [](void) -> uint32_t {return 0U;};
uint32_t Log::_ticksPerMs {0U};
char Log::_timestampBuffer[Log::_TIMESTAMP_BUFFER_SIZE];
Log::Level Log::_level {Log::Level::LOG_DEBUG};
struct sockaddr_in Log::_socketAddr {sizeof(Log::_socketAddr), AF_INET,  htons(PORT_LOG), inet_addr(HOST_IP), 0};
char Log::_buffer[_BUFFER_SIZE] {};

Log::Level Log::toLevel(uint8_t level){
    switch (level)
    {
        case static_cast<uint8_t>(Log::Level::LOG_TRACE): return Log::Level::LOG_TRACE;
        case static_cast<uint8_t>(Log::Level::LOG_DEBUG): return Log::Level::LOG_DEBUG;
        case static_cast<uint8_t>(Log::Level::LOG_INFO): return Log::Level::LOG_INFO;
        case static_cast<uint8_t>(Log::Level::LOG_WARNING): return Log::Level::LOG_WARNING;
        case static_cast<uint8_t>(Log::Level::LOG_ERROR): return Log::Level::LOG_ERROR;
        default: return Log::Level::LOG_UNDEFINED;
    }
}

void Log::level(Log::Level level){
    if(level == Log::Level::LOG_UNDEFINED){
        Log::warning("[ROOT] cannot set undfined log level");
        return;
    }
    _level = level;
    Log::info("[ROOT] changed log level to %u", level);
}

const char* Log::getTime(){
    uint64_t totalMs = static_cast<uint64_t>(Log::_getTicks()) * Log::_ticksPerMs; // Ensure correct precision
    std::time_t timestampS = totalMs / MILLISECONDS_PER_SECOND;
    uint32_t timestampMs = totalMs % MILLISECONDS_PER_SECOND;

    // Convert to struct tm (UTC time)
    std::tm timeInfo{};
    gmtime_r(&timestampS, &timeInfo);  // Thread-safe version of gmtime()

    // Format time as "YYYY-MM-DD HH:MM:SS"
    std::strftime(_timestampBuffer, _TIMESTAMP_BUFFER_SIZE, "%Y-%m-%d %H:%M:%S", &timeInfo);

    // Print result with milliseconds
    std::snprintf(_timestampBuffer + 19, 5, ".%03lu", timestampMs);

    return _timestampBuffer;
}

void Log::log(const char* logPrefix, const char* format, va_list arglist) {
    int32_t writePointer {0};

    int32_t writeLength = std::snprintf(_buffer, _BUFFER_SIZE, "%s ", getTime());
    if(writeLength <= 0) { return; } // abort
    writePointer += writeLength;
    writeLength = std::snprintf(_buffer + writePointer, _BUFFER_SIZE, logPrefix);
    if(writeLength <= 0) { return; } // abort
    writePointer += writeLength;
    writeLength = vsnprintf(_buffer + writePointer, _BUFFER_SIZE - writePointer, format, arglist);
    if(writeLength <= 0) { return; } // abort
    writePointer += writeLength;
    writeLength = std::snprintf(_buffer + writePointer, _BUFFER_SIZE - writePointer, "\n");
    if(writeLength <= 0) { return; } // abort
    writePointer += writeLength;
    publishSwo(_buffer, writePointer);
    publishUdp(_buffer, writePointer);
}

void Log::_vaListTrace(const char* format, va_list arglist) {
    if(_level > Level::LOG_TRACE) {
        return;
    }
    log("\x1B[2;90mTRACE\x1B[2;0m ",format, arglist);

}

void Log::_vaListDebug(const char* format, va_list arglist) {
    if(_level > Level::LOG_DEBUG) {
        return;
    }
    log("\x1B[2;90mDEBUG\x1B[2;0m ",format, arglist);
}

void Log::_vaListInfo(const char* format, va_list arglist) {
    if(_level > Level::LOG_INFO) {
        return;
    }
    log("\x1B[2;0mINFO\x1B[2;0m ",format, arglist);
}

void Log::_vaListWarning(const char* format, va_list arglist) {
    if(_level > Level::LOG_WARNING) {
        return;
    }
    log("\x1B[1;33mWARN\x1B[2;0m ",format, arglist);
}

void Log::_vaListError(const char* format, va_list arglist) {
    if(_level > Level::LOG_ERROR) {
        return;
    }
    log("\x1B[1;31mERR\x1B[2;0m ",format, arglist);
}

void Log::registerTickKeeper(Log::TickKeeper tickKeeper){
   _getTicks = std::move(tickKeeper);
}

void Log::setTickrate(uint32_t ticksPerMs){
    _ticksPerMs = ticksPerMs;
}

void Log::trace(const char* format, ...) {
    va_list arglist;
    va_start(arglist, format);
    _vaListTrace(format, arglist);
    va_end(arglist);
}

void Log::debug(const char* format, ...) {
    va_list arglist;
    va_start(arglist, format);
    _vaListDebug(format, arglist);
    va_end(arglist);
}

void Log::info(const char* format, ...) {
    va_list arglist;
    va_start(arglist, format);
    _vaListInfo(format, arglist);
    va_end(arglist);
}

void Log::warning(const char* format, ...) {
    va_list arglist;
    va_start(arglist, format);
    _vaListWarning(format, arglist);
    va_end(arglist);
}

void Log::error(const char* format, ...) {
    va_list arglist;
    va_start(arglist, format);
    _vaListError(format, arglist);
    va_end(arglist);
}
 
void Log::publishSwo(const char* p, int len) {
    for (int i = 0; i < len; i++) {
        ITM_SendChar(p[i]);  // SWO output
    }
}

void Log::publishUdp(const char* p, int len) {
    int32_t udpSocket = lwip_socket(AF_INET, SOCK_DGRAM, 0);

    auto ret = lwip_connect(udpSocket, (struct sockaddr*)&_socketAddr, sizeof(_socketAddr));
    if(ret == 0) {
        auto r = lwip_write(udpSocket, (void*)p, len); // blocking!
        (void) r;
    }
    lwip_close(udpSocket);
}
// C interface

void log_trace(const char* format, ...){
    va_list arglist;
    va_start( arglist, format);
    Log::_vaListTrace(format, arglist);
    va_end(arglist);
}

void log_debug(const char* format, ...){
    va_list arglist;
    va_start( arglist, format);
    Log::_vaListDebug(format, arglist);
    va_end(arglist);
}

void log_info(const char* format, ...){
    va_list arglist;
    va_start( arglist, format);
    Log::_vaListInfo(format, arglist);
    va_end(arglist);
}

void log_warning(const char* format, ...){
    va_list arglist;
    va_start( arglist, format);
    Log::_vaListWarning(format, arglist);
    va_end(arglist);
}

void log_error(const char* format, ...){
    va_list arglist;
    va_start( arglist, format);
    Log::_vaListError(format, arglist);
    va_end(arglist);
}