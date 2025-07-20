#include "command/CommandHandler.h"

#include "cmsis_os.h"
#include "utils/constants.h"
#include "ethernetif.h"
#include "lwip.h"
#include "lwip/arch.h"
#include "lwip/opt.h"
#include "string.h"
#include "utils/assert.h"
#include "utils/Log.h"
#include "tcpip.h"

#include <cstdlib>
#include <cstring>
#include <errno.h>
#include <utility>
#include <tuple>

//TODO: rework to use a map <commandId,handler> -> call correct handler based on commandId

// interface based on STM32CubeF7/Projects/STM32F769I-Discovery/Applications/LwIP/LwIP_HTTP_Server_Socket_RTOS/Src/main.c
// socket based on STM32CubeF7/Projects/STM32F769I-Discovery/Applications/LwIP/LwIP_HTTP_Server_Socket_RTOS/Src/httpserver-socket.c
CommandHandler::CommandHandler(
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
):
_storage{storage},
_cameraRequestCapture{std::move(cameraRequestCapture)},
_cameraRequestFrameTransfer{std::move(cameraRequestFrameTransfer)},
_cameraSetWhitebalance{std::move(cameraSetWhitebalance)},
_cameraSetExposure{std::move(cameraSetExposure)},
_cameraSetGain{std::move(cameraSetGain)},
_cameraSetFps{std::move(cameraSetFps)},
_networkGetMac{std::move(networkGetMac)},
_networkSetMac{std::move(networkSetMac)},
_networkGetIp{std::move(networkGetIp)},
_networkSetIp{std::move(networkSetIp)},
_networkGetNetmask{std::move(networkGetNetmask)},
_networkSetNetmask{std::move(networkSetNetmask)},
_networkGetGateway{std::move(networkGetGateway)},
_networkSetGateway{std::move(networkSetGateway)},
_networkPersistConfig{std::move(networkPersistConfig)},
_pipelineSetInput{std::move(pipelineSetInput)},
_pipelineSetOutput{std::move(pipelineSetOutput)},
_pipelineSetBinarizationThreshold{std::move(pipelineSetBinarizationThreshold)},
_strobeEnablePulse{std::move(strobeEnablePulse)},
_strobeSetOnDelay{std::move(strobeSetOnDelay)},
_strobeSetHoldTime{std::move(strobeSetHoldTime)},
_strobeEnableConstant{std::move(strobeEnableConstant)}
{
}

void CommandHandler::init() {
  _serverSocket = lwip_socket(AF_INET, SOCK_STREAM, 0);
  if (_serverSocket < 0) {
    Log::error("[CommandHandler] Socket error: %d", errno);
  }
  ASSERT(_serverSocket >= 0);

  // bind to port 80 at any interface
  _serverAddress.sin_family = AF_INET;
  static constexpr uint16_t SERVER_SOCKET_PORT {PORT_COMMAND_HANDLER};
  _serverAddress.sin_port = htons(SERVER_SOCKET_PORT);
  _serverAddress.sin_addr.s_addr = INADDR_ANY;

  int ret = lwip_bind(_serverSocket, (struct sockaddr *)&_serverAddress, sizeof (_serverAddress));
  ASSERT(ret >= 0);

  // listen for incoming connections (TCP listen backlog = 5)
  lwip_listen(_serverSocket, 5);
  Log::info("[CommandHandler] listening on port %u", SERVER_SOCKET_PORT);
}

bool CommandHandler::deserialize(const uint8_t* buffer, const size_t size) {
  if(size < 1) {
    Log::error("[CommandHandler] no data to deserialize");
    return false;
  }  
  if(!_requestPacket.fromBytes(buffer, size)){
    Log::error("[CommandHandler] deserializing packet failed");
    return false;
  }
  return true;
}

