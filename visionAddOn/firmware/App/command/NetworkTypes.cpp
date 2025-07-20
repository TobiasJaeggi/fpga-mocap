#include "NetworkTypes.h"


ip4_addr_t toLwip(const IpV4Address src)
{
    ip4_addr_t dst {}; 
    IP4_ADDR(&dst, src.octet0, src.octet1, src.octet2, src.octet3);
    return dst;
}

IpV4Address toIpv4(const ip4_addr_t* src)
{
    uint32_t raw = PP_NTOHL(src->addr);
    IpV4Address dst {
        static_cast<uint8_t>((raw >> 24) & 0xff),
        static_cast<uint8_t>((raw >> 16) & 0xff),
        static_cast<uint8_t>((raw >> 8) & 0xff),
        static_cast<uint8_t>((raw >> 0) & 0xff),
    };
    return dst;
}

uint64_t toU64(const IpV4Address src)
{
    return ((static_cast<uint64_t>(src.octet0) << 24) & 0xff000000)
     + ((static_cast<uint64_t>(src.octet1) << 16) & 0x00ff0000)
     + ((static_cast<uint64_t>(src.octet2) <<  8) & 0x0000ff00)
     + ((static_cast<uint64_t>(src.octet3) <<  0) & 0x000000ff);
}

IpV4Address toIpv4(const uint64_t src)
{
    IpV4Address dst {
        static_cast<uint8_t>((src >> 24) & 0xff),
        static_cast<uint8_t>((src >> 16) & 0xff),
        static_cast<uint8_t>((src >>  8) & 0xff),
        static_cast<uint8_t>((src >>  0) & 0xff),
    };
    return dst;
}

uint64_t toU64(const MacAddress src)
{
    return ((static_cast<uint64_t>(src.octet0) << 40) & 0xff0000000000)
     + ((static_cast<uint64_t>(src.octet1) << 32) & 0x00ff00000000)
     + ((static_cast<uint64_t>(src.octet2) << 24) & 0x0000ff000000)
     + ((static_cast<uint64_t>(src.octet3) << 16) & 0x000000ff0000)
     + ((static_cast<uint64_t>(src.octet4) <<  8) & 0x00000000ff00)
     + ((static_cast<uint64_t>(src.octet5) <<  0) & 0x0000000000ff);
}

MacAddress toMac(const uint64_t src)
{
    MacAddress dst {
        static_cast<uint8_t>((src >> 40) & 0xff),
        static_cast<uint8_t>((src >> 32) & 0xff),
        static_cast<uint8_t>((src >> 24) & 0xff),
        static_cast<uint8_t>((src >> 16) & 0xff),
        static_cast<uint8_t>((src >>  8) & 0xff),
        static_cast<uint8_t>((src >>  0) & 0xff),
    };
    return dst;
}
