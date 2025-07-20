#include "AppBuilder.h"
#include "command/CommandTypes.h"
#include "network/NetworkTypes.h"
#include "utils/assert.h"
#include "utils/Log.h"

#include <stdio.h>

extern "C" {
#include "dcmi.h"
#include "usart.h"
#include "i2c.h"
#include "spi.h"
}

static constexpr bool BLOB_RECEIVER_USE_UDP {true};
struct netif* AppBuilder::_networkInterface {nullptr};

AppBuilder::AppBuilder():
_camera{std::make_unique<Ov9281>(&hi2c1, 0xC0, &hdcmi)},
_bufferPoolMutex{std::make_unique<Mutex>()},
_spiRxToBlobReceiverQ{osMessageQueueNew(10, sizeof(ExternalIsrToBlobReceiverQMessage), NULL)},
_spiRxInterruptHandler{std::make_unique<ExternalInterruptHandler>(&hspi1, _spiRxToBlobReceiverQ)},
_blobReceiver{std::make_unique<BlobReceiver>(_spiRxToBlobReceiverQ, BLOB_RECEIVER_USE_UDP)},
_frameTransfer{std::make_unique<FrameTransfer>()},
_eeprom{std::make_unique<At24c02d>(&hi2c4, 0b10101111, 0b10101110)},
_networkManager{std::make_unique<NetworkManager>(_networkInterface,  *_eeprom, NetworkManager::GpioPin{GPIOC, GPIO_PIN_13})},
_networkStats{std::make_unique<NetworkStats>()},
_fpgaCommander{std::make_unique<FpgaCommander>(&huart2)}
{
    ExternalInterruptHandler::registerHandler(EXTI10_SPI_NEW_DATA_Pin, *_spiRxInterruptHandler);

    CommandHandler::CameraRequestCapture cameraRequestCapture = [this]() -> bool {
        return _camera->capture();
    };
    CommandHandler::CameraRequestFrameTransfer cameraRequestFrameTransfer = [this](uint32_t address, uint32_t port) -> bool {
        return _frameTransfer->sendFrame(static_cast<in_addr_t>(address), port);
    };
    CommandHandler::CameraSetWhitebalance cameraSetWhitebalance = [this](uint16_t red, uint16_t green, uint16_t blue) -> bool {
        return _camera->whitebalance(red, green, blue);
    };
    CommandHandler::CameraSetExposure cameraSetExposure = [this](uint16_t levelInteger, uint8_t levelFraction) -> bool {
        return _camera->exposure(levelInteger, levelFraction);
    };
    CommandHandler::CameraSetGain cameraSetGain = [this](uint8_t level, uint8_t band) -> bool {
        return _camera->gain(level, band);
    };
    CommandHandler::CameraSetFps cameraSetFps = [this](Fps fps) -> bool {
        return _camera->init(fps);
    };
    CommandHandler::NetworkGetMac networkGetMac = [this](void) -> MacAddress {
        return _networkManager->mac();
    };
    CommandHandler::NetworkSetMac networkSetMac = [this](MacAddress mac) -> void {
        _networkManager->mac(mac);
    };
    CommandHandler::NetworkGetIp networkGetIp = [this]() -> IpV4Address {
        return _networkManager->ip();
    };
    CommandHandler::NetworkSetIp networkSetIp = [this](IpV4Address ip) -> void {
        _networkManager->ip(ip);
    };
    CommandHandler::NetworkGetNetmask networkGetNetmask = [this](void) -> IpV4Address {
        return _networkManager->netmask();
    };
    CommandHandler::NetworkSetNetmask networkSetNetmask = [this](IpV4Address netmask) -> void {
        _networkManager->netmask(netmask);
    };
    CommandHandler::NetworkGetGateway networkGetGateway = [this](void) -> IpV4Address {
        return _networkManager->gateway();
    };
    CommandHandler::NetworkSetGateway networkSetGateway = [this](IpV4Address gateway) -> void {
        _networkManager->gateway(gateway);
    };
    CommandHandler::NetworkPersistConfig networkPersistConfig = [this](void) -> void {
        _networkManager->persistToStorage();
    };
    CommandHandler::PipelineSetInput pipelineSetInput = [this](PipelineInput input) -> bool {
        return _fpgaCommander->pipelineInput(input);
    };
    CommandHandler::PipelineSetOutput pipelineSetOutput = [this](PipelineOutput output) -> bool {
        return _fpgaCommander->pipelineOutput(output);
    };
    CommandHandler::PipelineSetBinarizationThreshold pipelineSetBinarizationThreshold = [this](uint8_t threshold) -> bool {
        return _fpgaCommander->pipelineBinarizationThreshold(threshold);
    };
    CommandHandler::StrobeEnablePulse strobeEnablePulse = [this](bool enable) -> bool {
        return _fpgaCommander->strobeEnablePulse(enable);
    };
    CommandHandler::StrobeSetOnDelay strobeSetOnDelay = [this](uint32_t delayCycles) -> bool {
        return _fpgaCommander->strobeOnDelay(delayCycles);
    };
    CommandHandler::StrobeSetHoldTime strobeSetHoldTime = [this](uint32_t holdCycles) -> bool {
        return _fpgaCommander->strobeHoldTime(holdCycles);
    };
    CommandHandler::StrobeEnableConstant strobeEnableConstant = [this](bool enable) -> bool {
        return _fpgaCommander->strobeEnableConstant(enable);
    };

    _commandHandler = std::make_unique<CommandHandler>(
        *_eeprom,
        cameraRequestCapture,
        cameraRequestFrameTransfer,
        cameraSetWhitebalance,
        cameraSetExposure,
        cameraSetGain,
        cameraSetFps,
        networkGetMac,
        networkSetMac,
        networkGetIp,
        networkSetIp,
        networkGetNetmask,
        networkSetNetmask,
        networkGetGateway,
        networkSetGateway,
        networkPersistConfig,
        pipelineSetInput,
        pipelineSetOutput,
        pipelineSetBinarizationThreshold,
        strobeEnablePulse,
        strobeSetOnDelay,
        strobeSetHoldTime,
        strobeEnableConstant
    );
    // assert product of constructor
    ASSERT(_camera != nullptr);
    ASSERT(_bufferPoolMutex != nullptr);
    ASSERT(_blobReceiver != nullptr);
    ASSERT(_frameTransfer != nullptr);
    ASSERT(_networkStats != nullptr);
    ASSERT(_fpgaCommander != nullptr);
    ASSERT(_commandHandler != nullptr);
}

