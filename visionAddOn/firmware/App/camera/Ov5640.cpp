#include "Ov5640.h"

#include "cmsis_os2.h"
#include "lwip/sockets.h"
#undef bind // to avoid conflicts with std functional bind
#include "utils/assert.h"
#include "utils/constants.h"
#include "utils/Log.h"
#include <stdio.h>

Ov5640::Ov5640(I2C_HandleTypeDef* i2c, uint8_t i2cSlaveAddress, DCMI_HandleTypeDef* dcmi) :
_i2c{i2c},
_i2cSlaveAddress{uint16_t(i2cSlaveAddress << 1)},
_dcmi{dcmi},
_initSequence{std::move(buildInitSequence())},
_rgb565Sequence{std::move(buildRgb565Sequence())}
{
    ASSERT(_i2c != nullptr);
    ASSERT(_dcmi != nullptr);
    if(!i2cMasterReady() || !i2cSlaveReady()){
        Log::warning("[Ov5640] I2C not ready");
    }
}

bool Ov5640::init() {
    return writeRegisterValueMap(_initSequence);
}

bool Ov5640::rgb565() {
    return writeRegisterValueMap(_rgb565Sequence);
}


bool Ov5640::slow() {
    auto status = writeRegister(0x3035, 0xF1);
    if(status != HAL_StatusTypeDef::HAL_OK){
        Log::debug("[Ov5640] write register value map failed, status: %u", status);
        return false;
    }
    return true;
}

uint16_t Ov5640::chipId() {
    static constexpr uint16_t REGISTER_ADDRESS_SC_CHIP_ID_HIGH {0x300a};
    static constexpr uint16_t REGISTER_ADDRESS_SC_CHIP_ID_LOW {0x300b};
    auto idHighResult = readRegister(REGISTER_ADDRESS_SC_CHIP_ID_HIGH);
    if(std::holds_alternative<HAL_StatusTypeDef>(idHighResult)){
        Log::debug("[Ov5640] chip id high read failed, status: %u", std::get<HAL_StatusTypeDef>(idHighResult));
        return 0;
    }
    auto idLowResult = readRegister(REGISTER_ADDRESS_SC_CHIP_ID_LOW);
    if(std::holds_alternative<HAL_StatusTypeDef>(idLowResult)){
        Log::debug("[Ov5640] chip id low read failed, status: %u", std::get<HAL_StatusTypeDef>(idLowResult));
        return 0;
    }
    return uint16_t(std::get<uint8_t>(idHighResult)) << 8 | uint16_t(std::get<uint8_t>(idLowResult));
}

bool Ov5640::resolutionAndFramerate(Ov5640::ResolutionAndFramerate resAndFps) {
    constexpr auto getResolutionValues = [](Ov5640::ResolutionAndFramerate resAndFps) -> std::tuple<int, int, int>  {
        switch(resAndFps){
            case Ov5640::ResolutionAndFramerate::_2592_X_1944_AT_15_FPS: return {2592, 1944, 15};
            case Ov5640::ResolutionAndFramerate::_1280_X_960_AT_45_FPS:  return {1280, 960, 45};
            case Ov5640::ResolutionAndFramerate::_1920_X_1080_AT_30_FPS: return {1920, 1080, 30};
            case Ov5640::ResolutionAndFramerate::_1280_X_720_AT_60_FPS:  return {1280, 720, 60};
            case Ov5640::ResolutionAndFramerate::_640_X_480_AT_90_FPS:   return {640, 480, 90};
            case Ov5640::ResolutionAndFramerate::_320_X_240_AT_120_FPS:  return {320, 240, 120};
        }
        return {640, 480, 90};
    };
    auto widthHeightFps = getResolutionValues(resAndFps);
    window(4, 0, std::get<0>(widthHeightFps), std::get<1>(widthHeightFps));
    Log::warning("[Ov5640] fps not yet implemented");
    return true;
}

