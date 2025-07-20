#include "Ov9281.h"

#include "cmsis_os2.h"
#include "cmsis_gcc.h"
#include "lwip/sockets.h"
#undef bind // to avoid conflicts with std functional bind
#include "utils/assert.h"
#include "utils/constants.h"
#include "utils/Log.h"
#include <stdio.h>


// initial sequences are based on 
// https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov9282.c
// and then modified using Ov9281 and Ov9282 data sheets

Ov9281::Ov9281(I2C_HandleTypeDef* i2c, uint8_t i2cSlaveAddress, DCMI_HandleTypeDef* dcmi) :
_i2c{i2c},
_i2cSlaveAddress{static_cast<uint16_t>(i2cSlaveAddress)},
_dcmi{dcmi},
_init13Fps{std::move(build13FpsSequence())},
_init72Fps{std::move(build72FpsSequence())}
{
    ASSERT(_i2c != nullptr);
    ASSERT(_dcmi != nullptr);

    if(!i2cMasterReady() || !i2cSlaveReady()){
        Log::warning("[Ov9281] I2C not ready");
    }
}

bool Ov9281::init(Fps fps) {
    _fps = fps;
    static constexpr uint16_t REGISTER_ADDRESS_MODE_SELECT {0x0100};
    static constexpr uint8_t MODE_STANDBY {0x00};
    static constexpr uint8_t MODE_STREAMING {0x01};
    // stop streaming
    if(!writeRegister(REGISTER_ADDRESS_MODE_SELECT, MODE_STANDBY)){
        Log::error("[Ov9281] select standby mode failed");
        return false;
    }

    switch (fps) {
        case Fps::_72:
            Log::info("[Ov9281] initializing ov9281 for high fps mode");
            if(!writeRegisters(_init72Fps)){
                Log::error("[Ov9281] write 72 fps sequence failed");
                return false;
            }
        break;
        case Fps::_13:
            Log::info("[Ov9281] initializing ov9281 for low fps mode");
            if(!writeRegisters(_init13Fps)){
                Log::error("[Ov9281] write 13 fps sequence failed");
                return false;
            }
        break;
        default:
            Log::error("[Ov9281] initializing abort fps %u is not supported", static_cast<uint8_t>(fps));
            return false;
    }

    // start streaming
    if(!writeRegister(REGISTER_ADDRESS_MODE_SELECT, MODE_STREAMING)){
        Log::error("[Ov9281] select streaming mode failed");
        return false;
    }
    return true;
}

uint16_t Ov9281::chipId() {
    static constexpr uint16_t REGISTER_ADDRESS_SC_CHIP_ID_HIGH {0x300a};
    static constexpr uint16_t REGISTER_ADDRESS_SC_CHIP_ID_LOW {0x300b};
    const auto idHighResult = readRegister(REGISTER_ADDRESS_SC_CHIP_ID_HIGH);
    if(!std::get<0>(idHighResult)){
        Log::error("[Ov9281] chip id high read failed");
        return 0;
    }
    const auto idLowResult = readRegister(REGISTER_ADDRESS_SC_CHIP_ID_LOW);
    if(!std::get<0>(idLowResult)){
        Log::error("[Ov9281] chip id low read failed");
        return 0;
    }
    return static_cast<uint16_t>(std::get<1>(idHighResult)) << 8 | static_cast<uint16_t>(std::get<1>(idLowResult));
}

