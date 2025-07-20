#include "BlobReceiver.h"
#include "ExternalInterruptHandler.h"

#include "lwip.h"
#include "lwip/sockets.h"
#undef bind // to avoid conflicts with std functional bind

#include "utils/assert.h"
#include "utils/constants.h"
#include "utils/Log.h"

BlobReceiver::BlobReceiver(osMessageQueueId_t newData, bool useUdp) :
_newData{newData},
_useUdp{useUdp},
_targetPort{PORT_BLOB_RECEIVER}
{
_targetAddress = inet_addr(HOST_IP);
}

void BlobReceiver::run() {
    uint32_t qCount = osMessageQueueGetCount(_newData);
    if(qCount > 1){
        Log::warning("[BlobReceiver] Can't keep up, %u messages waiting", qCount);
    }

    ExternalIsrToBlobReceiverQMessage message;
    static constexpr uint32_t Q_NO_TIMEOUT {0U}; // do not wait
    auto qStatus = osMessageQueueGet(_newData, &message, NULL, Q_NO_TIMEOUT);
    switch(qStatus){
        case osErrorResource: return; // no new data
        case osOK: break; // new data
        default: {
            Log::error("[BlobReceiver] osMessageQueueGet returned with status %d", qStatus);
            ASSERT(false); // TODO: remove?
            return;
        }
    }

    if(message.bufferBase == nullptr) {
        Log::info("[BlobReceiver] dropping message, invalid buffer");
        return;
    }
    
    Log::debug("[BlobReceiver] %u bytes received", message.bytesReceived);
    Log::debug("[BlobReceiver] data: %.*s", message.bytesReceived, message.bufferBase);

    int32_t socketType{SOCK_STREAM}; // TCP
    if(_useUdp){
        socketType = SOCK_DGRAM; // UDP
    }
    int32_t clientSocket = lwip_socket(AF_INET, socketType, 0);
    struct sockaddr_in addr = {};
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(_targetPort);
    addr.sin_addr.s_addr = _targetAddress;
    auto resultConnect = lwip_connect(clientSocket, (struct sockaddr*)&addr, sizeof(addr));
    if(resultConnect == 0) {
        if(!_useUdp){
            static constexpr int32_t OPT_DISABLE {1};
            lwip_setsockopt(clientSocket, IPPROTO_TCP, TCP_NODELAY, (void*)&OPT_DISABLE, sizeof(OPT_DISABLE));
        }
        auto resultWrite = lwip_write(clientSocket, (void*)message.bufferBase, message.bytesReceived); // blocking!
        if(resultWrite != static_cast<int32_t>(message.bytesReceived)) {
            Log::warning("[BlobReceiver] send failed, return code: %d", resultWrite);
        }
    }
    auto resultClose = lwip_close(clientSocket);
    if(resultClose != 0) {
      Log::warning("[BlobReceiver] closing socket failed, ret: %d", resultClose);
    }
}
