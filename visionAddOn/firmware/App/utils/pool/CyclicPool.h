#ifndef VISIONADDON_APP_UTILS_POOL_CYCLICPOOL_H
#define VISIONADDON_APP_UTILS_POOL_CYCLICPOOL_H

#include <cstddef>
#include <cstdint>
#include <vector>

class CyclicPool final {
public:
    CyclicPool(size_t bufferSize, size_t poolDepth);
    CyclicPool (const CyclicPool&) = delete;
    CyclicPool& operator=(const CyclicPool&) = delete;
    CyclicPool (const CyclicPool&&) = delete;
    CyclicPool& operator=(const CyclicPool&&) = delete;

    /**
     * @brief Request a buffer from the pool.
     * 
     * This function attempts to acquire a buffer of the specified size from the buffer pool.
     * No guarantee of ownership, same buffer will be handed out again after n calls to acquire, where n is the depth of the pool.
     * Acquire is not thread safe.
     * @param size The size of the buffer to request.
     * @return pointer to base of buffer, nullptr if allocation failed
     */
    void* acquire(size_t size);

private:
    const size_t _BUFFER_SIZE;
    std::vector<uint8_t*> _pool;
    decltype(_pool)::iterator _next;
};

#endif // VISIONADDON_APP_UTILS_POOL_CYCLICPOOL_H