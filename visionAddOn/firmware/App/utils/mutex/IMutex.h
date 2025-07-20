#ifndef VISIONADDON_APP_UTILS_MUTEX_IMUTEX_H
#define VISIONADDON_APP_UTILS_MUTEX_IMUTEX_H

class IMutex {
public:
    virtual void lock() = 0; //!< blocking!
    virtual void unlock() = 0; //!< blocking!
};

#endif // VISIONADDON_APP_UTILS_MUTEX_IMUTEX_H