bool Ov9281::exposure(uint16_t levelInteger, uint8_t levelFraction)
{
    static constexpr uint16_t REGISTER_ADDRESS_FRAME_LENGTH_HIGH {0x380E};
    static constexpr uint16_t REGISTER_ADDRESS_FRAME_LENGTH_LOW {0x380F};
    const auto frameLengthHighResult = readRegister(REGISTER_ADDRESS_FRAME_LENGTH_HIGH);
    if(!std::get<0>(frameLengthHighResult)){
        Log::error("[Ov9281] exposure: frame length high read failed");
        return false;
    }
    const auto frameLengthLowResult = readRegister(REGISTER_ADDRESS_FRAME_LENGTH_LOW);
    if(!std::get<0>(frameLengthLowResult)){
        Log::error("[Ov9281] exposure: frame length low read failed");
        return false;
    }
    const uint16_t frameLength = static_cast<uint16_t>(std::get<1>(frameLengthHighResult)) << 8 | static_cast<uint16_t>(std::get<1>(frameLengthLowResult));
    const uint16_t maximumExposure = frameLength - 25;

    if(levelInteger > 0x0fff) {
        Log::error("[Ov9281] exposure: integer bits (%u) exceed max value 0x0fff", levelFraction);
        return false;
    }
    if(levelFraction > 0x0f) {
        Log::error("[Ov9281] exposure: fractional bits (%u) exceed max value 0x0f", levelFraction);
        return false;
    }
    static constexpr size_t FRACTIONAL_BITS = 4;
    static constexpr float DIVISOR = 1 << FRACTIONAL_BITS;
    float exposure = static_cast<float>(levelInteger) + levelFraction / DIVISOR;
    if(exposure > maximumExposure) {
        Log::error("[Ov9281] exposure: level (%f) exceeds max value (%u)", exposure, maximumExposure);
        return false;
    }

    static constexpr uint16_t REGISTER_ADDRESS_AEC_EXPO_19_16 {0x3500};
    static constexpr uint16_t REGISTER_ADDRESS_AEC_EXPO_15_8 {0x3501};
    static constexpr uint16_t REGISTER_ADDRESS_AEC_EXPO_7_0 {0x3502};    
    
    uint8_t temp = ((levelInteger & 0x0f) << 4) | ((levelFraction & 0x0f) << 0);
    if(!writeRegister(REGISTER_ADDRESS_AEC_EXPO_7_0, temp)){
        Log::error("[Ov9281] exposure: write exposure [7:0] failed");
        return false;
    }
    temp = (levelInteger >> 4) & 0xff;
    if(!writeRegister(REGISTER_ADDRESS_AEC_EXPO_15_8, temp)){
        Log::error("[Ov9281] exposure: write exposure [15:8] failed");
        return false;
    }
    temp = (levelInteger >> 12) & 0x0f; 
    if(!writeRegister(REGISTER_ADDRESS_AEC_EXPO_19_16, temp)){
        Log::error("[Ov9281] exposure: write exposure [19:16] failed");
        return false;
    }
    return true;
}

bool Ov9281::gain(uint8_t level, uint8_t band)
{
    static constexpr uint8_t MAX_LEVEL {31U};
    if(level > MAX_LEVEL) {
        Log::error("[Ov9281] gain: level (%u) exceeds max level (%u)", level, MAX_LEVEL);
        return false;
    }
    static constexpr uint8_t MAX_BAND {7U};
    if(band > MAX_BAND) {
        Log::error("[Ov9281] gain: band (%u) exceeds max band (%u)", band, MAX_BAND);
        return false;
    }

    // use sensor gain format instead of real
    // this mode is used since it allows for lower gain than real gain format,
    // at the cost of having to experiment with level+band combos since the magic sauce behind the level to gain mapping
    // is not documented in the sensor data sheet or app notes

    if(!writeRegister(0x3503, 0x04)){
        Log::error("[Ov9281] gain: AEC manual write failed");
        return false;
    }

    static constexpr uint16_t REGISTER_ADDRESS_GAIN {0x3509};
    if(!writeRegister(REGISTER_ADDRESS_GAIN, level)){
        Log::error("[Ov9281] gain: write gain high failed");
        return false;
    }
    return true;
}