void AppBuilder::registerNetworkInterface(struct netif* networkInterface) {
    ASSERT(networkInterface != nullptr);
    _networkInterface = networkInterface;
}

void AppBuilder::initCamera() {
    uint16_t chipId = _camera->chipId();
    Log::info("[AppBuilder] camera chip id: %#x", chipId);
    if(chipId == 0){
        Log::error("[AppBuilder] camera probably not connected");
        return;
    }    
    if(!_camera->init(Fps::_72)) {
        Log::error("[AppBuilder] camera init failed");
        return;
    }
}

void AppBuilder::initCommandHandler() {
    _commandHandler->init();
}

void AppBuilder::initNetworkConfig() {
    _networkManager->init();
}

uint8_t* AppBuilder::getMacFromStorage() {
    MacAddress mac {_networkManager->loadMacFromStorage()};
    _macAddress[0] = mac.octet0;
    _macAddress[1] = mac.octet1;
    _macAddress[2] = mac.octet2;
    _macAddress[3] = mac.octet3;
    _macAddress[4] = mac.octet4;
    _macAddress[5] = mac.octet5;
    return _macAddress;
}

// c interface, singleton
static std::unique_ptr<AppBuilder> appBuilder;

void app_register_network_interface(struct netif* networkInterface)
{
    AppBuilder::registerNetworkInterface(networkInterface);
}

void app_build() {
    ASSERT(appBuilder == nullptr);
    appBuilder = std::make_unique<AppBuilder>();
}

void app_init_camera() {
    ASSERT(appBuilder != nullptr);
    appBuilder->initCamera();
}

void app_init_command_handler() {
    ASSERT(appBuilder != nullptr);
    appBuilder->initCommandHandler();
}

void app_init_network_config(){
    ASSERT(appBuilder != nullptr);
    appBuilder->initNetworkConfig();
}

void app_run_command_handler() {
    ASSERT(appBuilder != nullptr);
    appBuilder->getCommandHandlerRunnable().run();
}

void app_run_blob_receiver() {
    ASSERT(appBuilder != nullptr);
    appBuilder->getBlobReceiverRunnable().run();
}

void app_run_network_stats() {
    ASSERT(appBuilder != nullptr);
    appBuilder->getNetworkStatsRunnable().run();
}

uint8_t* app_fetch_mac_address_from_storage(){
    ASSERT(appBuilder != nullptr);
    return appBuilder->getMacFromStorage();
}