bool CommandHandler::handle() {
  
  switch(_requestPacket.commandId()) {
    case CommandIds::LOG_SET_LEVEL : {
      if(_requestPacket.dataSize() != 1){
        Log::warning("[CommandHandler] LOG_SET_LEVEL: abort, invalid command format");
        return false;
      }
      Log::Level level = Log::toLevel(_requestPacket.data()[0]);
      if(level == Log::LOG_UNDEFINED) {
        Log::warning("[CommandHandler] invalid log level %u", _requestPacket.data()[0]);
        return false;
      }
      Log::level(level);
      return true;
    }
    case CommandIds::CAMERA_REQUEST_CAPTURE : {
      return _cameraRequestCapture();
    }
    case  CommandIds::CAMERA_REQUEST_TRANSFER : {
      return _cameraRequestFrameTransfer(inet_addr(HOST_IP), PORT_FRAME_TRANSFER); // TODO: use _remotehost as addr
    };
    case CommandIds::CAMERA_SET_WHITEBALANCE : {
      if(_requestPacket.dataSize() != 6){
        Log::warning("[CommandHandler] CAMERA_SET_WHITEBALANCE: abort, invalid command format (manual), size: %u", _requestPacket.dataSize());
        return false;
      }
      uint16_t* red = (uint16_t*)(&_requestPacket.data()[0]);
      uint16_t* green = (uint16_t*)(&_requestPacket.data()[2]);
      uint16_t* blue = (uint16_t*)(&_requestPacket.data()[4]);
      Log::info("[CommandHandler] CAMERA_SET_WHITEBALANCE: manual rgb: (%u,%u,%u)", *red, *green, *blue);
      return _cameraSetWhitebalance(*red, *green, *blue);
    }
    case CommandIds::CAMERA_SET_EXPOSURE : {
      if(_requestPacket.dataSize() != 3){
        Log::warning("[CommandHandler] CAMERA_SET_EXPOSURE: abort, invalid command format, size: %u", _requestPacket.dataSize());
        return false;
      }
      uint16_t* levelInteger = (uint16_t*)(&_requestPacket.data()[0]);
      uint8_t levelFraction = _requestPacket.data()[2];
      Log::info("[CommandHandler] CAMERA_SET_EXPOSURE: level: %u + %u/16", *levelInteger, levelFraction);
      return _cameraSetExposure(*levelInteger, levelFraction);
    }
    case CommandIds::CAMERA_SET_GAIN : {
      if(_requestPacket.dataSize() != 2){
        Log::warning("[CommandHandler] CAMERA_SET_GAIN: abort, invalid command format, size: %u", _requestPacket.dataSize());
        return false;
      }
      uint8_t level = _requestPacket.data()[0];
      uint8_t band = _requestPacket.data()[1];
      Log::info("[CommandHandler] CAMERA_SET_GAIN: level: %u, band: %u", level, band);
      return _cameraSetGain(level, band);
    }
    case CommandIds::CAMERA_SET_FPS : {
      if(_requestPacket.dataSize() != 1){
        Log::warning("[CommandHandler] CAMERA_SET_FPS: abort, invalid command format, size: %u", _requestPacket.dataSize());
        return false;
      }
      Fps fps = static_cast<Fps>(_requestPacket.data()[0]);
      return _cameraSetFps(fps);
    }
    case CommandIds::NETWORK_GET_CONFIG : {
      if(_requestPacket.dataSize() != 0){
        Log::warning("[CommandHandler] NETWORK_GET_NETWORK_CONFIG: abort, invalid command format, size: %u", _requestPacket.dataSize());
        return false;
      }
      NetworkConfiguration networkConfiguration {};
      networkConfiguration.mac = _networkGetMac();
      networkConfiguration.ip = _networkGetIp();
      networkConfiguration.netmask = _networkGetNetmask();
      networkConfiguration.gateway = _networkGetGateway();

      static_assert(networkConfiguration.SIZE <= _responsePacket.DATA_SIZE_MAX);
      _responsePacket.dataSize(networkConfiguration.SIZE);
     
      return networkConfiguration.toBytes(_responsePacket.data(), _responsePacket.DATA_SIZE_MAX);;
    }
    case  CommandIds::NETWORK_SET_CONFIG : {
      if(_requestPacket.dataSize() != NetworkConfiguration::SIZE){
        Log::warning("[CommandHandler] NETWORK_SET_NETWORK_CONFIG: abort, invalid command format, size: %u", _requestPacket.dataSize());
        return false;
      }
      NetworkConfiguration networkConfiguration {};
      if(!networkConfiguration.fromBytes(_requestPacket.data(), _requestPacket.DATA_SIZE_MAX)) {
        Log::warning("[CommandHandler] NETWORK_SET_NETWORK_CONFIG: abort, deserialization failed");
        return false;
      }
      _networkSetMac(networkConfiguration.mac);
      _networkSetIp(networkConfiguration.ip);
      _networkSetNetmask(networkConfiguration.netmask);
      _networkSetGateway(networkConfiguration.gateway);
      return true;
    };
    case  CommandIds::NETWORK_PERSIST_CONFIG : {
      if(_requestPacket.dataSize() != 0){
        Log::warning("[CommandHandler] NETWORK_PERSIST_CONFIG: abort, invalid command format, size: %u", _requestPacket.dataSize());
        return false;
      }
      _networkPersistConfig();
      return true;
    };
    case CommandIds::CALIBRATION_LOAD_CAMERA_MATRIX : {
      if(_requestPacket.dataSize() != 0){
        Log::warning("[CommandHandler] CALIBRATION_LOAD_CAMERA_MATRIX: abort, invalid command format, size: %u", _requestPacket.dataSize());
        return false;
      }
      if(_responsePacket.DATA_SIZE_MAX < _cameraMatrix.SIZE()){
        Log::warning("[CommandHandler] CALIBRATION_LOAD_CAMERA_MATRIX: abort, response won't fit into data buffer");
        return false;
      }
      _responsePacket.dataSize(_cameraMatrix.SIZE());
      Log::info("[CommandHandler] CALIBRATION_LOAD_CAMERA_MATRIX: reading data from storage");
      return _storage.readData(EEPROM_ADDRESS_CAMERA_MATRIX, _responsePacket.data(), _cameraMatrix.SIZE());
    };
    case CommandIds::CALIBRATION_STORE_CAMERA_MATRIX : {
      if(_requestPacket.dataSize() != _cameraMatrix.SIZE()){
        Log::warning("[CommandHandler] CALIBRATION_STORE_CAMERA_MATRIX: abort, invalid command format, size: %u", _requestPacket.dataSize());
        return false;
      }
      Log::info("[CommandHandler] CALIBRATION_STORE_CAMERA_MATRIX: writing data to storage");
      static constexpr uint32_t WRITE_TIMEOUT_MS {200U};
      return _storage.writeData(EEPROM_ADDRESS_CAMERA_MATRIX, _requestPacket.data(), _requestPacket.dataSize(), WRITE_TIMEOUT_MS);
    };
    case CommandIds::CALIBRATION_LOAD_DISTORTION_COEFFICIENTS : {
      if(_requestPacket.dataSize() != 0){
        Log::warning("[CommandHandler] CALIBRATION_LOAD_DISTORTION_COEFFICIENTS: abort, invalid command format, size: %u", _requestPacket.dataSize());
        return false;
      }
      if(_responsePacket.DATA_SIZE_MAX < _distortionCoefficients.SIZE()){
        Log::warning("[CommandHandler] CALIBRATION_LOAD_DISTORTION_COEFFICIENTS: abort, response won't fit into data buffer");        return false;
      }
      _responsePacket.dataSize(_distortionCoefficients.SIZE());
      Log::info("[CommandHandler] CALIBRATION_LOAD_DISTORTION_COEFFICIENTS: reading data from storage");
      return _storage.readData(EEPROM_ADDRESS_DISTORTION_COEFFICIENTS, _responsePacket.data(), _distortionCoefficients.SIZE());
    };
    case CommandIds::CALIBRATION_STORE_DISTORTION_COEFFICIENTS : {
      if(_requestPacket.dataSize() != _distortionCoefficients.SIZE()){
        Log::warning("[CommandHandler] CALIBRATION_STORE_DISTORTION_COEFFICIENTS: abort, invalid command format, size: %u", _requestPacket.dataSize());
        return false;
      }
      Log::info("[CommandHandler] CALIBRATION_STORE_DISTORTION_COEFFICIENTS: writing data to storage");
      static constexpr uint32_t WRITE_TIMEOUT_MS {200U};
      return _storage.writeData(EEPROM_ADDRESS_DISTORTION_COEFFICIENTS, _requestPacket.data(), _requestPacket.dataSize(), WRITE_TIMEOUT_MS);
    };
    case CommandIds::CALIBRATION_LOAD_ROTATION_MATRIX : {
      if(_requestPacket.dataSize() != 0){
        Log::warning("[CommandHandler] CALIBRATION_LOAD_ROTATION_MATRIX: abort, invalid command format, size: %u", _requestPacket.dataSize());
        return false;
      }
      if(_responsePacket.DATA_SIZE_MAX < _rotationMatrix.SIZE()){
        Log::warning("[CommandHandler] CALIBRATION_LOAD_ROTATION_MATRIX: abort, response won't fit into data buffer");        return false;
      }
      _responsePacket.dataSize(_rotationMatrix.SIZE());
      Log::info("[CommandHandler] CALIBRATION_LOAD_ROTATION_MATRIX: reading data from storage");
      return _storage.readData(EEPROM_ADDRESS_ROTATION_MATRIX, _responsePacket.data(), _rotationMatrix.SIZE());
    };
    case CommandIds::CALIBRATION_STORE_ROTATION_MATRIX : {
      if(_requestPacket.dataSize() != _rotationMatrix.SIZE()){
        Log::warning("[CommandHandler] CALIBRATION_STORE_ROTATION_MATRIX: abort, invalid command format, size: %u", _requestPacket.dataSize());
        return false;
      }
      Log::info("[CommandHandler] CALIBRATION_STORE_ROTATION_MATRIX: writing data to storage");
      static constexpr uint32_t WRITE_TIMEOUT_MS {200U};
      return _storage.writeData(EEPROM_ADDRESS_ROTATION_MATRIX, _requestPacket.data(), _requestPacket.dataSize(), WRITE_TIMEOUT_MS);
    };
    case CommandIds::CALIBRATION_LOAD_TRANSLATION_VECTOR : {
      if(_requestPacket.dataSize() != 0){
        Log::warning("[CommandHandler] CALIBRATION_LOAD_TRANSLATION_VECTOR: abort, invalid command format, size: %u", _requestPacket.dataSize());
        return false;
      }
      if(_responsePacket.DATA_SIZE_MAX < _translationVector.SIZE()){
        Log::warning("[CommandHandler] CALIBRATION_LOAD_TRANSLATION_VECTOR: abort, response won't fit into data buffer");        return false;
      }
      _responsePacket.dataSize(_translationVector.SIZE());
      Log::info("[CommandHandler] CALIBRATION_LOAD_TRANSLATION_VECTOR: reading data from storage");
      return _storage.readData(EEPROM_ADDRESS_TRANSLATION_VECTOR, _responsePacket.data(), _translationVector.SIZE());
    };
    case CommandIds::CALIBRATION_STORE_TRANSLATION_VECTOR : {
      if(_requestPacket.dataSize() != _translationVector.SIZE()){
        Log::warning("[CommandHandler] CALIBRATION_STORE_TRANSLATION_VECTOR: abort, invalid command format, size: %u", _requestPacket.dataSize());
        return false;
      }
      Log::info("[CommandHandler] CALIBRATION_STORE_TRANSLATION_VECTOR: writing data to storage");
      static constexpr uint32_t WRITE_TIMEOUT_MS {200U};
      return _storage.writeData(EEPROM_ADDRESS_TRANSLATION_VECTOR, _requestPacket.data(), _requestPacket.dataSize(), WRITE_TIMEOUT_MS);
    };
    case CommandIds::PIPELINE_SET_INPUT : {
      if(_requestPacket.dataSize() != 1){
        Log::warning("[CommandHandler] PIPELINE_SET_INPUT: abort, invalid command format");
        return false;
      }
      return _pipelineSetInput(PipelineInput(_requestPacket.data()[0]));
    }
    case CommandIds::PIPELINE_SET_OUTPUT : {
      if(_requestPacket.dataSize() != 1){
        Log::warning("[CommandHandler] PIPELINE_SET_OUTPUT: abort, invalid command format");
        return false;
      }
      return _pipelineSetOutput(PipelineOutput(_requestPacket.data()[0]));
    }
    case CommandIds::PIPELINE_SET_BINARIZATION_THRESHOLD : {
      if(_requestPacket.dataSize() != 1){
        Log::warning("[CommandHandler] PIPELINE_SET_BINARIZATION_THRESHOLD: abort, invalid command format");
        return false;
      }
      return _pipelineSetBinarizationThreshold(_requestPacket.data()[0]);
    }
    case CommandIds::STROBE_ENABLE_PULSE : {
      if(_requestPacket.dataSize() != 1){
        Log::warning("[CommandHandler] STROBE_ENABLE_PULSE: abort, invalid command format");
        return false;
      }
      return _strobeEnablePulse(_requestPacket.data()[0]);
    }
    case CommandIds::STROBE_SET_ON_DELAY : {
      if(_requestPacket.dataSize() != 4){
        Log::warning("[CommandHandler] STROBE_SET_ON_DELAY: abort, invalid command format");
        return false;
      }
      uint32_t* onDelay = reinterpret_cast<uint32_t*>(_requestPacket.data());
      return _strobeSetOnDelay(*onDelay);
    }
    case CommandIds::STROBE_SET_HOLD_TIME : {
      if(_requestPacket.dataSize() != 4){
        Log::warning("[CommandHandler] STROBE_SET_HOLD_TIME: abort, invalid command format");
        return false;
      }
      uint32_t* holdTime = reinterpret_cast<uint32_t*>(_requestPacket.data());
      return _strobeSetHoldTime(*holdTime);
    }
    case CommandIds::STROBE_ENABLE_CONSTANT : {
      if(_requestPacket.dataSize() != 1){
        Log::warning("[CommandHandler] STROBE_ENABLE_CONSTANT: abort, invalid command format");
        return false;
      }
      return _strobeEnableConstant(_requestPacket.data()[0]);
    }
    default: {
      Log::debug("[CommandHandler] command %u not supported", _requestPacket.commandId());
      return false;
    }
  }
}

