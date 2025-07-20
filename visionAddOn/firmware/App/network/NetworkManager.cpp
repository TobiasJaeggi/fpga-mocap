#include "NetworkManager.h"
#include "utils/constants.h"
#include "utils/Log.h"
#include "lwip/ip4_addr.h"

#include <cstring>

NetworkManager::NetworkManager(netif* networkInterface, IStorage& storage, GpioPin restoreButton) :
_networkInterface{networkInterface},
_storage{storage},
_restoreButton{restoreButton}
{
    ASSERT(_networkInterface != nullptr);
};

void NetworkManager::init() {
    bool pressedBeforeDelay = HAL_GPIO_ReadPin(_restoreButton.port, _restoreButton.index) == GPIO_PinState::GPIO_PIN_RESET;
    static constexpr uint32_t DEBOUNCE_DELAY_MS {5U};
    HAL_Delay(DEBOUNCE_DELAY_MS*TICKS_PER_MILLISECOND);
    bool pressedAfterDelay = HAL_GPIO_ReadPin(_restoreButton.port, _restoreButton.index) == GPIO_PinState::GPIO_PIN_RESET;
    if(pressedBeforeDelay && pressedAfterDelay){
        Log::info("[Network Manager] restoring default config");
        _macPendingPersistance = {0x00, 0x80, 0xe1, 0x00, 0x00, 0x00}; // will only be applied after persist and reboot
        ip({10, 0, 0, 1});
        netmask({255, 255, 255, 0});
        gateway({10, 0, 0, 1});
        if (!persistToStorage()) {
            Log::warning("[NetworkManager] persisting default configuration failed");
        }
        //TODO: blink
    } else {
        loadFromStorage();
    }
}

void NetworkManager::ip(IpV4Address address) {
    Log::info("[NetworkManager] Set IP to %u.%u.%u.%u", address.octet0, address.octet1, address.octet2, address.octet3);
    _lwipIpAddress = address.toLwip();
    netif_set_ipaddr(_networkInterface, &_lwipIpAddress);
}

IpV4Address NetworkManager::ip() {
    const ip4_addr_t* lwipIp = netif_ip_addr4(_networkInterface);
    IpV4Address address;
    address.fromLwip(*lwipIp);
    return address;
}

void NetworkManager::netmask(IpV4Address address) {
    Log::info("[NetworkManager] Set Netmask to %u.%u.%u.%u", address.octet0, address.octet1, address.octet2, address.octet3);
    _lwipNetmask = address.toLwip();
    netif_set_netmask(_networkInterface, &_lwipNetmask);
}

IpV4Address NetworkManager::netmask() {
    const ip4_addr_t* lwipNetmask = netif_ip_netmask4(_networkInterface);
    IpV4Address address;
    address.fromLwip(*lwipNetmask);
    return address;
}

void NetworkManager::gateway(IpV4Address address) {
    Log::info("[NetworkManager] Set Gateway to %u.%u.%u.%u", address.octet0, address.octet1, address.octet2, address.octet3);
    _lwipGateway = address.toLwip();
    netif_set_gw(_networkInterface, &_lwipGateway);
}

IpV4Address NetworkManager::gateway() {
    const ip4_addr_t* lwipGateway = netif_ip_gw4(_networkInterface);
    IpV4Address address;
    address.fromLwip(*lwipGateway);
    return address;
}

void NetworkManager::mac(MacAddress mac) {
    _macPendingPersistance = mac;
    Log::info("[NetworkManager] MAC needs to be persisted for this change to take effect, will only be applied after a reboot");
    Log::info("[NetworkManager] MAC after next reboot: %02x.%02x.%02x.%02x.%02x.%02x", _macPendingPersistance.octet0, _macPendingPersistance.octet1, _macPendingPersistance.octet2, _macPendingPersistance.octet3, _macPendingPersistance.octet4, _macPendingPersistance.octet5);
}

