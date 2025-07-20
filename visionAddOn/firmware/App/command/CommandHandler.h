#ifndef VISIONADDON_APP_COMMAND_COMMANDHANDLER_H
#define VISIONADDON_APP_COMMAND_COMMANDHANDLER_H

#include "camera/CameraTypes.h"
#include "command/CommandPacket.h"
#include "command/CommandTypes.h"
#include "fpgaCommander/FpgaCommanderTypes.h"
#include "lwip/api.h"
#include "lwip/sockets.h"
#undef bind // to avoid conflicts with std functional bind
#include "network/NetworkTypes.h"
#include "storage/IStorage.h"
#include "utils/IRunnable.h"
#include "utils/matrix/Matrix.h"
#include <cstdint>
#include <functional>

class CommandHandler final : public IRunnable {
public:
    using CameraRequestCapture = std::function<bool(void)>;
    using CameraRequestFrameTransfer = std::function<bool(uint32_t address, uint32_t port)>; //TODO: use lwip type
    using CameraSetWhitebalance = std::function<bool(uint16_t red, uint16_t green, uint16_t blue)>;
    using CameraSetExposure = std::function<bool(uint16_t levelInteger, uint8_t levelFraction)>;
    using CameraSetGain = std::function<bool(uint8_t level, uint8_t band)>;
    using CameraSetFps = std::function<bool(Fps fps)>;
    using NetworkGetMac = std::function<MacAddress(void)>;
    using NetworkSetMac = std::function<void(MacAddress mac)>;
    using NetworkGetIp = std::function<IpV4Address(void)>;
    using NetworkSetIp = std::function<void(IpV4Address ip)>;
    using NetworkGetNetmask = std::function<IpV4Address(void)>;
    using NetworkSetNetmask = std::function<void(IpV4Address netmask)>;
    using NetworkGetGateway = std::function<IpV4Address(void)>;
    using NetworkSetGateway = std::function<void(IpV4Address gateway)>;
    using NetworkPersistConfig = std::function<void(void)>;
    using PipelineSetInput = std::function<bool(PipelineInput)>;
    using PipelineSetOutput = std::function<bool(PipelineOutput)>;
    using PipelineSetBinarizationThreshold = std::function<bool(uint8_t)>;
    using StrobeEnablePulse = std::function<bool(bool)>;
    using StrobeSetOnDelay = std::function<bool(uint32_t)>;
    using StrobeSetHoldTime = std::function<bool(uint32_t)>;
    using StrobeEnableConstant = std::function<bool(bool)>;
    CommandHandler(
        IStorage& storage,
        CameraRequestCapture cameraRequestCapture,
        CameraRequestFrameTransfer cameraRequestFrameTransfer,
        CameraSetWhitebalance cameraSetWhitebalance,
        CameraSetExposure cameraSetExposure,
        CameraSetGain cameraSetGain,
        CameraSetFps cameraSetFps,
        NetworkGetMac networkGetMac,
        NetworkSetMac networkSetMac,
        NetworkGetIp networkGetIp,
        NetworkSetIp networkSetIp,
        NetworkGetNetmask networkGetNetmask,
        NetworkSetNetmask networkSetNetmask,
        NetworkGetGateway networkGetGateway,
        NetworkSetGateway networkSetGateway,
        NetworkPersistConfig networkPersistConfig,
        PipelineSetInput pipelineSetInput,
        PipelineSetOutput pipelineSetOutput,
        PipelineSetBinarizationThreshold pipelineSetBinarizationThreshold,
        StrobeEnablePulse strobeEnablePulse,
        StrobeSetOnDelay strobeSetOnDelay,
        StrobeSetHoldTime strobeSetHoldTime,
        StrobeEnableConstant strobeEnableConstant
    );
    CommandHandler (const CommandHandler&) = delete;
    CommandHandler& operator=(const CommandHandler&) = delete;
    CommandHandler (const CommandHandler&&) = delete;
    CommandHandler& operator=(const CommandHandler&&) = delete;

    void init(); //!< must be called after MX_LWIP_Init()
    void run() override; //!< blocking!

private:
    bool deserialize(const uint8_t* buffer, const size_t size);
    bool handle();
    IStorage& _storage;
    CameraRequestCapture _cameraRequestCapture;
    CameraRequestFrameTransfer _cameraRequestFrameTransfer;
    CameraSetWhitebalance _cameraSetWhitebalance;
    CameraSetExposure _cameraSetExposure;
    CameraSetGain _cameraSetGain;
    CameraSetFps _cameraSetFps;
    NetworkGetMac _networkGetMac;
    NetworkSetMac _networkSetMac;
    NetworkGetIp _networkGetIp;
    NetworkSetIp _networkSetIp;
    NetworkGetNetmask _networkGetNetmask;
    NetworkSetNetmask _networkSetNetmask;
    NetworkGetGateway _networkGetGateway;
    NetworkSetGateway _networkSetGateway;
    NetworkPersistConfig _networkPersistConfig;
    PipelineSetInput _pipelineSetInput;
    PipelineSetOutput _pipelineSetOutput;
    PipelineSetBinarizationThreshold _pipelineSetBinarizationThreshold;
    StrobeEnablePulse _strobeEnablePulse;
    StrobeSetOnDelay _strobeSetOnDelay;
    StrobeSetHoldTime _strobeSetHoldTime;
    StrobeEnableConstant _strobeEnableConstant;
    Matrix<3,3> _cameraMatrix;
    Matrix<1,5> _distortionCoefficients;
    Matrix<3,3> _rotationMatrix;
    Matrix<1,3> _translationVector;
    int _serverSocket;
    struct sockaddr_in _serverAddress;
    struct sockaddr_in _remotehost;
    CommandPacket _requestPacket;
    CommandPacket _responsePacket;
    static constexpr size_t _RECEIVE_BUFFER_SIZE {1024};
    uint8_t _receiveBuffer[_RECEIVE_BUFFER_SIZE];
    static constexpr size_t _REPLY_BUFFER_SIZE {1024};
    uint8_t _replyBuffer[_REPLY_BUFFER_SIZE];
};

#endif // VISIONADDON_APP_COMMAND_COMMANDHANDLER_H