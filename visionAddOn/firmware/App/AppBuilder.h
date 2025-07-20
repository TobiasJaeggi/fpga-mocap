
#ifndef VISIONADDON_APP_APPBUILDER_H
#define VISIONADDON_APP_APPBUILDER_H

#include "c_app_builder.h"

#include "blob/BlobReceiver.h"
#include "blob/ExternalInterruptHandler.h"
#include "camera/Ov9281.h"
#include "command/CommandHandler.h"
#include "fpgaCommander/FpgaCommander.h"
#include "frameTransfer/FrameTransfer.h"
#include "network/NetworkManager.h"
#include "network/NetworkStats.h"
#include "utils/mutex/Mutex.h"
#include "utils/pool/BufferPool.h"
#include "utils/IRunnable.h"
#include "storage/At24c02d.h"

#include <memory>

class AppBuilder final {
public:
    AppBuilder();
    AppBuilder (const AppBuilder&) = delete;
    AppBuilder& operator=(const AppBuilder&) = delete;
    AppBuilder (const AppBuilder&&) = delete;
    AppBuilder& operator=(const AppBuilder&&) = delete;
    
    static void registerNetworkInterface(struct netif* networkInterface);
    
    void initCamera();
    void initCommandHandler();
    void initNetworkConfig();

    IRunnable& getBlobReceiverRunnable(){return *_blobReceiver;};
    IRunnable& getNetworkStatsRunnable(){return *_networkStats;};
    IRunnable& getCommandHandlerRunnable(){return *_commandHandler;};
    
    uint8_t* getMacFromStorage();

private:
    static struct netif* _networkInterface;
    std::unique_ptr<Ov9281> _camera;
    std::unique_ptr<Mutex> _bufferPoolMutex;
    osMessageQueueId_t _spiRxToBlobReceiverQ;
    std::unique_ptr<ExternalInterruptHandler> _spiRxInterruptHandler;
    std::unique_ptr<BlobReceiver> _blobReceiver;
    std::unique_ptr<FrameTransfer> _frameTransfer;
    std::unique_ptr<At24c02d> _eeprom;
    std::unique_ptr<NetworkManager> _networkManager;
    std::unique_ptr<NetworkStats> _networkStats;
    std::unique_ptr<FpgaCommander> _fpgaCommander;
    std::unique_ptr<CommandHandler> _commandHandler;
    uint8_t _macAddress[6];
};

#endif // VISIONADDON_APP_APPBUILDER_H
