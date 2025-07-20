#ifndef VISIONADDON_APP_UTILS_CONSTANTS_H
#define VISIONADDON_APP_UTILS_CONSTANTS_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

static const uint8_t DEFAULT_IP[4] = {10,0,0,1}; // defined in lwip.c MX_LWIP_Init

static const char HOST_IP[] = "10.0.0.2";
static const uint16_t PORT_COMMAND_HANDLER = 80;
static const uint16_t PORT_FRAME_TRANSFER = 1055;
static const uint16_t PORT_BLOB_RECEIVER = 1056;
static const uint16_t PORT_LOG = 1057;

static const uint32_t TICKS_PER_SECOND = 1000U; // based on FreeROTSConfig.h configTICK_RATE_HZ
static const uint32_t MILLISECONDS_PER_SECOND = 1000U;
static const uint32_t TICKS_PER_MILLISECOND = TICKS_PER_SECOND / MILLISECONDS_PER_SECOND;

static const uint32_t EXTERNAL_SDRAM_BASE_ADDRESS = 0xc0000000U;
static const uint32_t EXTERNAL_SDRAM_END_ADDRESS = 0xc2000000U;
static const uint32_t EXTERNAL_SDRAM_SIZE_BYTES = (16U * 1024U * 1024U * 16U) / 8U;
static const uint32_t EXTERNAL_SDRAM_SIZE_MEAGABYTES = EXTERNAL_SDRAM_SIZE_BYTES / 1024U / 1024U;
static const uint32_t EXTERNAL_SDRAM_SIZE_WORDS = EXTERNAL_SDRAM_SIZE_BYTES / sizeof(uint32_t);

static const uint32_t EEPROM_SIZE_BYTES = 256U;
static const uint32_t EEPROM_SIZE_BIT = EEPROM_SIZE_BYTES * 8U;
static const uint32_t EEPROM_SIZE_KILOBIT = EEPROM_SIZE_BIT / 1024U;

static const uint8_t EEPROM_ADDRESS_MAC = 0x10; // 6 byte (0x06)
static const uint8_t EEPROM_ADDRESS_IP = 0x18; // 4 byte (0x04)
static const uint8_t EEPROM_ADDRESS_NETMASK = 0x20; // 4 byte (0x04)
static const uint8_t EEPROM_ADDRESS_GATEWAY = 0x28; // 4 byte (0x04)
static const uint8_t EEPROM_ADDRESS_CAMERA_MATRIX = 0x40; // 36 byte (0x24)
static const uint8_t EEPROM_ADDRESS_DISTORTION_COEFFICIENTS = 0x70; // 20 byte (0x14)
static const uint8_t EEPROM_ADDRESS_ROTATION_MATRIX = 0x90; // 36 byte (0x24)
static const uint8_t EEPROM_ADDRESS_TRANSLATION_VECTOR = 0xc0; // 12 byte (0x0c)

#ifndef GIT_COMMIT_HASH
#define GIT_COMMIT_HASH "?"
#endif

#ifdef __cplusplus
}
#endif

#endif // VISIONADDON_APP_UTILS_CONSTANTS_H
