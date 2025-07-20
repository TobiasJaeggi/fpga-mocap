#ifndef VISIONADDON_APP_CAMERA_OV5640_H
#define VISIONADDON_APP_CAMERA_OV5640_H

#include "stm32f7xx_hal.h"

#include <cstdint>
#include <tuple>
#include <stdbool.h>
#include <variant>
#include <map>

class Ov5640 final {
public:
    Ov5640(I2C_HandleTypeDef* i2c, uint8_t i2cSlaveAddress, DCMI_HandleTypeDef* dcmi);
    Ov5640 (const Ov5640&) = delete;
    Ov5640& operator=(const Ov5640&) = delete;
    Ov5640 (const Ov5640&&) = delete;
    Ov5640& operator=(const Ov5640&&) = delete;

    uint16_t chipId();
    bool init();
    bool rgb565();
    bool slow();

    enum ResolutionAndFramerate {
        _2592_X_1944_AT_15_FPS,
        _1280_X_960_AT_45_FPS,
        _1920_X_1080_AT_30_FPS,
        _1280_X_720_AT_60_FPS,
        _640_X_480_AT_90_FPS,
        _320_X_240_AT_120_FPS,
    };
    bool resolutionAndFramerate(ResolutionAndFramerate resAndFps);
    
    static constexpr uint16_t DEFAULT_EXPOSURE_LEVEL {42U};
    bool exposure(bool automatic, uint16_t level=DEFAULT_EXPOSURE_LEVEL);
    static constexpr uint16_t DEFAULT_GAIN_LEVEL {42U};
    bool gain(bool automatic, uint16_t level=DEFAULT_GAIN_LEVEL);
    static constexpr uint16_t DEFAULT_WHITEBALANCE_RED {42U};
    static constexpr uint16_t DEFAULT_WHITEBALANCE_GREEN {42U};
    static constexpr uint16_t DEFAULT_WHITEBALANCE_BLUE {42U};
    bool whitebalance(bool automatic, uint16_t red=DEFAULT_WHITEBALANCE_RED, uint16_t green=DEFAULT_WHITEBALANCE_GREEN, uint16_t blue=DEFAULT_WHITEBALANCE_BLUE);
    bool capture();
    void abortCapture();

private:
    static const std::map<uint16_t, uint8_t> buildInitSequence();
    static const std::map<uint16_t, uint8_t> buildRgb565Sequence();

    bool window(uint16_t offsetX, uint16_t offsetY, uint16_t width, uint16_t height);

    bool i2cMasterReady();
    bool i2cSlaveReady(const uint32_t retires = 1, const uint32_t timeoutMs = 10);
    std::variant<uint8_t, HAL_StatusTypeDef> readRegister(uint16_t address, uint32_t  const timeoutMs = 10);
    HAL_StatusTypeDef writeRegister(uint16_t address, uint8_t data, const uint32_t timeoutMs = 10);
    bool writeRegisterValueMap(const std::map<uint16_t, uint8_t>& registerValueMap, const uint32_t timeoutMs = 10);

    I2C_HandleTypeDef* _i2c;
    const uint16_t _i2cSlaveAddress; //!< shifted to left by one to comply with STM HAL fuckery
    DCMI_HandleTypeDef* _dcmi;
    //const uint8_t* _framebufferBase;
    //const size_t 
    const std::map<uint16_t, uint8_t> _initSequence;
    const std::map<uint16_t, uint8_t> _rgb565Sequence;
    
};

#endif // VISIONADDON_APP_CAMERA_OV5640_H