bool Ov5640::exposure(bool automatic, uint16_t level)
{
    static constexpr uint16_t REGISTER_ADDRESS_AEC_PK_MANUAL {0x3503};
    auto aecManualModeResult = readRegister(REGISTER_ADDRESS_AEC_PK_MANUAL);
    if(std::holds_alternative<HAL_StatusTypeDef>(aecManualModeResult)){
        Log::debug("[Ov5640] AEC manual mode control read failed, status: %u", std::get<HAL_StatusTypeDef>(aecManualModeResult));
        return false;
    }
    static constexpr uint8_t OFFSET_AEC_MANUAL {0U};
    static constexpr uint8_t VALUE_ENABLE_AEC_MANUAL {1U};
    if(automatic){
        // clear manual
        auto aecManualMode = std::get<uint8_t>(aecManualModeResult);
        aecManualMode = aecManualMode & ~(VALUE_ENABLE_AEC_MANUAL << OFFSET_AEC_MANUAL);
        return writeRegister(REGISTER_ADDRESS_AEC_PK_MANUAL, aecManualMode) == HAL_StatusTypeDef::HAL_OK;
    } else {
        // TODO: check max level according to 4.6.2 manual exposure contol (base on {0x380E, 0x380F} + {0x350C,0x350D})
        // set manual
        auto aecManualMode = std::get<uint8_t>(aecManualModeResult);
        aecManualMode = aecManualMode | (VALUE_ENABLE_AEC_MANUAL << OFFSET_AEC_MANUAL);
        if(writeRegister(REGISTER_ADDRESS_AEC_PK_MANUAL, aecManualMode) != HAL_StatusTypeDef::HAL_OK){
            Log::error("[Ov5640] setting AEC manual failed");
            return false;
        }
        // set level
        static constexpr uint16_t REGISTER_ADDRESS_AEC_PK_EXPOSURE_19_16 {0x3500};
        static constexpr uint16_t REGISTER_ADDRESS_AEC_PK_EXPOSURE_15_8 {0x3501};
        static constexpr uint16_t REGISTER_ADDRESS_AEC_PK_EXPOSURE_7_0 {0x3502};
        static constexpr uint8_t AEC_PK_EXPOSURE_19_16_OFFSET {16U};
        static constexpr uint8_t AEC_PK_EXPOSURE_15_8_OFFSET {8U};
        static constexpr uint8_t AEC_PK_EXPOSURE_7_0_OFFSET {0U};
        static constexpr uint8_t AEC_PK_EXPOSURE_19_16_MASK {0x0fU};
        static constexpr uint8_t AEC_PK_EXPOSURE_15_8_MASK {0xffU};
        static constexpr uint8_t AEC_PK_EXPOSURE_7_0_MASK {0xffU};

        uint32_t levelShifted = level << 4; // lower 4 bits must be 0
        if(writeRegister(REGISTER_ADDRESS_AEC_PK_EXPOSURE_19_16, (levelShifted >> AEC_PK_EXPOSURE_19_16_OFFSET) & AEC_PK_EXPOSURE_19_16_MASK) != HAL_StatusTypeDef::HAL_OK){
            Log::error("[Ov5640] setting AEC PK exposure [19:16] failed");
            return false;
        }
        if(writeRegister(REGISTER_ADDRESS_AEC_PK_EXPOSURE_15_8, (levelShifted >> AEC_PK_EXPOSURE_15_8_OFFSET) & AEC_PK_EXPOSURE_15_8_MASK) != HAL_StatusTypeDef::HAL_OK){
            Log::error("[Ov5640] setting AEC PK exposure [15:8] failed");
            return false;
        }
        if(writeRegister(REGISTER_ADDRESS_AEC_PK_EXPOSURE_7_0, (levelShifted >> AEC_PK_EXPOSURE_7_0_OFFSET) & AEC_PK_EXPOSURE_7_0_MASK) != HAL_StatusTypeDef::HAL_OK){
            Log::error("[Ov5640] setting AEC PK exposure [7:0] failed");
            return false;
        }
    }
    return true;
}

