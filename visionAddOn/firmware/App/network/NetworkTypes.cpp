#include "NetworkTypes.h"

bool IpV4Address::toBytes(uint8_t* buffer, size_t size) {
    if(SIZE > size) {
        return false;
    }
    buffer[0] = octet0;
    buffer[1] = octet1;
    buffer[2] = octet2;
    buffer[3] = octet3;
    return true;
}

bool IpV4Address::fromBytes(const uint8_t* buffer, size_t size) {
    if(SIZE > size) {
        return false;
    }
    octet0 = buffer[0];
    octet1 = buffer[1];
    octet2 = buffer[2];
    octet3 = buffer[3];
    return true;
}

uint32_t IpV4Address::toU32() {
    return ((static_cast<uint32_t>(octet0) << 24) & 0xff000000)
    + ((static_cast<uint32_t>(octet1) << 16) & 0x00ff0000)
    + ((static_cast<uint32_t>(octet2) <<  8) & 0x0000ff00)
    + ((static_cast<uint32_t>(octet3) <<  0) & 0x000000ff);
}

void IpV4Address::fromU32(uint32_t src) {
    octet0 = static_cast<uint8_t>((src >> 24) & 0xff);
    octet1 = static_cast<uint8_t>((src >> 16) & 0xff);
    octet2 = static_cast<uint8_t>((src >>  8) & 0xff);
    octet3 = static_cast<uint8_t>((src >>  0) & 0xff);
}

ip4_addr_t IpV4Address::toLwip() {
    ip4_addr_t dst {}; 
    IP4_ADDR(&dst, octet0, octet1, octet2, octet3);
    return dst;
}

void IpV4Address::fromLwip(ip4_addr_t src) {
    uint32_t raw = PP_NTOHL(src.addr);
    octet0 = static_cast<uint8_t>((raw >> 24) & 0xff);
    octet1 = static_cast<uint8_t>((raw >> 16) & 0xff);
    octet2 = static_cast<uint8_t>((raw >> 8) & 0xff);
    octet3 = static_cast<uint8_t>((raw >> 0) & 0xff);
}

bool MacAddress::toBytes(uint8_t* buffer, size_t size) {
    if(SIZE > size) {
        return false;
    }
    buffer[0] = octet0;
    buffer[1] = octet1;
    buffer[2] = octet2;
    buffer[3] = octet3;
    buffer[4] = octet4;
    buffer[5] = octet5;
    return true;
}

bool MacAddress::fromBytes(const uint8_t* buffer, size_t size) {
    if(SIZE > size) {
        return false;
    }
    octet0 = buffer[0];
    octet1 = buffer[1];
    octet2 = buffer[2];
    octet3 = buffer[3];
    octet4 = buffer[4];
    octet5 = buffer[5];
    return true;
}

uint64_t MacAddress::toU64()
{
    return ((static_cast<uint64_t>(octet0) << 40) & 0xff0000000000)
     + ((static_cast<uint64_t>(octet1) << 32) & 0x00ff00000000)
     + ((static_cast<uint64_t>(octet2) << 24) & 0x0000ff000000)
     + ((static_cast<uint64_t>(octet3) << 16) & 0x000000ff0000)
     + ((static_cast<uint64_t>(octet4) <<  8) & 0x00000000ff00)
     + ((static_cast<uint64_t>(octet5) <<  0) & 0x0000000000ff);
}

void MacAddress::fromU64(uint64_t src)
{
    octet0 = static_cast<uint8_t>((src >> 40) & 0xff);
    octet1 = static_cast<uint8_t>((src >> 32) & 0xff);
    octet2 = static_cast<uint8_t>((src >> 24) & 0xff);
    octet3 = static_cast<uint8_t>((src >> 16) & 0xff);
    octet4 = static_cast<uint8_t>((src >>  8) & 0xff);
    octet5 = static_cast<uint8_t>((src >>  0) & 0xff);
}
