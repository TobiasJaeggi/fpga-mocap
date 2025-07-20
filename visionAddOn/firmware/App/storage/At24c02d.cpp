#include "At24c02d.h"

#include "utils/assert.h"
#include "utils/constants.h"
#include "utils/Log.h"
#include <stdio.h>

At24c02d::At24c02d(I2C_HandleTypeDef* i2c, uint8_t i2cSlaveAddressRead, uint8_t i2cSlaveAddressWrite) :
_i2c{i2c},
_i2cSlaveAddressRead{uint16_t(i2cSlaveAddressRead)},
_i2cSlaveAddressWrite{uint16_t(i2cSlaveAddressWrite)}
{
    ASSERT(_i2c != nullptr);
    if(!i2cMasterReady() || !i2cSlaveReady()){
        Log::warning("[At24c02d] I2C not ready");
    }
}


bool At24c02d::writeData(uint8_t address, uint8_t data, uint32_t timeoutMs) {
    return writeData(address, reinterpret_cast<uint8_t*>(&data), sizeof(data), timeoutMs);
}

bool At24c02d::writeData(uint8_t address, uint32_t data, uint32_t timeoutMs) {
    return writeData(address, reinterpret_cast<uint8_t*>(&data), sizeof(data), timeoutMs);
}

bool At24c02d::writeData(uint8_t address, uint64_t data, uint32_t timeoutMs) {
    return writeData(address, reinterpret_cast<uint8_t*>(&data), sizeof(data), timeoutMs);
}

bool At24c02d::writeData(uint8_t address, const uint8_t* data, size_t size, uint32_t timeoutMs)
{
    Log::debug("[At24c02d] writing %u bytes to %#x", size, address);
    auto currentTimeMs = [&]() -> uint32_t {
        uint32_t time = HAL_GetTick() * TICKS_PER_MILLISECOND; // use hal instead of kernel since os might not yet be running
        return time;
    };
    const uint32_t startTimeMs = currentTimeMs();

    uint8_t writeAddress {address};
    size_t bytesRemaining {size};
    const uint8_t* writePointer = data;
    while(bytesRemaining > 0) {
        const int32_t timeRemainingMs = timeoutMs - (currentTimeMs() - startTimeMs);
        if(timeRemainingMs <= 0) {
            Log::warning("[At24c02d] write abort, timeout reached");
            return false;
        }

        static constexpr uint32_t DO_NOT_WAIT {0U};
        while(isBusy(DO_NOT_WAIT)){
            if((currentTimeMs() - startTimeMs) > timeoutMs){
                Log::warning("[At24c02d] write abort, timeout reached (I2C busy)");
                return false;
            }
            Log::trace("[At24c02d] I2C busy, waiting");
            static constexpr uint32_t WAIT_MS {1U};
            HAL_Delay(WAIT_MS); //intentionally blocking
        }

        size_t PAGE_SIZE {8};
        uint8_t pageOffset = address % PAGE_SIZE;
        size_t bytesInCurrenPage = PAGE_SIZE - pageOffset;
        size_t bytesToWrite = (bytesRemaining < bytesInCurrenPage) ? bytesRemaining : bytesInCurrenPage;
        const uint32_t timeoutTicks {timeRemainingMs * TICKS_PER_MILLISECOND};
        auto status = HAL_I2C_Mem_Write(_i2c, _i2cSlaveAddressWrite, uint16_t(writeAddress), uint16_t(sizeof(writeAddress)), const_cast<uint8_t*>(writePointer), bytesToWrite, timeoutTicks);
        if(status != HAL_OK){
            Log::warning("[At24c02d] write abort, I2C transmit failed, status: %u", status);
            return false;
        }

        // next page
        writeAddress += bytesToWrite;
        writePointer += bytesToWrite;
        bytesRemaining -= bytesToWrite;  
    }
    return true;
}

bool At24c02d::readData(uint8_t address, uint8_t& data, uint32_t timeoutMs){
    return readData(address, reinterpret_cast<uint8_t*>(&data), sizeof(data), timeoutMs);
}

bool At24c02d::readData(uint8_t address, uint32_t& data, uint32_t timeoutMs){
    return readData(address, reinterpret_cast<uint8_t*>(&data), sizeof(data), timeoutMs);
}


bool At24c02d::readData(uint8_t address, uint64_t& data, uint32_t timeoutMs){
    return readData(address, reinterpret_cast<uint8_t*>(&data), sizeof(data), timeoutMs);
}

bool At24c02d::readData(uint8_t address, uint8_t* data, size_t size, uint32_t timeoutMs)
{
    Log::debug("[At24c02d] reading %u bytes from %#x", size, address);
    auto currentTimeMs = [&]() -> uint32_t {
        uint32_t time = HAL_GetTick() * TICKS_PER_MILLISECOND; // use hal instead of kernel since os might not yet be running
        return time;
    };
    const uint32_t startTimeMs = currentTimeMs();
    static constexpr uint32_t DO_NOT_WAIT {0U};
    while(isBusy(DO_NOT_WAIT)){
        if((currentTimeMs() - startTimeMs) > timeoutMs){
            Log::warning("[At24c02d] write abort, I2C busy");
            return false;
        }
        Log::trace("[At24c02d] I2C busy, waiting");
        static constexpr uint32_t WAIT_MS {1U};
        HAL_Delay(WAIT_MS); //intentionally blocking
    }

    const uint32_t timeRemainingMs = timeoutMs - (currentTimeMs() - startTimeMs);
    const uint32_t timeoutTicks {timeRemainingMs * TICKS_PER_MILLISECOND};

    auto status = HAL_I2C_Mem_Read(_i2c, _i2cSlaveAddressRead, uint16_t(address), uint16_t(sizeof(address)), data, size, timeoutTicks);
    if(status != HAL_StatusTypeDef::HAL_OK){
        Log::warning("[At24c02d] I2C mem read failed, status: %u", status);
        return false;
    }
    return true;
}

bool At24c02d::isBusy(uint32_t timeoutMs){
    return !i2cSlaveReady(timeoutMs);
}

bool At24c02d::i2cMasterReady(){
    auto state = HAL_I2C_GetState(_i2c);
    if(state != HAL_I2C_StateTypeDef::HAL_I2C_STATE_READY){
        Log::warning("[At24c02d] I2C master not ready, state: %u", state);
        return false;
    }
    return true;
}

bool At24c02d::i2cSlaveReady(const uint32_t retries, const uint32_t timeoutMs){
    const uint32_t timeoutTicks {timeoutMs * TICKS_PER_MILLISECOND};
    auto status = HAL_I2C_IsDeviceReady(_i2c, _i2cSlaveAddressRead, retries, timeoutTicks); //TODO: correct addr?
    return status == HAL_StatusTypeDef::HAL_OK;
}