bool Ov5640::gain(bool automatic, uint16_t level)
{
    static constexpr uint16_t REGISTER_ADDRESS_AEC_PK_MANUAL {0x3503};
    auto aecManualModeResult = readRegister(REGISTER_ADDRESS_AEC_PK_MANUAL);
    if(std::holds_alternative<HAL_StatusTypeDef>(aecManualModeResult)){
        Log::debug("[Ov5640] AEC manual mode control read failed, status: %u", std::get<HAL_StatusTypeDef>(aecManualModeResult));
        return false;
    }
    static constexpr uint8_t OFFSET_AGC_MANUAL {1U};
    static constexpr uint8_t VALUE_ENABLE_AGC_MANUAL {1U};
    if(automatic){
        // clear manual
        auto aecManualMode = std::get<uint8_t>(aecManualModeResult);
        aecManualMode = aecManualMode & ~(VALUE_ENABLE_AGC_MANUAL << OFFSET_AGC_MANUAL);
        return writeRegister(REGISTER_ADDRESS_AEC_PK_MANUAL, aecManualMode) == HAL_StatusTypeDef::HAL_OK;
    } else {
        static constexpr uint16_t MAX_GAIN_LEVEL{64}; // according to 4.6.4 manual gain control
        if(level > MAX_GAIN_LEVEL){
            Log::error("[Ov5640] Requested gain level exeeds limit");
            return false;
        }
        // set manual
        auto aecManualMode = std::get<uint8_t>(aecManualModeResult);
        aecManualMode = aecManualMode | (VALUE_ENABLE_AGC_MANUAL << OFFSET_AGC_MANUAL);
        if(writeRegister(REGISTER_ADDRESS_AEC_PK_MANUAL, aecManualMode) != HAL_StatusTypeDef::HAL_OK){
            Log::error("[Ov5640] setting AEC manual failed");
            return false;
        }
        // set level
        static constexpr uint16_t REGISTER_ADDRESS_AEC_PK_REAL_GAIN_HIGH {0x350a};
        static constexpr uint16_t REGISTER_ADDRESS_AEC_PK_REAL_GAIN_LOW {0x350b};
        static constexpr uint8_t AEC_PK_REAL_GAIN_HIGH_OFFSET {8U};
        static constexpr uint8_t AEC_PK_REAL_GAIN_LOW_OFFSET {0U};
        static constexpr uint8_t AEC_PK_REAL_GAIN_HIGH_MASK {0x03U};
        static constexpr uint8_t AEC_PK_REAL_GAIN_LOW_MASK {0xffU};
        if(writeRegister(REGISTER_ADDRESS_AEC_PK_REAL_GAIN_HIGH, (level >> AEC_PK_REAL_GAIN_HIGH_OFFSET) & AEC_PK_REAL_GAIN_HIGH_MASK) != HAL_StatusTypeDef::HAL_OK){
            Log::error("[Ov5640] setting AEC PK real gain [9:8] failed");
            return false;
        }
        if(writeRegister(REGISTER_ADDRESS_AEC_PK_REAL_GAIN_LOW, (level >> AEC_PK_REAL_GAIN_LOW_OFFSET) & AEC_PK_REAL_GAIN_LOW_MASK) != HAL_StatusTypeDef::HAL_OK){
            Log::error("[Ov5640] setting AEC PK real gain [7:0] failed");
            return false;
        }
    }
    return true;
}

bool Ov5640::whitebalance(bool automatic, uint16_t red, uint16_t green, uint16_t blue)
{
    static constexpr uint16_t MAX_LEVEL{0xfff};
    if((red > MAX_LEVEL) || (green > MAX_LEVEL) || (blue > MAX_LEVEL)){
        Log::error("[Ov5640] Requested rbg levels the exeed limits");
        return false;
    }
    uint8_t autoWhiteBalanceManual =  automatic ? 0U : 1U;
    static constexpr uint16_t REGISTER_ADDRESS_AWB_MANUAL_CONTROL {0x3406};
    if(writeRegister(REGISTER_ADDRESS_AWB_MANUAL_CONTROL, autoWhiteBalanceManual) != HAL_StatusTypeDef::HAL_OK){
        Log::error("[Ov5640] setting auto white balance auto/manual failed");
        return false;
    }
    if(!automatic){
        static constexpr uint16_t REGISTER_ADDRESS_AWB_R_GAIN_HIGH {0x3400};
        static constexpr uint16_t REGISTER_ADDRESS_AWB_R_GAIN_LOW {0x3401};
        static constexpr uint16_t REGISTER_ADDRESS_AWB_G_GAIN_HIGH {0x3402};
        static constexpr uint16_t REGISTER_ADDRESS_AWB_G_GAIN_LOW {0x3403};
        static constexpr uint16_t REGISTER_ADDRESS_AWB_B_GAIN_HIGH {0x3404};
        static constexpr uint16_t REGISTER_ADDRESS_AWB_B_GAIN_LOW {0x3405};
        static constexpr uint8_t ABW_GAIN_HIGH_OFFSET {8U};
        static constexpr uint8_t ABW_GAIN_LOW_OFFSET {0U};
        static constexpr uint8_t ABW_GAIN_HIGH_MASK {0x04U};
        static constexpr uint8_t ABW_GAIN_LOW_MASK {0xffU};
        // red
        if(writeRegister(REGISTER_ADDRESS_AWB_R_GAIN_HIGH, (red >> ABW_GAIN_HIGH_OFFSET) & ABW_GAIN_HIGH_MASK) != HAL_StatusTypeDef::HAL_OK){
            Log::error("[Ov5640] setting AWB R gain high failed");
            return false;
        }
        if(writeRegister(REGISTER_ADDRESS_AWB_R_GAIN_LOW, (red >> ABW_GAIN_LOW_OFFSET) & ABW_GAIN_LOW_MASK) != HAL_StatusTypeDef::HAL_OK){
            Log::error("[Ov5640] setting AWB R gain low failed");
            return false;
        }
        // green
        if(writeRegister(REGISTER_ADDRESS_AWB_G_GAIN_HIGH, (green >> ABW_GAIN_HIGH_OFFSET) & ABW_GAIN_HIGH_MASK) != HAL_StatusTypeDef::HAL_OK){
            Log::error("[Ov5640] setting AWB G gain high failed");
            return false;
        }
        if(writeRegister(REGISTER_ADDRESS_AWB_G_GAIN_LOW, (green >> ABW_GAIN_LOW_OFFSET) & ABW_GAIN_LOW_MASK) != HAL_StatusTypeDef::HAL_OK){
            Log::error("[Ov5640] setting AWB G gain low failed");
            return false;
        }
        // blue
        if(writeRegister(REGISTER_ADDRESS_AWB_B_GAIN_HIGH, (blue >> ABW_GAIN_HIGH_OFFSET) & ABW_GAIN_HIGH_MASK) != HAL_StatusTypeDef::HAL_OK){
            Log::error("[Ov5640] setting AWB B gain high failed");
            return false;
        }
        if(writeRegister(REGISTER_ADDRESS_AWB_B_GAIN_LOW, (blue >> ABW_GAIN_LOW_OFFSET) & ABW_GAIN_LOW_MASK) != HAL_StatusTypeDef::HAL_OK){
            Log::error("[Ov5640] setting AWB B gain low failed");
            return false;
        }
    }
    return true;
}