void CommandHandler::run() {
  size_t addressLength = sizeof(_remotehost);
  int clientSocket = lwip_accept(_serverSocket, (struct sockaddr *)&_remotehost, (socklen_t *)&addressLength);


  int bytesReceived = lwip_read(clientSocket, _receiveBuffer, _RECEIVE_BUFFER_SIZE);
  if(bytesReceived < 0){
    Log::error("[CommandHandler] Socket read error: %d", errno);
    return;
  };

  if(!deserialize(_receiveBuffer, bytesReceived)){
    static constexpr size_t BROADCAST_REQUEST_ID {0U};
    _responsePacket.requestId(BROADCAST_REQUEST_ID);
    _responsePacket.completionStatus(static_cast<uint8_t>(CompletionStatus::COMPLETION_FAILURE));
    static constexpr size_t DATA_EMPTY {0};
    _responsePacket.dataSize(DATA_EMPTY);
  } else {
    _responsePacket.requestId(_requestPacket.requestId());
    _responsePacket.commandId(_requestPacket.commandId());
    uint8_t completionStatus = handle() ? CompletionStatus::COMPLETION_SUCCESS : CompletionStatus::COMPLETION_FAILURE;
    _responsePacket.completionStatus(static_cast<uint8_t>(completionStatus));  
  }
  
  auto serializeResult = _responsePacket.toBytes(_replyBuffer, _REPLY_BUFFER_SIZE);
  if(!std::get<0>(serializeResult)){
    Log::error("[CommandHandler] serialize failed, unable to send reply");
  }else{
    int bytesSent = lwip_write(clientSocket, _replyBuffer, std::get<1>(serializeResult));
    if(bytesSent < 0){
      Log::error("[CommandHandler] Socket write error: %d", errno);
    };  
  }
  lwip_close(clientSocket);
}
