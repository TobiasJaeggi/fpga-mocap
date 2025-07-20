#include "BufferPool.h"

#include "utils/assert.h"
#include "utils/Log.h"

#include <algorithm>
#include <stdlib.h>
#include <mutex>
BufferPool::BufferPool(size_t depth, IMutex& mutex) :
_mutex{mutex}
{
    for(size_t i = 0; i < depth; i++){
        uint8_t* p = (uint8_t*)malloc(_BUFFER_SIZE);
        ASSERT(p != nullptr);
        Log::debug("[BufferPool] *p: %#x", p);
        _pool.push_back(p);
        _validBases.push_back(p);
    }
}

uint8_t* BufferPool::acquire(size_t size)
{
    Log::trace("[BufferPool] acquire: pool size: %u", _pool.size());
    if(size > _BUFFER_SIZE){
        Log::warning("[BufferPool] acquire: size exeeds buffer");
        return nullptr;
    }
    uint8_t* p {nullptr};
    {
        std::scoped_lock lock(_mutex);
        if(_pool.empty()){
            Log::warning("[BufferPool] acquire: pool exhausted");
            return nullptr;
        }
        p = _pool.back();
        _pool.pop_back();
    }
    Log::trace("[BufferPool] acquire: *p: %#x", p);
    return p;
}

void BufferPool::release(uint8_t* p)
{
    ASSERT(std::find(_validBases.begin(), _validBases.end(), p) != _validBases.end());
    {
        std::scoped_lock lock(_mutex);
        _pool.push_back(p);
    }
    Log::trace("[BufferPool] released: *p: %#x, pool size: %u", p, _pool.size());
}
