#include "FrameTransfer.h"

#include "lwip.h"
#include "utils/assert.h"
#include "utils/constants.h"
#include "utils/Log.h"

bool FrameTransfer::initTransfer(int32_t& socket){
  (void)socket;
  Log::debug("[FrameTransfer] init transfer");
  _bytesRemaining = _FRAME_BUFFER_SIZE;
  _segmentIndex = 0;
  return true;
}

FrameTransfer::TransferStatus FrameTransfer::sendFrameSegment(int32_t& socket) {
  size_t segmentSize {0};
  if(_bytesRemaining > _MAX_SEGMENT_SIZE) {
    segmentSize = _MAX_SEGMENT_SIZE;
  } else {
    segmentSize = _bytesRemaining;
  }
  // FIXME: frame buffer address and size should be managed by Camera class
  const uint8_t* frameBufferBase {(const uint8_t*)EXTERNAL_SDRAM_BASE_ADDRESS};
  const uint8_t* segmentBase {frameBufferBase + (_MAX_SEGMENT_SIZE * _segmentIndex++)};
  Log::debug("[FrameTransfer] segment %u/%u, segmentBase: %#x", _segmentIndex, _REQUIRED_SEGMENTS, segmentBase);
  auto ret = lwip_write(socket, (void*)segmentBase, segmentSize); // blocking!
  if(ret != static_cast<int32_t>(segmentSize)) {
    Log::warning("[FrameTransfer] sending frame segment failed, ret: %d", ret);
    return TransferStatus::ERROR;
  }
  _bytesRemaining = _bytesRemaining - segmentSize;
  if((segmentSize != _MAX_SEGMENT_SIZE) && (_bytesRemaining != 0)) {
    Log::warning("[FrameTransfer] sending frame segment failed, expected to have 0 bytes remaining. Actual remaining: %d", _bytesRemaining);
    return TransferStatus::ERROR;
  }
  Log::trace("[FrameTransfer] bytesRemaining: %u", _bytesRemaining);
  if(_bytesRemaining == 0){
    Log::trace("[FrameTransfer] sending frame segment done");
    return TransferStatus::COMPLETE;
  }
  Log::trace("[FrameTransfer] transfer incomplete");
  return TransferStatus::INCOMPLETE;
}

void FrameTransfer::endTransfer(int32_t& socket){
  (void)socket;
  Log::debug("[CommandHandler] end transfer");
}

bool FrameTransfer::sendFrame(in_addr_t address, uint32_t port) { //!< blocking!
    int32_t clientSocket = lwip_socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in addr = {};
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = address;
    auto ret = lwip_connect(clientSocket, (struct sockaddr*)&addr, sizeof(addr));

    if(ret == 0) {
      if(initTransfer(clientSocket)){
        TransferStatus transferStatus = TransferStatus::INCOMPLETE;
        while(transferStatus == TransferStatus::INCOMPLETE){
          transferStatus = sendFrameSegment(clientSocket);
        }
        endTransfer(clientSocket);          
        Log::debug("[FrameTransfer] transfer status: %u, segment index: %u, bytes remaining: %u", transferStatus, _segmentIndex, _bytesRemaining);
        if(transferStatus != TransferStatus::COMPLETE) {
          Log::warning("[FrameTransfer] errno: %d", errno);
        }
      } else {
        Log::error("[FrameTransfer] init frame transfer failed");
      }
    }
    if(lwip_close(clientSocket) != 0) {
      Log::warning("[FrameTransfer] closing socket failed, ret: %d", ret);
      return false;
    }
    return true;
}
