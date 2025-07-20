#ifndef VISIONADDON_APP_UTILS_MUTEX_MUTEX_H
#define VISIONADDON_APP_UTILS_MUTEX_MUTEX_H

#include "IMutex.h"
#include "cmsis_os2.h"

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <tuple>
#include <queue>

class Mutex final : public IMutex{
public:
    Mutex();
    Mutex (const Mutex&) = delete;
    Mutex& operator=(const Mutex&) = delete;
    Mutex (const Mutex&&) = delete;
    Mutex& operator=(const Mutex&&) = delete;
    void lock() override; //!< blocking!
    void unlock() override; //!< blocking!
private:
    osMutexId_t _mutex;
};

#endif // VISIONADDON_APP_UTILS_MUTEX_IMUTEX_H