MacAddress NetworkManager::mac() {
    return _macPendingPersistance;
}

MacAddress NetworkManager::loadMacFromStorage() {
    MacAddress mac;
    uint8_t buffer[mac.SIZE] {};
    if(_storage.readData(_ADDRESS_MAC, buffer,  sizeof(buffer))){
        mac.fromBytes(buffer, sizeof(buffer));
    } else {
        Log::warning("[NetworkManager] loading MAC from storage failed");
    }
    return mac;
}

bool NetworkManager::persistToStorage() {
    Log::info("[NetworkManager] persisting network configuration");
    IpV4Address ipStore {ip()};
    IpV4Address netmaskStore {netmask()};
    IpV4Address gatewayStore {gateway()};
    Log::info("[NetworkManager] IP: %u.%u.%u.%u", ipStore.octet0, ipStore.octet1, ipStore.octet2, ipStore.octet3);
    Log::info("[NetworkManager] Netmask: %u.%u.%u.%u", netmaskStore.octet0, netmaskStore.octet1, netmaskStore.octet2, netmaskStore.octet3);
    Log::info("[NetworkManager] Gateway: %u.%u.%u.%u", gatewayStore.octet0, gatewayStore.octet1, gatewayStore.octet2, gatewayStore.octet3);
    Log::info("[NetworkManager] MAC: %02x.%02x.%02x.%02x.%02x.%02x", _macPendingPersistance.octet0, _macPendingPersistance.octet1, _macPendingPersistance.octet2, _macPendingPersistance.octet3, _macPendingPersistance.octet4, _macPendingPersistance.octet5);

    bool success {true};
    auto checkSuccess = [&](bool ok, const char* message) -> void {
        if(!ok){
            Log::warning(message);
            success = false;
        }
    };
    checkSuccess(_storage.writeData(_ADDRESS_MAC, _macPendingPersistance.toU64()), "[NetworkManager] persisting MAC failed");    
    checkSuccess(_storage.writeData(_ADDRESS_IP, ipStore.toU32()), "[NetworkManager] persisting IP failed");
    checkSuccess(_storage.writeData(_ADDRESS_NETMASK, netmaskStore.toU32()), "[NetworkManager] persisting Netmask failed");
    checkSuccess(_storage.writeData(_ADDRESS_GATEWAY, gatewayStore.toU32()), "[NetworkManager] persisting Gateway failed");
    return success;
}

bool NetworkManager::loadFromStorage() {
    Log::info("[NetworkManager] loading network configuration");

    uint64_t macAddressRaw {};
    uint32_t ipV4AddressRaw {};
    IpV4Address ipV4Address {};
    bool success = true;
    if(_storage.readData(_ADDRESS_MAC, macAddressRaw)){
        _macPendingPersistance.fromU64(macAddressRaw);
    } else {
        Log::warning("[NetworkManager] loading MAC from storage failed");
        success = false;
    }
    if(_storage.readData(_ADDRESS_IP, ipV4AddressRaw)){
        ipV4Address.fromU32(ipV4AddressRaw);
        ip(ipV4Address);
    } else {
        Log::warning("[NetworkManager] loading IP from storage failed");
        success = false;
    }
    if(_storage.readData(_ADDRESS_NETMASK, ipV4AddressRaw)){
        ipV4Address.fromU32(ipV4AddressRaw);
        netmask(ipV4Address);
    } else {
        Log::warning("[NetworkManager] loading Netmask from storage failed");
        success = false;
    }
    if(_storage.readData(_ADDRESS_GATEWAY, ipV4AddressRaw)){
        ipV4Address.fromU32(ipV4AddressRaw);
        gateway(ipV4Address);
    } else {
        Log::warning("[NetworkManager] loading Gateway from storage failed");
        success = false;
    }
    if(!success){
        Log::warning("[NetworkManager] loading network configuration failed");
    }
    return success;
}
