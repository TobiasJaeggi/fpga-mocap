#ifndef VISIONADDON_APP_BLOB_BLOBRECEIVER_H
#define VISIONADDON_APP_BLOB_BLOBRECEIVER_H

#include "cmsis_os2.h"
#include "lwip/api.h"
#include "utils/IRunnable.h"
#include "utils/IActivatable.h"
#include "utils/pool/BufferPool.h"

#include <cstdint>

// TODO: rework to support 2-way coms and command fpga (threshold, trigger sync, reset?)
// -> will be renamed 

class BlobReceiver final : public IRunnable {
public:
    BlobReceiver(osMessageQueueId_t newData, bool useUdp=false);
    BlobReceiver (const BlobReceiver&) = delete;
    BlobReceiver& operator=(const BlobReceiver&) = delete;
    BlobReceiver (const BlobReceiver&&) = delete;
    BlobReceiver& operator=(const BlobReceiver&&) = delete;
    void run() override;
private:
    osMessageQueueId_t _newData;
    bool _useUdp;
    uint32_t _targetPort;
    in_addr_t _targetAddress;
};

#endif // VISIONADDON_APP_BLOB_BLOBRECEIVER_H