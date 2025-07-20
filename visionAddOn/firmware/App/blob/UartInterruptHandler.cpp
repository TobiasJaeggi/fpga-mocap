#include "UartInterruptHandler.h"

#include "utils/assert.h"
#include "utils/Log.h"

#include <algorithm>
#include <mutex>

std::unordered_map<volatile uint32_t*, UartInterruptHandler&> UartInterruptHandler::_handleToHandler {};

UartInterruptHandler::UartInterruptHandler(
    UART_HandleTypeDef* uartHandle,
    osMessageQueueId_t messageQId,
    BufferPool& bufferPool) :
_uartHandle{uartHandle},
_messageQId{messageQId},
_bufferPool{bufferPool}
{
    ASSERT(_uartHandle != nullptr);
    ASSERT(_messageQId != nullptr);
}

bool UartInterruptHandler::isActive(){
    std::scoped_lock lock(_transferActiveMutex);
    return _transferActive;
}

void UartInterruptHandler::start()
{
    Log::trace("[UartInterruptHandler] start - acquiring mutex");
    std::scoped_lock lock(_transferActiveMutex);
    Log::trace("[UartInterruptHandler] start - mutex acquired");
    if(_transferActive){
        Log::warning("[UartInterruptHandler] Abort start, transfer active");
        return;
    }
    static constexpr size_t BUFFER_SIZE {1024};
    uint8_t* bufferBase = _bufferPool.acquire(BUFFER_SIZE);
    if(bufferBase == nullptr) {
        Log::warning("[UartInterruptHandler] Abort start, buffer acquire failed");
        _transferActive = false;
        return;
    }
    _message.bufferBase = bufferBase;
    __HAL_UART_DISABLE_IT(_uartHandle, UART_IT_CM);
    __HAL_UART_DISABLE_IT(_uartHandle, UART_IT_CTS);
    __HAL_UART_DISABLE_IT(_uartHandle, UART_IT_LBD);
    __HAL_UART_DISABLE_IT(_uartHandle, UART_IT_TXE);
    __HAL_UART_DISABLE_IT(_uartHandle, UART_IT_TC);
    __HAL_UART_DISABLE_IT(_uartHandle, UART_IT_RXNE);
    __HAL_UART_DISABLE_IT(_uartHandle, UART_IT_RTO);
    __HAL_UART_DISABLE_IT(_uartHandle, UART_IT_IDLE);
    __HAL_UART_DISABLE_IT(_uartHandle, UART_IT_PE);
    __HAL_UART_DISABLE_IT(_uartHandle, UART_IT_ERR);

    __HAL_UART_CLEAR_FLAG(_uartHandle, UART_CLEAR_PEF);
    __HAL_UART_CLEAR_FLAG(_uartHandle, UART_CLEAR_FEF);
    __HAL_UART_CLEAR_FLAG(_uartHandle, UART_CLEAR_NEF);
    __HAL_UART_CLEAR_FLAG(_uartHandle, UART_CLEAR_OREF);
    __HAL_UART_CLEAR_FLAG(_uartHandle, UART_CLEAR_IDLEF);
    __HAL_UART_CLEAR_FLAG(_uartHandle, UART_CLEAR_TCF);
    __HAL_UART_CLEAR_FLAG(_uartHandle, UART_CLEAR_RTOF);
    __HAL_UART_CLEAR_FLAG(_uartHandle, UART_CLEAR_LBDF);
    __HAL_UART_CLEAR_FLAG(_uartHandle, UART_CLEAR_CTSF);
    __HAL_UART_CLEAR_FLAG(_uartHandle, UART_CLEAR_CMF);
    auto status = HAL_UARTEx_ReceiveToIdle_DMA(_uartHandle, bufferBase, BUFFER_SIZE);
    if(status != HAL_StatusTypeDef::HAL_OK){
        Log::error("[setupNewUartRx] hal status %d", status);
        _transferActive = false;
        return;
    }
    _transferActive = true;
}

void UartInterruptHandler::handleInterrupt(size_t bytesReceived)
{
    Log::trace("[UartInterruptHandler] handling interrupt, %d bytes received", bytesReceived);
    switch(HAL_UARTEx_GetRxEventType(_uartHandle)) {
        case HAL_UART_RXEVENT_IDLE: {
            Log::trace("[HAL_UARTEx_RxEventCallback] idle event, received %d bytes", bytesReceived);
            _message.bytesReceived = bytesReceived; // bytes received in previous buffer
            ASSERT(osMessageQueuePut(_messageQId, &_message, 0, 0) == osOK);
            {
                //FIXME: If task has lock and ISR fires, mutex can never be acquired
                std::scoped_lock lock(_transferActiveMutex);
                _transferActive = false;
            }
            start();
            break;
        }
        case HAL_UART_RXEVENT_TC: {
            Log::warning("[HAL_UARTEx_RxEventCallback] TC complete interrupt should never happen");
            break;
        }
        case HAL_UART_RXEVENT_HT: {
            Log::warning("[HAL_UARTEx_RxEventCallback] HT complete interrupt must be disabled");
            break;
        }
        default: {
            Log::warning("[HAL_UARTEx_RxEventCallback] unknown interrupt");
            break;
        }
    }
}

void UartInterruptHandler::registerHandler(UART_HandleTypeDef* huart, UartInterruptHandler& handler){
    volatile uint32_t* uartBase = &(huart->Instance->CR1);
    Log::debug("[UartInterruptHandler] register handler for uart %#x", uartBase);
    _handleToHandler.insert({uartBase, handler});
}

bool UartInterruptHandler::callHandler(UART_HandleTypeDef* huart, size_t bytesReceived){
    volatile uint32_t* uartBase = &(huart->Instance->CR1);
    auto it = _handleToHandler.find(uartBase);
    if(it == _handleToHandler.end()){
        Log::warning("[UartInterruptHandler] no handler registered for uart %#x", uartBase);
        return false;
    }
    Log::trace("[UartInterruptHandler] calling handler for uart %#x", uartBase);
    it->second.handleInterrupt(bytesReceived);
    return true;
}

void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart)
{
    (void)huart;
    Log::trace("[HAL_UART_RxCpltCallback]");
}

void HAL_UARTEx_RxEventCallback(UART_HandleTypeDef *huart, uint16_t Size)
{
    UartInterruptHandler::callHandler(huart, Size);
}

void HAL_UART_ErrorCallback(UART_HandleTypeDef *huart)
{
    (void)huart;
    Log::error("[HAL_UART_ErrorCallback]");
}