bool Ov5640::capture()
{
    if(__HAL_DMA_GET_FLAG(_dcmi, DMA_FLAG_TEIF1_5)){
        Log::warning("[Ov5640] DMA transfer error flag is set");
        __HAL_DMA_CLEAR_FLAG(_dcmi, DMA_FLAG_TEIF1_5);
    }
    if(__HAL_DMA_GET_FLAG(_dcmi, DMA_FLAG_DMEIF1_5)){
        Log::warning("[Ov5640] DMA direct mode error flag is set");
        __HAL_DMA_CLEAR_FLAG(_dcmi, DMA_FLAG_DMEIF1_5);
    }
    if(__HAL_DMA_GET_FLAG(_dcmi, DMA_FLAG_FEIF1_5)){
        Log::warning("[Ov5640] DMA fifo error flag is set");
        __HAL_DMA_CLEAR_FLAG(_dcmi, DMA_FLAG_FEIF1_5);
    }
    auto dcmiState = _dcmi->State;
    auto dcmiErrorCode = _dcmi->ErrorCode;
    switch (dcmiState){
        case HAL_DCMI_StateTypeDef::HAL_DCMI_STATE_READY: {
            break;
        }
        case HAL_DCMI_StateTypeDef::HAL_DCMI_STATE_BUSY: {
            log_warning("[Ov5640] capture abort, DCMI busy");
            return false;
        }
        default: {
            log_debug("[Ov5640] capture abort, DCMI not ready, State: %d ErrorCode: %d", dcmiState, dcmiErrorCode);
            return false;
        }
    }
    
    Log::info("[Ov5640] starting capture");
    //FIXME: hardcoded to 1 resolution, reconfigure based on ResolutionAndFramerate
    static constexpr size_t IMAGE_WIDTH_PIXELS {640};
    static constexpr size_t IMAGE_HEIGHT_PIXELS {480};
    static constexpr size_t BYTES_PER_PIXEL {2};
    static constexpr size_t BYTES_PER_DMA_TRANSFER {4};
    auto startStatus = HAL_DCMI_Start_DMA(
        _dcmi,
        DCMI_MODE_SNAPSHOT,
        EXTERNAL_SDRAM_BASE_ADDRESS,
        IMAGE_WIDTH_PIXELS * IMAGE_HEIGHT_PIXELS * BYTES_PER_PIXEL / BYTES_PER_DMA_TRANSFER
    );

    if (startStatus != HAL_StatusTypeDef::HAL_OK){
        Log::error("[Ov5640] capture abort, start snapshot failed, dma status: %u", startStatus);
        return false;
    }
    bool success = false;
    bool timeout = true;
    static constexpr uint32_t FRAMERATE_FPS {15}; //FIXME: hardcoded to 1 resolution, reconfigure based on ResolutionAndFramerate
    static constexpr float SECONDS_PER_FRAME {1 / float(FRAMERATE_FPS)};
    static constexpr uint32_t TICKS_PER_FRAME {static_cast<uint32_t>(SECONDS_PER_FRAME * float(TICKS_PER_SECOND) + 0.5)}; // std::ceil is not a constexpr ¯\_(ツ)_/¯
    
    static constexpr size_t MAX_WAIT_CYCLES {5};
    for(size_t i = 0; i < MAX_WAIT_CYCLES; i++){
        dcmiState = _dcmi->State;
        dcmiErrorCode = _dcmi->ErrorCode;
        if(dcmiState == HAL_DCMI_StateTypeDef::HAL_DCMI_STATE_READY){
            Log::info("[Ov5640] capture success, took %u cycles", i);
            success = true;
            timeout = false;
            break;
        }else if(dcmiState != HAL_DCMI_StateTypeDef::HAL_DCMI_STATE_BUSY){
            Log::warning("[Ov5640] capture abort (cycle %u), status: %u, errorCode: %d", i, dcmiState, dcmiErrorCode);
            success = false;
            timeout = false;
            break;
        }
        osDelay(TICKS_PER_FRAME);
    }
    if(timeout){
        Log::warning("[Ov5640] capture timeout, status: %u, errorCode: %d", dcmiState, dcmiErrorCode);
    }
    HAL_DCMI_Stop(_dcmi);
    return success;
}

