#ifndef VISIONADDON_APP_SERVICE_NETWORKSTATS_H
#define VISIONADDON_APP_SERVICE_NETWORKSTATS_H

#include "utils/IRunnable.h"

#include <cstdint>

class NetworkStats final: public IRunnable {
public:    
    NetworkStats() = default;
    NetworkStats (const NetworkStats&) = delete;
    NetworkStats& operator=(const NetworkStats&) = delete;
    NetworkStats (const NetworkStats&&) = delete;
    NetworkStats& operator=(const NetworkStats&&) = delete;

    uint32_t intervalS() {return _intervalS;};
    void intervalS(uint32_t intervalS) {_intervalS = intervalS;};

    void run() override;
private:
    uint32_t _intervalS {10};
    uint32_t _lastTimestampS;
};

#endif // VISIONADDON_APP_SERVICE_NETWORKSTATS_H