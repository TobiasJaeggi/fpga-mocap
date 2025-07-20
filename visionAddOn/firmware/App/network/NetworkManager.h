#ifndef VISIONADDON_APP_SERVICE_NETWORKMANAGER_H
#define VISIONADDON_APP_SERVICE_NETWORKMANAGER_H

#include "NetworkTypes.h"
#include "lwip/netif.h"
#include "storage/IStorage.h"
#include "stm32f7xx_hal.h"
#include "utils/constants.h"
#include <cstdint>

//TODO: Integrate Network Stats
class NetworkManager final {
public:
    struct GpioPin {
        GPIO_TypeDef *port;
        uint16_t index;
    };
    NetworkManager(netif* networkInterface, IStorage& storage, GpioPin restoreButton);
    NetworkManager() = delete;
    NetworkManager (const NetworkManager&) = delete;
    NetworkManager& operator=(const NetworkManager&) = delete;
    NetworkManager (const NetworkManager&&) = delete;
    NetworkManager& operator=(const NetworkManager&&) = delete;

    void init();

    void ip(IpV4Address address);
    IpV4Address ip();
    void netmask(IpV4Address address);
    IpV4Address netmask();
    void gateway(IpV4Address address);
    IpV4Address gateway();
    void mac(MacAddress mac);
    MacAddress mac();

    MacAddress loadMacFromStorage();

    bool persistToStorage();
    bool loadFromStorage();

private:
    bool apply(IpV4Address ip);
    bool apply(MacAddress mac);

    netif* _networkInterface;
    IStorage& _storage;
    GpioPin _restoreButton;
    ip4_addr_t _lwipIpAddress {};
    ip4_addr_t _lwipNetmask {};
    ip4_addr_t _lwipGateway {};
    MacAddress _macPendingPersistance {};
    static constexpr uint8_t _ADDRESS_MAC {EEPROM_ADDRESS_MAC};
    static constexpr uint8_t _ADDRESS_IP {EEPROM_ADDRESS_IP};
    static constexpr uint8_t _ADDRESS_NETMASK {EEPROM_ADDRESS_NETMASK};
    static constexpr uint8_t _ADDRESS_GATEWAY {EEPROM_ADDRESS_GATEWAY};
};

#endif // VISIONADDON_APP_SERVICE_NETWORKMANAGER_H