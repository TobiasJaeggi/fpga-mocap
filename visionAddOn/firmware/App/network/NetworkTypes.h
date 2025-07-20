#ifndef VISIONADDON_APP_NETWORK_NETWORKTYPES_H
#define VISIONADDON_APP_NETWORK_NETWORKTYPES_H

#include "ip4_addr.h"

#include <cstdint>

class IpV4Address {
public:
    IpV4Address() = default;

    uint8_t octet0 = {};
    uint8_t octet1 = {};
    uint8_t octet2 = {};
    uint8_t octet3 = {};

    static constexpr size_t SIZE = 4;
    bool fromBytes(const uint8_t* buffer, size_t size);
    bool toBytes(uint8_t* buffer, size_t size);

    uint32_t toU32();
    void fromU32(uint32_t src);

    void fromLwip(ip4_addr_t src);
    ip4_addr_t toLwip();
};

class MacAddress {
public:
    MacAddress() = default;

    uint8_t octet0 = {};
    uint8_t octet1 = {};
    uint8_t octet2 = {};
    uint8_t octet3 = {};
    uint8_t octet4 = {};
    uint8_t octet5 = {};

    static constexpr size_t SIZE = 6;
    bool fromBytes(const uint8_t* buffer, size_t size);
    bool toBytes(uint8_t* buffer, size_t size);

    uint64_t toU64();
    void fromU64(uint64_t src);
};

#endif // VISIONADDON_APP_NETWORK_NETWORKTYPES_H