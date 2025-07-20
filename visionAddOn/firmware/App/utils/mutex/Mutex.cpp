#include "Mutex.h"

Mutex::Mutex() :
_mutex{osMutexNew(nullptr)}
{
}

void Mutex::lock()
{
    osMutexAcquire(_mutex, osWaitForever);
}

void Mutex::unlock()
{
    osMutexRelease(_mutex);
}