bool Ov9281::whitebalance(uint16_t red, uint16_t green, uint16_t blue)
{
    static constexpr uint16_t MAX_LEVEL{0xfff};
    if((red > MAX_LEVEL) || (green > MAX_LEVEL) || (blue > MAX_LEVEL)){
        Log::error("[Ov9281] Requested rbg levels the exeed limits");
        return false;
    }
    static constexpr uint16_t REGISTER_ADDRESS_AWB_RED_GAIN_HIGH {0x3400};
    static constexpr uint16_t REGISTER_ADDRESS_AWB_RED_GAIN_LOW {0x3401};
    static constexpr uint16_t REGISTER_ADDRESS_AWB_GREEN_GAIN_HIGH {0x3402};
    static constexpr uint16_t REGISTER_ADDRESS_AWB_GREEN_GAIN_LOW {0x3403};
    static constexpr uint16_t REGISTER_ADDRESS_AWB_BLUE_GAIN_HIGH {0x3404};
    static constexpr uint16_t REGISTER_ADDRESS_AWB_BLUE_GAIN_LOW {0x3405};
    static constexpr uint8_t ABW_GAIN_HIGH_OFFSET {8U};
    static constexpr uint8_t ABW_GAIN_LOW_OFFSET {0U};
    static constexpr uint8_t ABW_GAIN_HIGH_MASK {0x08U};
    static constexpr uint8_t ABW_GAIN_LOW_MASK {0xffU};
    // red
    if(!writeRegister(REGISTER_ADDRESS_AWB_RED_GAIN_HIGH, (red >> ABW_GAIN_HIGH_OFFSET) & ABW_GAIN_HIGH_MASK)){
        Log::error("[Ov9281] setting white balance red gain high failed");
        return false;
    }
    if(!writeRegister(REGISTER_ADDRESS_AWB_RED_GAIN_LOW, (red >> ABW_GAIN_LOW_OFFSET) & ABW_GAIN_LOW_MASK)){
        Log::error("[Ov9281] setting white balance red gain low failed");
        return false;
    }
    // green
    if(!writeRegister(REGISTER_ADDRESS_AWB_GREEN_GAIN_HIGH, (green >> ABW_GAIN_HIGH_OFFSET) & ABW_GAIN_HIGH_MASK)){
        Log::error("[Ov9281] setting white balance green gain high failed");
        return false;
    }
    if(!writeRegister(REGISTER_ADDRESS_AWB_GREEN_GAIN_LOW, (green >> ABW_GAIN_LOW_OFFSET) & ABW_GAIN_LOW_MASK)){
        Log::error("[Ov9281] setting white balance green gain low failed");
        return false;
    }
    // blue
    if(!writeRegister(REGISTER_ADDRESS_AWB_BLUE_GAIN_HIGH, (blue >> ABW_GAIN_HIGH_OFFSET) & ABW_GAIN_HIGH_MASK)){
        Log::error("[Ov9281] setting white balance blue gain high failed");
        return false;
    }
    if(!writeRegister(REGISTER_ADDRESS_AWB_BLUE_GAIN_LOW, (blue >> ABW_GAIN_LOW_OFFSET) & ABW_GAIN_LOW_MASK)){
        Log::error("[Ov9281] setting white balance blue gain low failed");
        return false;
    }
    return true;
}