void Ov5640::abortCapture(){
   HAL_DCMI_Stop(_dcmi);
}

bool Ov5640::window(uint16_t offsetX, uint16_t offsetY, uint16_t width, uint16_t height) {
    auto ok = [](HAL_StatusTypeDef status) -> bool {
        return status == HAL_StatusTypeDef::HAL_OK;
    };
    auto r = ok(writeRegister(0x3212, 0x03));
    r = ok(writeRegister(0x3808, uint8_t(width >> 8))) & r;
    r = ok(writeRegister(0x3809, uint8_t(width & 0xff))) & r;
    r = ok(writeRegister(0x380a, uint8_t(height >> 8))) & r;
    r = ok(writeRegister(0x380b, uint8_t(height & 0xff))) & r;
    r = ok(writeRegister(0x3810, uint8_t(offsetX >> 8))) & r;
    r = ok(writeRegister(0x3811, uint8_t(offsetX & 0xff))) & r;
    r = ok(writeRegister(0x3812, uint8_t(offsetY >> 8))) & r;
    r = ok(writeRegister(0x3813, uint8_t(offsetY & 0xff))) & r;
    r = ok(writeRegister(0x3212, 0x13)) & r;
    r = ok(writeRegister(0x3212, 0xa3)) & r;
    return r;
}

bool Ov5640::i2cMasterReady(){
    auto state = HAL_I2C_GetState(_i2c);
    if(state != HAL_I2C_StateTypeDef::HAL_I2C_STATE_READY){
        Log::warning("[Ov5640] I2C master not ready, state: %u", state);
        return false;
    }
    
    return true;
}
bool Ov5640::i2cSlaveReady(const uint32_t retries, const uint32_t timeoutMs){
    const uint32_t timeoutTicks {timeoutMs * TICKS_PER_MILLISECOND};
    auto status = HAL_I2C_IsDeviceReady(_i2c, _i2cSlaveAddress, retries, timeoutTicks);
    if(status != HAL_StatusTypeDef::HAL_OK){
        Log::warning("[Ov5640] I2C slave not ready, status: %u", status);
        return false;
    }
    return true;
}

std::variant<uint8_t, HAL_StatusTypeDef> Ov5640::readRegister(uint16_t address, const uint32_t timeoutMs) {
    static constexpr size_t WRITE_BUFFER_SIZE {2};
    uint8_t writeBuffer[WRITE_BUFFER_SIZE] {uint8_t(address >> 8), uint8_t(address >> 0)};
    const uint32_t timeoutTicks {timeoutMs * TICKS_PER_MILLISECOND};
    auto status = HAL_I2C_Master_Transmit(_i2c, _i2cSlaveAddress, writeBuffer, WRITE_BUFFER_SIZE, timeoutTicks);
    if(status != HAL_StatusTypeDef::HAL_OK){
        Log::debug("[Ov5640] I2C transmit failed, status: %u", status);
        return status;
    }
    
    uint8_t readBuffer;
    status = HAL_I2C_Master_Receive(_i2c, _i2cSlaveAddress, &readBuffer, sizeof(readBuffer), timeoutTicks);
    if(status != HAL_StatusTypeDef::HAL_OK){
        Log::debug("[Ov5640] I2C receive failed, status: %u", status);
        return status;
    }

    return readBuffer;
}

