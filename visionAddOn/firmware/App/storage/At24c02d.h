#ifndef VISIONADDON_APP_STORAGE_AT24C02D_H
#define VISIONADDON_APP_STORAGE_AT24C02D_H

#include "IStorage.h"
#include "stm32f7xx_hal.h"

#include <cstdint>
#include <stdbool.h>
#include <variant>

//TODO: must be called from same thread as camera since they share i2c4
class At24c02d final : public IStorage {
public:
    At24c02d(I2C_HandleTypeDef* i2c, uint8_t i2cSlaveAddressRead, uint8_t i2cSlaveAddressWrite);
    At24c02d (const At24c02d&) = delete;
    At24c02d& operator=(const At24c02d&) = delete;
    At24c02d (const At24c02d&&) = delete;
    At24c02d& operator=(const At24c02d&&) = delete;

    bool writeData(uint8_t address, uint8_t data, uint32_t timeoutMs) override;
    bool writeData(uint8_t address, uint32_t data, uint32_t timeoutMs) override;
    bool writeData(uint8_t address, uint64_t data, uint32_t timeoutMs) override;
    bool writeData(uint8_t address, const uint8_t* data, size_t size, uint32_t timeoutMs) override;
    bool readData(uint8_t address, uint8_t& data, uint32_t timeoutMs) override;
    bool readData(uint8_t address, uint32_t& data, uint32_t timeoutMs) override;
    bool readData(uint8_t address, uint64_t& data, uint32_t timeoutMs) override;
    bool readData(uint8_t address, uint8_t* data, size_t size, uint32_t timeoutMs = 10) override;
    bool isBusy( uint32_t timeoutMs) override;
private:

    bool i2cMasterReady();
    bool i2cSlaveReady(uint32_t retires = 1, uint32_t timeoutMs = 1);

    I2C_HandleTypeDef* _i2c;
    const uint16_t _i2cSlaveAddressRead;
    const uint16_t _i2cSlaveAddressWrite;
   
};

#endif // VISIONADDON_APP_STORAGE_AT24C02D_H