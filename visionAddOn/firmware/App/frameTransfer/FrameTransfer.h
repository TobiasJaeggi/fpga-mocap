#ifndef VISIONADDON_APP_SERVICE_FRAMETRANSFER_H
#define VISIONADDON_APP_SERVICE_FRAMETRANSFER_H

#include "cmsis_os2.h"
#include "lwip/api.h"
#include "lwip/sockets.h"
#undef bind // to avoid conflicts with std functional bind

class FrameTransfer final {
public:
    FrameTransfer() = default;
    FrameTransfer (const FrameTransfer&) = delete;
    FrameTransfer& operator=(const FrameTransfer&) = delete;
    FrameTransfer (const FrameTransfer&&) = delete;
    FrameTransfer& operator=(const FrameTransfer&&) = delete;

    bool sendFrame(in_addr_t address, uint32_t port); //!< blocking!
private:
    bool initTransfer(int32_t& socket);
    enum TransferStatus : uint8_t {
        COMPLETE = 0,
        INCOMPLETE = 1,
        ERROR = 2,
    };
    TransferStatus sendFrameSegment(int32_t& socket);
    void endTransfer(int32_t& socket); 
    osSemaphoreId_t _transferRequestSemaphore;
    size_t _segmentIndex = 0;
    size_t _bytesRemaining = 0;
    static constexpr size_t _FRAME_BUFFER_SIZE {1280 * 800};
    static constexpr size_t _MAX_SEGMENT_SIZE {1024}; //TODO: tune
    static constexpr size_t _REQUIRED_SEGMENTS {size_t(_FRAME_BUFFER_SIZE / _MAX_SEGMENT_SIZE + 0.5)}; // std::ceil is not a constexpr ¯\_(ツ)_/¯
    
};

#endif // VISIONADDON_APP_SERVICE_FRAMETRANSFER_H