//TODO: pass framebuffer
bool Ov9281::capture()
{
    if(_fps != Fps::_13) {
        Log::error("[Ov9281] capture abort, camera frame rate is not set to 13 fps");
        return false;
    }
    if(__HAL_DMA_GET_FLAG(_dcmi, DMA_FLAG_TEIF1_5)){
        Log::warning("[Ov9281] DMA transfer error flag is set");
        __HAL_DMA_CLEAR_FLAG(_dcmi, DMA_FLAG_TEIF1_5);
    }
    if(__HAL_DMA_GET_FLAG(_dcmi, DMA_FLAG_DMEIF1_5)){
        Log::warning("[Ov9281] DMA direct mode error flag is set");
        __HAL_DMA_CLEAR_FLAG(_dcmi, DMA_FLAG_DMEIF1_5);
    }
    if(__HAL_DMA_GET_FLAG(_dcmi, DMA_FLAG_FEIF1_5)){
        Log::warning("[Ov9281] DMA fifo error flag is set");
        __HAL_DMA_CLEAR_FLAG(_dcmi, DMA_FLAG_FEIF1_5);
    }
    auto dcmiState = _dcmi->State;
    auto dcmiErrorCode = _dcmi->ErrorCode;
    switch (dcmiState){
        case HAL_DCMI_StateTypeDef::HAL_DCMI_STATE_READY: {
            break;
        }
        case HAL_DCMI_StateTypeDef::HAL_DCMI_STATE_BUSY: {
            Log::error("[Ov9281] capture abort, DCMI busy");
            return false;
        }
        default: {
            Log::error("[Ov9281] capture abort, DCMI not ready, State: %d ErrorCode: %d", dcmiState, dcmiErrorCode);
            return false;
        }
    }
    
    Log::info("[Ov9281] starting capture");
    static constexpr size_t IMAGE_WIDTH_PIXELS {1280}; // Hardcoded to match 13 fps sequence
    static constexpr size_t IMAGE_HEIGHT_PIXELS {800}; // Hardcoded to match 13 fps sequence
    static constexpr size_t BYTES_PER_PIXEL {1};
    static constexpr size_t BYTES_PER_DMA_TRANSFER {4};
    auto startStatus = HAL_DCMI_Start_DMA(
        _dcmi,
        DCMI_MODE_SNAPSHOT,
        EXTERNAL_SDRAM_BASE_ADDRESS,
        IMAGE_WIDTH_PIXELS * IMAGE_HEIGHT_PIXELS * BYTES_PER_PIXEL / BYTES_PER_DMA_TRANSFER
    );

    if (startStatus != HAL_StatusTypeDef::HAL_OK){
        Log::error("[Ov9281] capture abort, start snapshot failed, dma status: %u", startStatus);
        return false;
    }
    bool success = false;
    bool timeout = true;
    static constexpr uint32_t FRAMERATE_FPS {13}; // Hardcoded to match 13 fps sequence
    static constexpr float SECONDS_PER_FRAME {1 / float(FRAMERATE_FPS)};
    (void)SECONDS_PER_FRAME;
    static constexpr uint32_t TICKS_PER_FRAME {static_cast<uint32_t>(SECONDS_PER_FRAME * float(TICKS_PER_SECOND) + 0.5)}; // std::ceil is not a constexpr ¯\_(ツ)_/¯
    
    static constexpr size_t MAX_WAIT_CYCLES {5};
    for(size_t i = 0; i < MAX_WAIT_CYCLES; i++){
        dcmiState = _dcmi->State;
        dcmiErrorCode = _dcmi->ErrorCode;
        if(dcmiState == HAL_DCMI_StateTypeDef::HAL_DCMI_STATE_READY){
            Log::info("[Ov9281] capture success, took %u cycles", i);
            success = true;
            timeout = false;
            break;
        }else if(dcmiState != HAL_DCMI_StateTypeDef::HAL_DCMI_STATE_BUSY){
            Log::warning("[Ov9281] capture abort (cycle %u), status: %u, errorCode: %d", i, dcmiState, dcmiErrorCode);
            success = false;
            timeout = false;
            break;
        }
        osDelay(TICKS_PER_FRAME);
    }
    if(timeout){
        // Hint: search for DCMI_Error_Code to figure out meaning of error code
        Log::warning("[Ov9281] capture timeout, status: %u, errorCode: %d", dcmiState, dcmiErrorCode);
    }
    HAL_DCMI_Stop(_dcmi);
    return success;
}

void Ov9281::abortCapture(){
   HAL_DCMI_Stop(_dcmi);
}

bool Ov9281::i2cMasterReady(){
    auto state = HAL_I2C_GetState(_i2c);
    if(state != HAL_I2C_StateTypeDef::HAL_I2C_STATE_READY){
        Log::warning("[Ov9281] I2C master not ready, state: %u", state);
        return false;
    }
    
    return true;
}
bool Ov9281::i2cSlaveReady(uint32_t retries, uint32_t timeoutMs){
    const uint32_t timeoutTicks {timeoutMs * TICKS_PER_MILLISECOND};
    auto status = HAL_I2C_IsDeviceReady(_i2c, _i2cSlaveAddress, retries, timeoutTicks);
    if(status != HAL_StatusTypeDef::HAL_OK){
        Log::warning("[Ov9281] I2C slave not ready, status: %u", status);
        return false;
    }
    return true;
}

std::tuple<bool, uint8_t> Ov9281::readRegister(uint16_t address, uint32_t timeoutMs) {
    static constexpr size_t WRITE_BUFFER_SIZE {2};
    uint8_t writeBuffer[WRITE_BUFFER_SIZE] {uint8_t(address >> 8), uint8_t(address >> 0)};
    const uint32_t timeoutTicks {timeoutMs * TICKS_PER_MILLISECOND};
    auto status = HAL_I2C_Master_Transmit(_i2c, _i2cSlaveAddress, writeBuffer, WRITE_BUFFER_SIZE, timeoutTicks);
    if(status != HAL_StatusTypeDef::HAL_OK){
        Log::debug("[Ov9281] I2C transmit failed, status: %u", status);
        return {false, 0};
    }
    
    uint8_t readBuffer;
    status = HAL_I2C_Master_Receive(_i2c, _i2cSlaveAddress, &readBuffer, sizeof(readBuffer), timeoutTicks);
    if(status != HAL_StatusTypeDef::HAL_OK){
        Log::debug("[Ov9281] I2C receive failed, status: %u", status);
        return {false, 0};
    }

    return {true, readBuffer};
}

