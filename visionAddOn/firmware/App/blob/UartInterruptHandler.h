#ifndef VISIONADDON_APP_BLOB_UARTINTERRUPTHANDLER_H
#define VISIONADDON_APP_BLOB_UARTINTERRUPTHANDLER_H

#include "cmsis_os2.h"
#include "utils/ITransfer.h"
#include "utils/mutex/Mutex.h"
#include "utils/pool/BufferPool.h"
#include "stm32f7xx_hal.h"

#include <unordered_map>

//TODO: move out of this header
struct UartIsrToBlobReceiverQMessage {
    uint8_t* bufferBase;
    size_t bytesReceived;
};

class UartInterruptHandler final : public ITransfer {
public:
    UartInterruptHandler(UART_HandleTypeDef* uartHandle, osMessageQueueId_t messageQId, BufferPool& bufferPool);
    UartInterruptHandler (const UartInterruptHandler&) = delete;
    UartInterruptHandler& operator=(const UartInterruptHandler&) = delete;
    UartInterruptHandler (const UartInterruptHandler&&) = delete;
    UartInterruptHandler& operator=(const UartInterruptHandler&&) = delete;
    bool isActive() override;
    void start() override;
    void handleInterrupt(size_t bytesReceived);
    static void registerHandler(UART_HandleTypeDef* huart, UartInterruptHandler& handler);
    static bool callHandler(UART_HandleTypeDef* huart, size_t bytesReceived);
private:
    Mutex _transferActiveMutex {Mutex()};
    bool _transferActive {false};
    UART_HandleTypeDef* _uartHandle;
    osMessageQueueId_t _messageQId;
    BufferPool& _bufferPool;
    UartIsrToBlobReceiverQMessage _message {nullptr, 0};
    static std::unordered_map<volatile uint32_t*, UartInterruptHandler&> _handleToHandler;
};

void registerInterruptHandler(UartInterruptHandler* handler);

#endif // VISIONADDON_APP_BLOB_UARTINTERRUPTHANDLER_H
