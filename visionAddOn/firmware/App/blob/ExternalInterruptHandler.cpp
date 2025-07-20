#include "ExternalInterruptHandler.h"

#include "stm32f7xx_hal_dma.h"
#include "utils/assert.h"
#include "utils/Log.h"

#include <algorithm>
#include <mutex>
std::unordered_map<uint16_t, ExternalInterruptHandler&> ExternalInterruptHandler::_handleToHandler {};

ExternalInterruptHandler::ExternalInterruptHandler(
    SPI_HandleTypeDef* spiHandle,
    osMessageQueueId_t messageQId) :
_spiHandle{spiHandle},
_messageQId{messageQId}
{
    ASSERT(_spiHandle != nullptr);
    ASSERT(_messageQId != nullptr);
}

bool ExternalInterruptHandler::dmaRxStart()
{
    static constexpr size_t BUFFER_SIZE {1024};
    uint8_t* bufferBase = static_cast<uint8_t*>(_bufferPool.acquire(BUFFER_SIZE));
    if(bufferBase == nullptr) {
        Log::warning("[ExternalInterruptHandler] Abort, buffer acquire failed");
        return false;
    }

    HAL_StatusTypeDef startRet = HAL_SPI_Receive_DMA(_spiHandle, bufferBase, BUFFER_SIZE);
    if(startRet != HAL_OK) {
        Log::warning("[ExternalInterruptHandler] Abort, DMA start failed with code %d", startRet);
        return false;
    }

    return true;
}

bool ExternalInterruptHandler::dmaRxStop()
{
    HAL_StatusTypeDef stopRet = HAL_SPI_DMAStop(_spiHandle);
    if(stopRet != HAL_OK) {
        Log::warning("[ExternalInterruptHandler] Abort, DMA stop failed with code %d", stopRet);
        return false;
    }

    return true;
}

void ExternalInterruptHandler::handleInterrupt()
{
    dmaRxStop();

    // publish data
    uint32_t bytesReceived = _spiHandle->RxXferSize - __HAL_DMA_GET_COUNTER(_spiHandle->hdmarx);

    _message.bytesReceived = bytesReceived; // bytes received in previous buffer
    _message.bufferBase =  _spiHandle->pRxBuffPtr;
    ASSERT(osMessageQueuePut(_messageQId, &_message, 0, 0) == osOK);

    dmaRxStart();
}

void ExternalInterruptHandler::registerHandler(uint16_t gpioPin, ExternalInterruptHandler& handler){
    Log::debug("[ExternalInterruptHandler] register handler for external interrupt on GPIO pin %#x", gpioPin);
    _handleToHandler.insert({gpioPin, handler});
}

bool ExternalInterruptHandler::callHandler(uint16_t gpioPin){
    auto it = _handleToHandler.find(gpioPin);
    if(it == _handleToHandler.end()){
        return false;
    }
    it->second.handleInterrupt();
    return true;
}

void HAL_GPIO_EXTI_Callback(uint16_t gpioPin)
{
   ExternalInterruptHandler::callHandler(gpioPin);
}

//TODO: move to different file
void HAL_SPI_ErrorCallback(SPI_HandleTypeDef *hspi)
{
    (void)hspi;
    Log::error("[HAL_SPI_ErrorCallback]");
}