bool Ov9281::writeRegister(uint16_t address, uint8_t data, uint32_t timeoutMs) {
    static constexpr size_t WRITE_BUFFER_SIZE {3};
    uint8_t writeBuffer[WRITE_BUFFER_SIZE] {uint8_t(address >> 8), uint8_t(address >> 0), data};
    const uint32_t timeoutTicks {timeoutMs * TICKS_PER_MILLISECOND};
    auto status = HAL_I2C_Master_Transmit(_i2c, _i2cSlaveAddress, writeBuffer, WRITE_BUFFER_SIZE, timeoutTicks);
    if(status != HAL_StatusTypeDef::HAL_OK){
        Log::debug("[Ov9281] write register failed, status: %u", status);
        return false;
    }
    return true;
}

bool Ov9281::writeRegisters(const std::map<uint16_t, uint8_t>& registerValueMap, const uint32_t timeoutMs) {
    for (auto const& addressValuePair : registerValueMap){
        if(!writeRegister(addressValuePair.first, addressValuePair.second, timeoutMs)){
            return false;
        }
    }
    return true;
}

void HAL_DCMI_ErrorCallback(DCMI_HandleTypeDef *hdcmi) {
    (void)hdcmi;
    Log::error("[HAL_DCMI_ErrorCallback]");
}

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

