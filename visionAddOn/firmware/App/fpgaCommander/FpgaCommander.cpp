#include "FpgaCommander.h"

#include "stm32f7xx_hal_uart.h"
#include "utils/assert.h"
#include "utils/constants.h"
#include "utils/Log.h"

FpgaCommander::FpgaCommander(UART_HandleTypeDef *uartHandle) : _uartHandle{uartHandle}
{
    ASSERT(_uartHandle != nullptr);
}

bool FpgaCommander::sendCommand(const char *buffer, size_t size)
{
    auto ret = HAL_UART_Transmit(_uartHandle, (const uint8_t *)buffer, size, UART_TIMEOUT_MS * TICKS_PER_MILLISECOND);
    if (ret != HAL_StatusTypeDef::HAL_OK)
    {
        Log::warning("[FpgaCommander] sending command failed with return code %d", ret);
        return false;
    }
    return true;
}

bool FpgaCommander::pipelineInput(PipelineInput input)
{
    static constexpr char CAMERA[] {"io"};
    static constexpr char FAKE_STATIC[] {"is"};
    static constexpr char FAKE_MOVING[] {"im"};

    const char *buffer{nullptr};
    size_t size{0U};
    switch (input)
    {
    case PipelineInput::CAMERA:
        buffer = CAMERA;
        size = sizeof(CAMERA);
        break;
    case PipelineInput::FAKE_STATIC:
        buffer = FAKE_STATIC;
        size = sizeof(FAKE_STATIC);
        break;
    case PipelineInput::FAKE_MOVING:
        buffer = FAKE_MOVING;
        size = sizeof(FAKE_MOVING);
        break;
    default:
        Log::error("[FpgaCommander] select pipeline input failed, invalid option %u", input);
        return false;
    }
    Log::info("[FpgaCommander] set pipeline input to %u", input);
    return sendCommand(buffer, size);
}

bool FpgaCommander::pipelineOutput(PipelineOutput output)
{
    static constexpr char UNPROCESSED[] {"or"};
    static constexpr char BINARIZED[] {"ob"};

    const char *buffer{nullptr};
    size_t size{0U};
    switch (output)
    {
    case PipelineOutput::UNPROCESSED:
        buffer = UNPROCESSED;
        size = sizeof(UNPROCESSED);
        break;
    case PipelineOutput::BINARIZED:
        buffer = BINARIZED;
        size = sizeof(BINARIZED);
        break;
    default:
        Log::error("[FpgaCommander] select pipeline output failed, invalid option %u", output);
        return false;
    }
    Log::info("[FpgaCommander] set pipeline output to %u", output);
    return sendCommand(buffer, size);
}

bool FpgaCommander::pipelineBinarizationThreshold(uint8_t threshold)
{
    static constexpr uint16_t THRESHOLD_MAX{0xffU};
    if (threshold > THRESHOLD_MAX)
    {
        Log::error("[FpgaCommander] set binarization threshold failed, invalid threshold %u", threshold);
        return false;
    }

    static constexpr char PREFIX[] {"t"};
    static constexpr size_t DIGIT_SIZE_MIN{1};
    static constexpr size_t DIGIT_SIZE_MAX{3};
    static constexpr size_t BUFFER_SIZE{sizeof(PREFIX) + DIGIT_SIZE_MAX};
    char buffer[BUFFER_SIZE];
    int32_t size = snprintf(buffer, BUFFER_SIZE, "%s%u", PREFIX, threshold);
    size = size + NULL_TERMINATION_SIZE;
    static constexpr int32_t COMMAND_SIZE_MIN{sizeof(PREFIX) + DIGIT_SIZE_MIN};
    if (size < COMMAND_SIZE_MIN)
    {
        Log::error("[FpgaCommander] set binarization threshold failed, populating buffer failed with code %d", size);
        return false;
    }
    Log::info("[FpgaCommander] set binarization threshold to %u", threshold);
    return sendCommand(buffer, size);
}

bool FpgaCommander::strobeEnablePulse(bool enable)
{
    static constexpr char ENABLE[] {"se1"};
    static constexpr char DISABLE[] {"se0"};

    const char *buffer{nullptr};
    size_t size{0U};
    if (enable)
    {
        buffer = ENABLE;
        size = sizeof(ENABLE);
    }
    else
    {
        buffer = DISABLE;
        size = sizeof(DISABLE);
    }
    Log::info("[FpgaCommander] set strobe enable pulse to %u", enable);
    return sendCommand(buffer, size);
}

bool FpgaCommander::strobeOnDelay(uint32_t delayCycles)
{
    static constexpr char PREFIX[] {"sd"};
    static constexpr size_t DIGIT_SIZE_MIN{1}; // 0
    static constexpr size_t DIGIT_SIZE_MAX{10}; // 2^32 - 1 
    static constexpr size_t BUFFER_SIZE{sizeof(PREFIX) + DIGIT_SIZE_MAX};
    char buffer[BUFFER_SIZE];
    int32_t size = snprintf(buffer, BUFFER_SIZE, "%s%lu", PREFIX, delayCycles);
    size = size + NULL_TERMINATION_SIZE;
    static constexpr int32_t COMMAND_SIZE_MIN{sizeof(PREFIX) + DIGIT_SIZE_MIN};
    if (size < COMMAND_SIZE_MIN)
    {
        Log::error("[FpgaCommander] set strobe on delay failed, populating buffer failed with code %d", size);
        return false;
    }
    Log::info("[FpgaCommander] set strobe on delay to %lu cycles", delayCycles);
    return sendCommand(buffer, size);

}

bool FpgaCommander::strobeHoldTime(uint32_t holdCycles)
{
    static constexpr char PREFIX[] {"sh"};
    static constexpr size_t DIGIT_SIZE_MIN{1}; // 0
    static constexpr size_t DIGIT_SIZE_MAX{10}; // 2^32 - 1 
    static constexpr size_t BUFFER_SIZE{sizeof(PREFIX) + DIGIT_SIZE_MAX};
    char buffer[BUFFER_SIZE];
    int32_t size = snprintf(buffer, BUFFER_SIZE, "%s%lu", PREFIX, holdCycles);
    size = size + NULL_TERMINATION_SIZE;
    static constexpr int32_t COMMAND_SIZE_MIN{sizeof(PREFIX) + DIGIT_SIZE_MIN};
    if ((size + NULL_TERMINATION_SIZE) < COMMAND_SIZE_MIN)
    {
        Log::error("[FpgaCommander] set strobe hold time failed, populating buffer failed with code %d", size);
        return false;
    }
    Log::info("[FpgaCommander] set strobe hold time to %lu cycles", holdCycles);
    return sendCommand(buffer, size);
}

bool FpgaCommander::strobeEnableConstant(bool enable)
{
    static constexpr char ENABLE[] {"sc1"};
    static constexpr char DISABLE[] {"sc0"};

    const char *buffer{nullptr};
    size_t size{0U};
    if (enable)
    {
        buffer = ENABLE;
        size = sizeof(ENABLE);
    }
    else
    {
        buffer = DISABLE;
        size = sizeof(DISABLE);
    }
    Log::info("[FpgaCommander] set strobe enable constant to %u", enable);
    return sendCommand(buffer, size);
}
