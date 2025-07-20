#ifndef VISIONADDON_APP_BLOB_EXTERNALINTERRUPTHANDLER_H
#define VISIONADDON_APP_BLOB_EXTERNALINTERRUPTHANDLER_H

#include "cmsis_os2.h"
#include "utils/ITransfer.h"
#include "utils/mutex/Mutex.h"
#include "utils/pool/CyclicPool.h"
#include "stm32f7xx_hal.h"
#include "utils/IActivatable.h"

#include <cstdint>
#include <unordered_map>

//TODO: move out of this header
struct ExternalIsrToBlobReceiverQMessage {
    std::uint8_t* bufferBase;
    size_t bytesReceived;
};

class ExternalInterruptHandler final {
public:
    ExternalInterruptHandler(SPI_HandleTypeDef* spiHandle, osMessageQueueId_t messageQId);
    ExternalInterruptHandler (const ExternalInterruptHandler&) = delete;
    ExternalInterruptHandler& operator=(const ExternalInterruptHandler&) = delete;
    ExternalInterruptHandler (const ExternalInterruptHandler&&) = delete;
    ExternalInterruptHandler& operator=(const ExternalInterruptHandler&&) = delete;
    void handleInterrupt();
    static void registerHandler(uint16_t gpioPin, ExternalInterruptHandler& handler);
    static bool callHandler(uint16_t gpioPin);
private:
    bool dmaRxStart();
    bool dmaRxStop();

    SPI_HandleTypeDef* _spiHandle;
    osMessageQueueId_t _messageQId;
    CyclicPool _bufferPool = CyclicPool(1024, 2);
    ExternalIsrToBlobReceiverQMessage _message {nullptr, 0};
    static std::unordered_map<uint16_t, ExternalInterruptHandler&> _handleToHandler;
};

void registerInterruptHandler(ExternalInterruptHandler* handler);

#endif // VISIONADDON_APP_BLOB_EXTERNALINTERRUPTHANDLER_H
