#ifndef VISIONADDON_APP_FPGACOMMANDER_FPGACOMMANDER_H
#define VISIONADDON_APP_FPGACOMMANDER_FPGACOMMANDER_H

#include "FpgaCommanderTypes.h"

#include "stm32f7xx_hal.h"

class FpgaCommander final
{
public:
    FpgaCommander(UART_HandleTypeDef *uartHandle);
    FpgaCommander(const FpgaCommander &) = delete;
    FpgaCommander &operator=(const FpgaCommander &) = delete;
    FpgaCommander(const FpgaCommander &&) = delete;
    FpgaCommander &operator=(const FpgaCommander &&) = delete;

    /**
     * @brief Set the image processing pipeline input source.
     *
     * @param input of the pipeline
     * @return true if command was sent successfully, false otherwise
     */
    bool pipelineInput(PipelineInput input);

    /**
     * @brief Set the image processing pipeline output received by the visionAddOn.
     *
     * @param output of the pipeline
     * @return true if command was sent successfully, false otherwise
     */
    bool pipelineOutput(PipelineOutput output);

    /**
     * @brief Set the pipeline image binarization threshold.
     *
     * @param threshold used to binarize the image feed. Allowed values: [0-2^8-1]
     * @return true if command was sent successfully, false otherwise
     */
    bool pipelineBinarizationThreshold(uint8_t threshold);

    /**
     * @brief Enable/disable pulsed strobe pin.
     *
     * @param enable true to enable, false to disable
     * @return true if command was sent successfully, false otherwise
     */
    bool strobeEnablePulse(bool enable);

    /**
     * @brief Set the strobe on delay.
     *
     * Delay from vertical sync event to rising edge of strobe pin in pixel clock cycles.
     *
     * @param delayCycles in pixel clock cycles
     * @return true if command was sent successfully, false otherwise
     */
    bool strobeOnDelay(uint32_t delayCycles);

    /**
     * @brief Set the strobe hold time.
     *
     * Hold time of the strobe pin in pixel clock cycles.
     *
     * @param holdCycles in pixel clock cycles
     * @return true if command was sent successfully, false otherwise
     */
    bool strobeHoldTime(uint32_t holdCycles);

    /**
     * @brief Enable/disable constant strobe pin.
     *
     * @param enable true to enable, false to disable
     * @return true if command was sent successfully, false otherwise
     */
    bool strobeEnableConstant(bool enable);

private:
    bool sendCommand(const char* buffer, size_t size);
    UART_HandleTypeDef *_uartHandle;
    static constexpr uint32_t UART_TIMEOUT_MS {10U};
    static constexpr size_t NULL_TERMINATION_SIZE {1};
};

#endif // VISIONADDON_APP_FPGACOMMANDER_FPGACOMMANDER_H
