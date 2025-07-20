#ifndef VISIONADDON_APP_UTILS_POOL_BUFFERPOOL_H
#define VISIONADDON_APP_UTILS_POOL_BUFFERPOOL_H

#include "utils/mutex/IMutex.h"

#include <cstddef>
#include <cstdint>
#include <deque>
#include <vector>

class BufferPool final {
public:
    BufferPool(size_t depth, IMutex& mutex);
    BufferPool (const BufferPool&) = delete;
    BufferPool& operator=(const BufferPool&) = delete;
    BufferPool (const BufferPool&&) = delete;
    BufferPool& operator=(const BufferPool&&) = delete;

    /**
     * @brief Request a buffer from the pool.
     * 
     * This function attempts to acquire a buffer of the specified size from the buffer pool.
     * 
     * @param size The size of the buffer to request.
     * @return pointer to base of buffer, nullptr if allocation failed
     */
    uint8_t* acquire(size_t size);

    /**
     * @brief Returns a buffer back to the pool.
     * 
     * This function is used to return a previously allocated buffer back to the pool,
     * making it available for future use.
     * 
     * @param b The buffer to be returned to the pool.
     */
    void release(uint8_t* p);
private:
    static constexpr size_t _BUFFER_SIZE {1024};
    IMutex& _mutex;
    std::deque<uint8_t*> _pool;
    std::vector<uint8_t*> _validBases;
};

#endif // VISIONADDON_APP_UTILS_POOL_BUFFERPOOL_H