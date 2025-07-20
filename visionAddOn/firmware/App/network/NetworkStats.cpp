#include "NetworkStats.h"

#include "cmsis_os2.h"
#include "constants.h"
#include "lwip.h"
#include "utils/Log.h"

void NetworkStats::run() {
    const uint32_t currentTimestampS = static_cast<uint32_t>(osKernelGetTickCount() / TICKS_PER_SECOND);
    if(currentTimestampS - _lastTimestampS > _intervalS){
        Log::info("[NetworkStats] ---- lwip stats start ----");
        stats_display();
        Log::info("[NetworkStats] ---- lwip stats stop ----");
        _lastTimestampS = currentTimestampS;
    }
}