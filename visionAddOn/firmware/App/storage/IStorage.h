#ifndef VISIONADDON_APP_UTILS_STORAGE_ISTORAGE_H
#define VISIONADDON_APP_UTILS_STORAGE_ISTORAGE_H

#include <cstddef>
#include <cstdint>

class IStorage {
public:
    virtual bool writeData(uint8_t address, uint8_t data, uint32_t timeoutMs = 10) = 0; //!< write 1 byte
    virtual bool writeData(uint8_t address, uint32_t data, uint32_t timeoutMs = 10) = 0; //!< write 4 bytes
    virtual bool writeData(uint8_t address, uint64_t data, uint32_t timeoutMs = 10) = 0; //!< write 8 bytes
    virtual bool writeData(uint8_t address, const uint8_t* data, size_t size, uint32_t timeoutMs = 10) = 0; //!< write <size> bytes
    virtual bool readData(uint8_t address, uint8_t& data, uint32_t timeoutMs = 10) = 0; //!< read 1 bytes
    virtual bool readData(uint8_t address, uint32_t& data, uint32_t timeoutMs = 10) = 0; //!< read 4 bytes
    virtual bool readData(uint8_t address, uint64_t& data, uint32_t timeoutMs = 10) = 0; //!< read 8 bytes
    virtual bool readData(uint8_t address, uint8_t* data, size_t size, uint32_t timeoutMs = 10) = 0; //!< read <size> bytes
    virtual bool isBusy( uint32_t timeoutMs = 1) = 0; //!< check if storage is busy
};

#endif // VISIONADDON_APP_UTILS_STORAGE_ISTORAGE_H