const std::map<uint16_t, uint8_t> Ov9281::build13FpsSequence() {
    // default:
    //  Value as described in OV9282 Camera Module Application Notes R1.00 1280x800  RAW10 72 FPS DVP sequence.
    //  Value matched default register value as documented in OV9281 data sheet v1.53
    // non-default:
    //  Value as described in OV9282 Camera Module Application Notes R1.00 1280x800  RAW10 72 FPS DVP sequence.
    //  Value differs from default register value as documented in OV9281 data sheet v1.53.
    // user-modified:
    //  Value changed by user
    // user-added:
    //  Value not configured in reference sequence
    return {
        {0x0103, 0x01}, // software reset on
        {0x0302, 0x30}, // pll1 multiplier[7:0]
        {0x030d, 0x60}, // pll2 multiplier[7:0] -> 140
        {0x030e, 0x06}, // pll2 system divider -> 1/4
        {0x0303, 0x01}, // user-added, slow down PCLK <- slow down to 13 fps
        {0x3001, 0x62}, // non-default, I/O pin drive capacity 4x
        {0x3004, 0x01}, // non-default, output control enable D9
        {0x3005, 0xfe}, // user-modified, output control enable D8-D2, disable D1
        {0x3006, 0x62}, // user-modified, output control disable D0, enable PCLK, HREF, VYSNC
        {0x3011, 0x0a}, // non-default, system control
        {0x3013, 0x18}, // non-default, system control
        {0x301c, 0xf0}, // non-default, system control
        {0x3022, 0x07}, // non-default, system control
        {0x3030, 0x10}, // default, system control
        {0x3039, 0x2e}, // non-default, system control enable DVP
        {0x303a, 0xf0}, // non-default, MIPI lane disable
        {0x3500, 0x00}, // default, exposure control
        {0x3501, 0x2a}, // non-default, exposure control
        {0x3502, 0x90}, // non-default, exposure control
        {0x3503, 0x08}, // non-default, AEC manual
        {0x3505, 0x8c}, // non-default, gain conversation option
        {0x3507, 0x03}, // non-default, gain shift
        {0x3508, 0x00}, // unknown, undocumented debug register
        {0x3509, 0x10}, // non-default, gain control
        {0x3610, 0x80}, // unknown, undocumented analog register
        {0x3611, 0xa0}, // unknown, undocumented analog register
        {0x3620, 0x6e}, // unknown, undocumented analog register
        {0x3632, 0x56}, // unknown, undocumented analog register
        {0x3633, 0x78}, // unknown, undocumented analog register
        {0x3662, 0x05}, // default, MIPI 2-lane, RAW10
        {0x3666, 0x5a}, // non-default, VSYNC output select, internal frame sync fixed value 0
        {0x366f, 0x7e}, // unknown, undocumented analog register
        {0x3680, 0x84}, // unknown, undocumented analog register
        {0x3712, 0x80}, // unknown, undocumented sensor control register
        {0x372d, 0x22}, // unknown, undocumented sensor control register
        {0x3731, 0x80}, // unknown, undocumented sensor control register
        {0x3732, 0x30}, // unknown, undocumented sensor control register
        {0x3778, 0x00}, // default, disable vertical binning
        {0x377d, 0x22}, // unknown, undocumented sensor control register
        {0x3788, 0x02}, // unknown, undocumented sensor control register
        {0x3789, 0xa4}, // unknown, undocumented sensor control register
        {0x378a, 0x00}, // unknown, undocumented sensor control register
        {0x378b, 0x4a}, // unknown, undocumented sensor control register
        {0x3799, 0x20}, // unknown, undocumented sensor control register
        {0x3800, 0x00},
        {0x3801, 0x00}, // default, Timing X addr start 0
        {0x3802, 0x00},
        {0x3803, 0x00}, // default, Timing Y addr start 0
        {0x3804, 0x05},
        {0x3805, 0x0f}, // default, Timing X addr end 1295
        {0x3806, 0x03},
        {0x3807, 0x2f}, // default, Timing X addr end 815
        {0x3808, 0x05},
        {0x3809, 0x00}, // default, Timing X output size 1280
        {0x380a, 0x03}, 
        {0x380b, 0x20}, // default, Timing Y output size 800
        {0x380c, 0x0f},
        {0x380d, 0xd8}, // user-modified, HTS 4056 <- slow down to 13 fps
        {0x380e, 0x03},
        {0x380f, 0x8e}, // default, VTS 910
        {0x3810, 0x00},
        {0x3811, 0x08}, // default, Timing ISP X win offset 8
        {0x3812, 0x00},
        {0x3813, 0x08}, // default, Timing ISP Y win offset 8
        {0x3814, 0x11}, // default, Timing X increment odd 1 even 1
        {0x3815, 0x11}, // default, Timing Y increment odd 1 even 1
        {0x3820, 0x44}, // user-modified, flip image orientation
        {0x3821, 0x04}, // user-modified, mirror image
        {0x382c, 0x05},
        {0x382d, 0xb0}, // default, HTS global TX 1456
        {0x389d, 0x00}, // unknown, undocumented global shutter control
        {0x3881, 0x42}, // unknown, undocumented global shutter control
        {0x3882, 0x01}, // unknown, undocumented global shutter control
        {0x3883, 0x00}, // unknown, undocumented global shutter control
        {0x3885, 0x02}, // unknown, undocumented global shutter control
        {0x38a8, 0x02}, // unknown, undocumented global shutter control
        {0x38a9, 0x80}, // unknown, undocumented global shutter control
        {0x38b1, 0x00}, // unknown, undocumented global shutter control
        {0x38b3, 0x02}, // unknown, undocumented global shutter control
        {0x38c4, 0x00}, // unknown, undocumented global shutter control
        {0x38c5, 0xc0}, // unknown, undocumented global shutter control
        {0x38c6, 0x04}, // unknown, undocumented global shutter control
        {0x38c7, 0x80}, // unknown, undocumented global shutter control
        {0x3920, 0xff}, // non-default, strobe pattern
        {0x4003, 0x40}, // non-default, BLC
        {0x4008, 0x04}, // non-default, BLC
        {0x4009, 0x0b}, // non-default, BLC
        {0x400c, 0x00}, // default, BLC
        {0x400d, 0x07}, // default, BLC
        {0x4010, 0x40}, // default, BLC
        {0x4043, 0x40}, // non-default, BLC
        {0x4307, 0x30}, // default, format control "embed_st"
        {0x4317, 0x01}, // non-default, enable DVP
        {0x4501, 0x00}, // unknown, undocumented readout control registers
        {0x4507, 0x00}, // unknown, undocumented readout control registers
        {0x4509, 0x00}, // unknown, undocumented readout control register
        {0x450a, 0x08}, // unknown, undocumented readout control register
        {0x4601, 0x04}, // default, VFIFO read start point
        {0x470f, 0xe0}, // non-default, DVP control "Reserved" section of BYP_SEL register
        {0x4f07, 0x00}, // non-default, low power mode control
        {0x4800, 0x00}, // non-default, MIPI control
        {0x5000, 0x9f}, // default, BLC enable
        {0x5001, 0x00}, // default, ISP control
        {0x5e00, 0x00}, // default, disable test pattern (0x80 to enable)
        {0x5d00, 0x0b}, // undocumented sensor control register
        {0x5d01, 0x02}, // undocumented sensor control register
        {0x4f00, 0x00}, // user-modified, low power control pclk free running
        {0x4f10, 0x00}, // low power control "ana_psv_pch[15:8]"
        {0x4f11, 0x98}, // low power control "ana_psv_pch[7:0]" -> 152
        {0x4f12, 0x0f}, // low power control "ana_psv_stm[15:8]"
        {0x4f13, 0xc4}, // low power control "ana_psv_stm[7:0]" -> 4036

        {0x0100, 0x01}, // select streaming mode
    };
}