HAL_StatusTypeDef Ov5640::writeRegister(uint16_t address, uint8_t data, const uint32_t timeoutMs) {
    static constexpr size_t WRITE_BUFFER_SIZE {3};
    uint8_t writeBuffer[WRITE_BUFFER_SIZE] {uint8_t(address >> 8), uint8_t(address >> 0), data};
    const uint32_t timeoutTicks {timeoutMs * TICKS_PER_MILLISECOND};
    auto status = HAL_I2C_Master_Transmit(_i2c, _i2cSlaveAddress, writeBuffer, WRITE_BUFFER_SIZE, timeoutTicks);
    return status;
}

bool Ov5640::writeRegisterValueMap(const std::map<uint16_t, uint8_t>& registerValueMap, const uint32_t timeoutMs) {
    for (auto const& addressValuePair : registerValueMap){
        auto status = writeRegister(addressValuePair.first, addressValuePair.second, timeoutMs);
        if(status != HAL_StatusTypeDef::HAL_OK){
            Log::debug("[Ov5640] write register value map failed, status: %u", status);
            return false;
        }
    }
    return true;
}

//void HAL_DCMI_ErrorCallback(DCMI_HandleTypeDef *hdcmi) {
//    (void)hdcmi;
//    Log::error("[HAL_DCMI_ErrorCallback]");
//}

//void HAL_DCMI_LineEventCallback(DCMI_HandleTypeDef *hdcmi) {
//    (void)hdcmi;
//    Log::debug("[HAL_DCMI_LineEventCallback]");
//}

//void HAL_DCMI_FrameEventCallback(DCMI_HandleTypeDef *hdcmi) {
//    (void)hdcmi;
//    Log::debug("[HAL_DCMI_FrameEventCallback]");
//}

//void HAL_DCMI_VsyncEventCallback(DCMI_HandleTypeDef *hdcmi) {
//    (void)hdcmi;
//    Log::debug("[HAL_DCMI_VsyncEventCallback]");
//}


