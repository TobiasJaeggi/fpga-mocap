#ifndef VISIONADDON_APP_COMMAND_COMMANDTYPES_H
#define VISIONADDON_APP_COMMAND_COMMANDTYPES_H

#include "network/NetworkTypes.h"

#include <climits>
#include <cstddef>
#include <cstdint>

enum CommandIds : uint8_t {
    LOG_SET_LEVEL = 0x10,
    CAMERA_REQUEST_CAPTURE = 0x20,
    CAMERA_REQUEST_TRANSFER = 0x21,
    CAMERA_SET_WHITEBALANCE = 0x22,
    CAMERA_SET_EXPOSURE = 0x23,
    CAMERA_SET_GAIN = 0x24,
    CAMERA_SET_FPS = 0x25,
    NETWORK_GET_CONFIG = 0x30,
    NETWORK_SET_CONFIG = 0x31,
    NETWORK_PERSIST_CONFIG = 0x32,
    CALIBRATION_LOAD_CAMERA_MATRIX = 0x40,
    CALIBRATION_STORE_CAMERA_MATRIX = 0x41,
    CALIBRATION_LOAD_DISTORTION_COEFFICIENTS = 0x42,
    CALIBRATION_STORE_DISTORTION_COEFFICIENTS = 0x43,
    CALIBRATION_LOAD_ROTATION_MATRIX = 0x44,
    CALIBRATION_STORE_ROTATION_MATRIX = 0x45,
    CALIBRATION_LOAD_TRANSLATION_VECTOR = 0x46,
    CALIBRATION_STORE_TRANSLATION_VECTOR = 0x47,
    PIPELINE_SET_INPUT = 0x50,
    PIPELINE_SET_OUTPUT = 0x51,
    PIPELINE_SET_BINARIZATION_THRESHOLD = 0x52,
    STROBE_ENABLE_PULSE = 0x60,
    STROBE_SET_ON_DELAY = 0x61,
    STROBE_SET_HOLD_TIME = 0x62,
    STROBE_ENABLE_CONSTANT = 0x63,
    COMMAND_UNDEFINED = UINT8_MAX
};

enum CompletionStatus : uint8_t {
    COMPLETION_FAILURE = 0x00,
    COMPLETION_SUCCESS = 0x01,
    COMPLETION_UNDEFINED = UINT8_MAX
};

class NetworkConfiguration {
public:
    MacAddress mac = {};
    IpV4Address ip = {};
    IpV4Address netmask = {};
    IpV4Address gateway = {};
    static constexpr size_t SIZE {decltype(mac)::SIZE + decltype(ip)::SIZE + decltype(netmask)::SIZE + decltype(gateway)::SIZE};
    static constexpr size_t OFFSET_MAC {0};
    static constexpr size_t OFFSET_IP {OFFSET_MAC + decltype(mac)::SIZE};
    static constexpr size_t OFFSET_NETMASK {OFFSET_IP + decltype(ip)::SIZE};
    static constexpr size_t OFFSET_GATEWAY {OFFSET_NETMASK + decltype(netmask)::SIZE};

    bool toBytes(uint8_t* buffer, size_t size) {
        if(SIZE > size) {
            return false;
        }

        bool success = mac.toBytes(buffer + OFFSET_MAC, mac.SIZE);
        success = ip.toBytes(buffer + OFFSET_IP, ip.SIZE) && success;
        success = netmask.toBytes(buffer + OFFSET_NETMASK, netmask.SIZE) && success;
        success = gateway.toBytes(buffer + OFFSET_GATEWAY, gateway.SIZE) && success;
        return success;
    }

    bool fromBytes(const uint8_t* buffer, size_t size) {
        if(SIZE > size) {
            return false;
        }
        bool success = mac.fromBytes(buffer + OFFSET_MAC, mac.SIZE);
        success = ip.fromBytes(buffer + OFFSET_IP, ip.SIZE) && success;
        success = netmask.fromBytes(buffer + OFFSET_NETMASK, netmask.SIZE) && success;
        success = gateway.fromBytes(buffer + OFFSET_GATEWAY, gateway.SIZE) && success;
        return success;
    }
};

#endif // VISIONADDON_APP_COMMAND_COMMANDTYPES_H