const std::map<uint16_t, uint8_t> Ov9281::build72FpsSequence() {
    // default:
    //  Value as described in OV9282 Camera Module Application Notes R1.00 1280x800  RAW10 72 FPS DVP sequence.
    //  Value matched default register value as documented in OV9281 data sheet v1.53
    // non-default:
    //  Value as described in OV9282 Camera Module Application Notes R1.00 1280x800  RAW10 72 FPS DVP sequence.
    //  Value differs from default register value as documented in OV9281 data sheet v1.53.
    // user-modified:
    //  Value changed by user
    // user-added:
    //  Value not configured in reference sequence
    return {
        {0x0103, 0x01}, // software reset on
        {0x0302, 0x30}, // pll1 multiplier[7:0]
        {0x030d, 0x60}, // pll2 multiplier[7:0] -> 140
        {0x030e, 0x06}, // pll2 system divider -> 1/4
        {0x3001, 0x62}, // non-default, I/O pin drive capacity 4x
        {0x3004, 0x01}, // non-default, output control enable D9
        {0x3005, 0xfe}, // user-modified, output control enable D8-D2, disable D1
        {0x3006, 0x62}, // user-modified, output control disable D0, enable PCLK, HREF, VYSNC
        {0x3011, 0x0a}, // non-default, system control
        {0x3013, 0x18}, // non-default, system control
        {0x301c, 0xf0}, // non-default, system control
        {0x3022, 0x07}, // non-default, system control
        {0x3030, 0x10}, // default, system control
        {0x3039, 0x2e}, // non-default, system control enable DVP
        {0x303a, 0xf0}, // non-default, MIPI lane disable
        {0x3500, 0x00}, // default, exposure control
        {0x3501, 0x2a}, // non-default, exposure control
        {0x3502, 0x90}, // non-default, exposure control
        {0x3503, 0x08}, // non-default, AEC manual
        {0x3505, 0x8c}, // non-default, gain conversation option
        {0x3507, 0x03}, // non-default, gain shift
        {0x3508, 0x00}, // unknown, undocumented debug register
        {0x3509, 0x10}, // non-default, gain control
        {0x3610, 0x80}, // unknown, undocumented analog register
        {0x3611, 0xa0}, // unknown, undocumented analog register
        {0x3620, 0x6e}, // unknown, undocumented analog register
        {0x3632, 0x56}, // unknown, undocumented analog register
        {0x3633, 0x78}, // unknown, undocumented analog register
        {0x3662, 0x05}, // default, MIPI 2-lane, RAW10
        {0x3666, 0x5a}, // non-default, VSYNC output select, internal frame sync fixed value 0
        {0x366f, 0x7e}, // unknown, undocumented analog register
        {0x3680, 0x84}, // unknown, undocumented analog register
        {0x3712, 0x80}, // unknown, undocumented sensor control register
        {0x372d, 0x22}, // unknown, undocumented sensor control register
        {0x3731, 0x80}, // unknown, undocumented sensor control register
        {0x3732, 0x30}, // unknown, undocumented sensor control register
        {0x3778, 0x00}, // default, disable vertical binning
        {0x377d, 0x22}, // unknown, undocumented sensor control register
        {0x3788, 0x02}, // unknown, undocumented sensor control register
        {0x3789, 0xa4}, // unknown, undocumented sensor control register
        {0x378a, 0x00}, // unknown, undocumented sensor control register
        {0x378b, 0x4a}, // unknown, undocumented sensor control register
        {0x3799, 0x20}, // unknown, undocumented sensor control register
        {0x3800, 0x00},
        {0x3801, 0x00}, // default, Timing X addr start 0
        {0x3802, 0x00},
        {0x3803, 0x00}, // default, Timing Y addr start 0
        {0x3804, 0x05},
        {0x3805, 0x0f}, // default, Timing X addr end 1295
        {0x3806, 0x03},
        {0x3807, 0x2f}, // default, Timing X addr end 815
        {0x3808, 0x05},
        {0x3809, 0x00}, // default, Timing X output size 1280
        {0x380a, 0x03}, 
        {0x380b, 0x20}, // default, Timing Y output size 800
        {0x380c, 0x02},
        {0x380d, 0xd8}, // default, HTS 728
        {0x380e, 0x03},
        {0x380f, 0x8e}, // default, VTS 910
        {0x3810, 0x00},
        {0x3811, 0x08}, // default, Timing ISP X win offset 8
        {0x3812, 0x00},
        {0x3813, 0x08}, // default, Timing ISP Y win offset 8
        {0x3814, 0x11}, // default, Timing X increment odd 1 even 1
        {0x3815, 0x11}, // default, Timing Y increment odd 1 even 1
        {0x3820, 0x44}, // user-modified, flip image orientation
        {0x3821, 0x04}, // user-modified, mirror image
        {0x382c, 0x05},
        {0x382d, 0xb0}, // default, HTS global TX 1456
        {0x389d, 0x00}, // unknown, undocumented global shutter control
        {0x3881, 0x42}, // unknown, undocumented global shutter control
        {0x3882, 0x01}, // unknown, undocumented global shutter control
        {0x3883, 0x00}, // unknown, undocumented global shutter control
        {0x3885, 0x02}, // unknown, undocumented global shutter control
        {0x38a8, 0x02}, // unknown, undocumented global shutter control
        {0x38a9, 0x80}, // unknown, undocumented global shutter control
        {0x38b1, 0x00}, // unknown, undocumented global shutter control
        {0x38b3, 0x02}, // unknown, undocumented global shutter control
        {0x38c4, 0x00}, // unknown, undocumented global shutter control
        {0x38c5, 0xc0}, // unknown, undocumented global shutter control
        {0x38c6, 0x04}, // unknown, undocumented global shutter control
        {0x38c7, 0x80}, // unknown, undocumented global shutter control
        {0x3920, 0xff}, // non-default, strobe pattern
        {0x4003, 0x40}, // non-default, BLC
        {0x4008, 0x04}, // non-default, BLC
        {0x4009, 0x0b}, // non-default, BLC
        {0x400c, 0x00}, // default, BLC
        {0x400d, 0x07}, // default, BLC
        {0x4010, 0x40}, // default, BLC
        {0x4043, 0x40}, // non-default, BLC
        {0x4307, 0x30}, // default, format control "embed_st"
        {0x4317, 0x01}, // non-default, enable DVP
        {0x4501, 0x00}, // unknown, undocumented readout control registers
        {0x4507, 0x00}, // unknown, undocumented readout control registers
        {0x4509, 0x00}, // unknown, undocumented readout control register
        {0x450a, 0x08}, // unknown, undocumented readout control register
        {0x4601, 0x04}, // default, VFIFO read start point
        {0x470f, 0xe0}, // non-default, DVP control "Reserved" section of BYP_SEL register
        {0x4f07, 0x00}, // non-default, low power mode control
        {0x4800, 0x00}, // non-default, MIPI control
        {0x5000, 0x9f}, // default, BLC enable
        {0x5001, 0x00}, // default, ISP control
        {0x5e00, 0x00}, // default, disable test pattern (0x80 to enable)
        {0x5d00, 0x0b}, // undocumented sensor control register
        {0x5d01, 0x02}, // undocumented sensor control register
        {0x4f00, 0x00}, // user-modified, low power control pclk free running
        {0x4f10, 0x00}, // low power control "ana_psv_pch[15:8]"
        {0x4f11, 0x98}, // low power control "ana_psv_pch[7:0]" -> 152
        {0x4f12, 0x0f}, // low power control "ana_psv_stm[15:8]"
        {0x4f13, 0xc4}, // low power control "ana_psv_stm[7:0]" -> 4036

        {0x0100, 0x01}, // select streaming mode
    };
}