const std::map<uint16_t, uint8_t> Ov5640::buildInitSequence() {
    return {
        // 24MHz input clock, 24MHz PCLK
        {0x3103, 0x03}, // system clock from PLL, bit[1]
        {0x3017, 0xff}, // FREX, Vsync, HREF, PCLK, D[9:6] output enable
        {0x3018, 0xff}, // D[5:0], GPIO[1:0] output enable
        {0x3034, 0x18}, // MIPI 8-bit
        {0x3037, 0x03}, // PLL root divider, bit[4], PLL pre-divider, bit[3:0]
        {0x3108, 0x01}, // PCLK root divider, bit[5:4], SCLK2x root divider, bit[3:2]
        // SCLK root divider, bit[1:0]
        {0x3630, 0x36},
        {0x3631, 0x0e},
        {0x3632, 0xe2},
        {0x3633, 0x12},
        {0x3621, 0xe0},
        {0x3704, 0xa0},
        {0x3703, 0x5a},
        {0x3715, 0x78},
        {0x3717, 0x01},
        {0x370b, 0x60},
        {0x3705, 0x1a},
        {0x3905, 0x02},
        {0x3906, 0x10},
        {0x3901, 0x0a},
        {0x3731, 0x12},
        {0x3600, 0x08}, // VCM control
        {0x3601, 0x33}, // VCM control
        {0x302d, 0x60}, // system control
        {0x3620, 0x52},
        {0x371b, 0x20},
        {0x471c, 0x50},
        {0x3a13, 0x43}, // pre-gain = 1.047x
        {0x3a18, 0x00}, // gain ceiling
        {0x3a19, 0xf8}, // gain ceiling = 15.5x
        {0x3635, 0x13},
        {0x3636, 0x03},
        {0x3634, 0x40},
        {0x3622, 0x01},
        // 50/60Hz detection 50/60Hz 
        {0x3c01, 0x34}, // Band auto, bit[7]
        {0x3c04, 0x28}, // threshold low sum
        {0x3c05, 0x98}, // threshold high sum
        {0x3c06, 0x00}, // light meter 1 threshold[15:8]
        {0x3c07, 0x08}, // light meter 1 threshold[7:0]
        {0x3c08, 0x00}, // light meter 2 threshold[15:8]
        {0x3c09, 0x1c}, // light meter 2 threshold[7:0]
        {0x3c0a, 0x9c}, // sample number[15:8]
        {0x3c0b, 0x40}, // sample number[7:0]
        {0x3810, 0x00}, // Timing Hoffset[11:8]
        {0x3811, 0x10}, // Timing Hoffset[7:0]
        {0x3812, 0x00}, // Timing Voffset[10:8]
        {0x3708, 0x64},
        {0x4001, 0x02}, // BLC start from line 2
        {0x4005, 0x1a}, // BLC always update
        {0x3000, 0x00}, // enable blocks
        {0x3004, 0xff}, // enable clocks
        {0x300e, 0x58}, // MIPI power down, DVP enable
        {0x302e, 0x00},
        {0x4300, 0x30}, // YUV 422, YUYV
        {0x501f, 0x00}, // YUV 422
        {0x440e, 0x00},
        {0x5000, 0xa7}, // Lenc on, raw gamma on, BPC on, WPC on, CIP on
        // AEC target 
        {0x3a0f, 0x30}, // stable range in high
        {0x3a10, 0x28}, // stable range in low
        {0x3a1b, 0x30}, // stable range out high
        {0x3a1e, 0x26}, // stable range out low
        {0x3a11, 0x60}, // fast zone high
        {0x3a1f, 0x14}, // fast zone low
        // Lens correction for ? 
        {0x5800, 0x23},
        {0x5801, 0x14},
        {0x5802, 0x0f},
        {0x5803, 0x0f},
        {0x5804, 0x12},
        {0x5805, 0x26},
        {0x5806, 0x0c},
        {0x5807, 0x08},
        {0x5808, 0x05},
        {0x5809, 0x05},
        {0x580a, 0x08},
        
        {0x580b, 0x0d},
        {0x580c, 0x08},
        {0x580d, 0x03},
        {0x580e, 0x00},
        {0x580f, 0x00},
        {0x5810, 0x03},
        {0x5811, 0x09},
        {0x5812, 0x07},
        {0x5813, 0x03},
        {0x5814, 0x00},
        {0x5815, 0x01},
        {0x5816, 0x03},
        {0x5817, 0x08},
        {0x5818, 0x0d},
        {0x5819, 0x08},
        {0x581a, 0x05},
        {0x581b, 0x06},
        {0x581c, 0x08},
        {0x581d, 0x0e},
        {0x581e, 0x29},
        {0x581f, 0x17},
        {0x5820, 0x11},
        {0x5821, 0x11},
        {0x5822, 0x15},
        {0x5823, 0x28},
        {0x5824, 0x46},
        {0x5825, 0x26},
        {0x5826, 0x08},
        {0x5827, 0x26},
        {0x5828, 0x64},
        {0x5829, 0x26},
        {0x582a, 0x24},
        {0x582b, 0x22},
        {0x582c, 0x24},
        {0x582d, 0x24},
        {0x582e, 0x06},
        {0x582f, 0x22},
        {0x5830, 0x40},
        {0x5831, 0x42},
        {0x5832, 0x24},
        {0x5833, 0x26},
        {0x5834, 0x24},
        {0x5835, 0x22},
        {0x5836, 0x22},
        {0x5837, 0x26},
        {0x5838, 0x44},
        {0x5839, 0x24},
        {0x583a, 0x26},
        {0x583b, 0x28},
        {0x583c, 0x42},
        {0x583d, 0xce}, // lenc BR offset
        // AWB 
        {0x5180, 0xff}, // AWB B block
        {0x5181, 0xf2}, // AWB control
        {0x5182, 0x00}, // [7:4] max local counter, [3:0] max fast counter
        {0x5183, 0x14}, // AWB advanced
        {0x5184, 0x25},
        {0x5185, 0x24},
        {0x5186, 0x09},
        {0x5187, 0x09},
        {0x5188, 0x09},
        {0x5189, 0x75},
        {0x518a, 0x54},
        {0x518b, 0xe0},
        {0x518c, 0xb2},
        {0x518d, 0x42},
        {0x518e, 0x3d},
        {0x518f, 0x56},
        {0x5190, 0x46},
        {0x5191, 0xf8}, // AWB top limit
        {0x5192, 0x04}, // AWB bottom limit
        {0x5193, 0x70}, // red limit
        {0x5194, 0xf0}, // green limit
        {0x5195, 0xf0}, // blue limit
        {0x5196, 0x03}, // AWB control
        {0x5197, 0x01}, // local limit
        {0x5198, 0x04},
        {0x5199, 0x12},
        {0x519a, 0x04},
        {0x519b, 0x00},
        {0x519c, 0x06},
        {0x519d, 0x82},
        {0x519e, 0x38}, // AWB control
        // Gamma 
        {0x5480, 0x01}, // Gamma bias plus on, bit[0]
        {0x5481, 0x08},
        {0x5482, 0x14},
        {0x5483, 0x28},
        {0x5484, 0x51},
        {0x5485, 0x65},
        {0x5486, 0x71},
        {0x5487, 0x7d},
        {0x5488, 0x87},
        {0x5489, 0x91},
        {0x548a, 0x9a},
        {0x548b, 0xaa},
        {0x548c, 0xb8},
        {0x548d, 0xcd},
        {0x548e, 0xdd},
        {0x548f, 0xea},
        {0x5490, 0x1d},
        // color matrix 	
        {0x5381, 0x1e}, // CMX1 for Y
        {0x5382, 0x5b}, // CMX2 for Y
        {0x5383, 0x08}, // CMX3 for Y
        {0x5384, 0x0a}, // CMX4 for U
        {0x5385, 0x7e}, // CMX5 for U
        {0x5386, 0x88}, // CMX6 for U
        {0x5387, 0x7c}, // CMX7 for V
        {0x5388, 0x6c}, // CMX8 for V
        {0x5389, 0x10}, // CMX9 for V
        {0x538a, 0x01}, // sign[9]
        {0x538b, 0x98}, // sign[8:1]
        // UV adjust UV 
        {0x5580, 0x06}, // saturation on, bit[1]
        {0x5583, 0x40},
        {0x5584, 0x10}, 
        {0x5589, 0x10},
        {0x558a, 0x00},
        {0x558b, 0xf8},
        {0x501d, 0x40}, // enable manual offset of contrast
        // CIP 
        {0x5300, 0x08}, // CIP sharpen MT threshold 1
        {0x5301, 0x30}, // CIP sharpen MT threshold 2
        {0x5302, 0x10}, // CIP sharpen MT offset 1
        {0x5303, 0x00}, // CIP sharpen MT offset 2
        {0x5304, 0x08}, // CIP DNS threshold 1
        {0x5305, 0x30}, // CIP DNS threshold 2
        {0x5306, 0x08}, // CIP DNS offset 1
        {0x5307, 0x16}, // CIP DNS offset 2
        {0x5309, 0x08}, // CIP sharpen TH threshold 1
        {0x530a, 0x30}, // CIP sharpen TH threshold 2
        {0x530b, 0x04}, // CIP sharpen TH offset 1
        {0x530c, 0x06}, // CIP sharpen TH offset 2
        {0x5025, 0x00}, 
        {0x3008, 0x02}, // wake up from standby, bit[6]
        
        {0x4740, 0x21}, //VSYNC active HIGH
    };
}

