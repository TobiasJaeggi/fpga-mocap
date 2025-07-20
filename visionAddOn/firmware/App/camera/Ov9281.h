#ifndef VISIONADDON_APP_CAMERA_OV9281_H
#define VISIONADDON_APP_CAMERA_OV9281_H

#include "CameraTypes.h"
#include "stm32f7xx_hal.h"

#include <cstdint>
#include <tuple>
#include <stdbool.h>
#include <variant>
#include <map>

class Ov9281 final {
public:
    Ov9281(I2C_HandleTypeDef* i2c, uint8_t i2cSlaveAddress, DCMI_HandleTypeDef* dcmi);
    Ov9281 (const Ov9281&) = delete;
    Ov9281& operator=(const Ov9281&) = delete;
    Ov9281 (const Ov9281&&) = delete;
    Ov9281& operator=(const Ov9281&&) = delete;

    uint16_t chipId();

    bool init(Fps fps);
    
    static constexpr uint8_t DEFAULT_EXPOSURE_LEVEL_FRACTION {0U};
    /**
     * @brief Set the sensor exposure level
     * 
     * The level is set using fixed point float (4.4).
     * The sensor data sheet describes the unit as "number of row periods".
     *
     * @param levelInteger, 4 bit exponent of fixed point float exposure level
     * @param levelFraction, 4 bit mantissa of fixed point float exposure level
     *
     * @return true if command was sent successfully, false otherwise
     */
    bool exposure(uint16_t levelInteger, uint8_t levelFraction=DEFAULT_EXPOSURE_LEVEL_FRACTION);

    static constexpr uint8_t DEFAULT_GAIN_BAND {0U};
    /**
     * @brief Set the sensor gain level.
     *
     * @param level, the gain level, must be [0,31]
     * @param band, level to sensor gain mapping band, each band maps level differently, band must be [0,7]
     * How each band maps the level to the actual sensor gain is not documented, see implementation notes for some more insight
     *
     * @return true if command was sent successfully, false otherwise
     */
    bool gain(uint8_t level, uint8_t band=DEFAULT_GAIN_BAND);

    /**
     * @brief Set the sensor white balance levels, 12 bit per channel.
     *
     * @param red gain must be [0, 0xfff]
     * @param green gain must be [0, 0xfff]
     * @param blue gain must be [0, 0xfff]
     *
     * @return true if command was sent successfully, false otherwise
     */
    bool whitebalance(uint16_t red, uint16_t green, uint16_t blue);
    bool capture();
    void abortCapture();

private:
    static const std::map<uint16_t, uint8_t> build13FpsSequence();
    static const std::map<uint16_t, uint8_t> build72FpsSequence();

    bool i2cMasterReady();
    bool i2cSlaveReady(uint32_t retires = 1, uint32_t timeoutMs = 10);
        std::tuple<bool, uint8_t> readRegister(uint16_t address, uint32_t timeoutMs = 10);

    bool writeRegister(uint16_t address, uint8_t data, uint32_t timeoutMs = 10);
    bool writeRegisters(const std::map<uint16_t, uint8_t>& registerValueMap, uint32_t timeoutMs = 10);

    I2C_HandleTypeDef* _i2c;
    const uint16_t _i2cSlaveAddress;
    DCMI_HandleTypeDef* _dcmi;
    Fps _fps {Fps::UNDEFINED};
    const std::map<uint16_t, uint8_t> _init13Fps;
    const std::map<uint16_t, uint8_t> _init72Fps;
};

#endif // VISIONADDON_APP_CAMERA_OV9281_H