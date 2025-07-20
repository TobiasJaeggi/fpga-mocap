#include "CyclicPool.h"

#include "utils/assert.h"

#include <stdlib.h>
#include <mutex>

CyclicPool::CyclicPool(size_t bufferSize, size_t poolDepth) :
_BUFFER_SIZE{bufferSize}
{
    for(size_t i = 0; i < poolDepth; i++){
        uint8_t* p = (uint8_t*)malloc(_BUFFER_SIZE);
        ASSERT(p != nullptr);
        _pool.push_back(p);
    }
    _next = _pool.begin();
}

void* CyclicPool::acquire(size_t size)
{
    if(size > _BUFFER_SIZE){
        return nullptr;
    }
    uint8_t* p {nullptr};
    {
        p = *_next;
        _next++;
        if(_next == _pool.end()){
            _next = _pool.begin();
        }
    }
    return p;
}