const std::map<uint16_t, uint8_t> Ov5640::buildRgb565Sequence() {
    return {
        {0x4300, 0x61},
        {0x501F, 0x01},
        {0x3035, 0x21}, // PLL
        {0x3036, 0x69}, // PLL
        {0x3c07, 0x07}, // lightmeter 1 threshold[7:0]
        {0x3820, 0x46}, // flip
        {0x3821, 0x00}, // mirror
        {0x3814, 0x31}, // timing X inc
        {0x3815, 0x31}, // timing Y inc
        {0x3800, 0x00}, // HS
        {0x3801, 0x00}, // HS
        {0x3802, 0x00}, // VS
        {0x3803, 0x00}, // VS
        {0x3804, 0x0a}, // HW (HE)
        {0x3805, 0x3f}, // HW (HE)
        {0x3806, 0x06}, // VH (VE)
        {0x3807, 0xa9}, // VH (VE)
        // 1280x800
        // (0x3808, 0x05), // DVPHO
        // (0x3809, 0x00), // DVPHO
        // (0x380a, 0x02), // DVPVO
        // (0x380b, 0xd0), // DVPVO
        // 1528 x 900
        {0x380c, 0x05}, // HTS
        {0x380d, 0xF8}, // HTS
        {0x380e, 0x03}, // VTS
        {0x380f, 0x84}, // VTS
        {0x3813, 0x04}, // timing V offset
        {0x3618, 0x00},
        {0x3612, 0x29},
        {0x3709, 0x52},
        {0x370c, 0x03},
        {0x3a02, 0x02}, // 60Hz max exposure
        {0x3a03, 0xe0}, // 60Hz max exposure 
    
        {0x3a14, 0x02}, // 50Hz max exposure
        {0x3a15, 0xe0}, // 50Hz max exposure
        {0x4004, 0x02}, // BLC line number
        {0x3002, 0x1c}, // reset JFIFO, SFIFO, JPG
        {0x3006, 0xc3}, // disable clock of JPEG2x, JPEG
        {0x4713, 0x03}, // JPEG mode 3
        {0x4407, 0x04}, // Quantization scale
        {0x460b, 0x37},
        {0x460c, 0x20},
        {0x4837, 0x16}, // MIPI global timing
        {0x3824, 0x04}, // PCLK manual divider
        {0x5001, 0xA3}, // SDE on, scale on, UV average off, color matrix on, AWB on
        {0x3503, 0x00}, // AEC/AGC on
    };
}