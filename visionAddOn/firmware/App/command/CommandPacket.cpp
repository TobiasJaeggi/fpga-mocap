#include "CommandPacket.h"
#include "utils/assert.h"
#include "utils/Log.h"

#include <cstring>

std::tuple<bool, size_t> CommandPacket::toBytes(uint8_t* buffer, size_t size){
    if(size < (_OFFSET_DATA + _dataSize)){
        Log::warning("[CommandPacket] serialize failed, destination buffer too small");
        return {false, 0};
    }
    std::memcpy(buffer + _OFFSET_REQUEST_ID, &_requestId, sizeof(_requestId));
    std::memcpy(buffer + _OFFSET_COMMAND_ID, &_commandId, sizeof(_commandId));
    std::memcpy(buffer + _OFFSET_COMPLETION_STATUS, &_completionStatus, sizeof(_completionStatus));
    std::memcpy(buffer + _OFFSET_DATA_SIZE, &_dataSize, sizeof(_dataSize));
    std::memcpy(buffer + _OFFSET_DATA, &_data, _dataSize);
    return {true, _OFFSET_DATA + _dataSize};
}

bool CommandPacket::fromBytes(const uint8_t* buffer, size_t size){
    if(size > DATA_SIZE_MAX)
    {
        Log::warning("[CommandPacket] deserialize failed, data size exceeds internal buffer size");
        return false;
    }

    if(size < _OFFSET_REQUEST_ID + sizeof(_requestId)){
        Log::warning("[CommandPacket] deserialize failed at request uid");
        return false;
    }
    _requestId = buffer[_OFFSET_REQUEST_ID];
    
    if(size < (_OFFSET_COMMAND_ID + sizeof(_commandId)))
    {
        Log::warning("[CommandPacket] deserialize failed at command id");
        return false;
    }
    _commandId = buffer[_OFFSET_COMMAND_ID];
    
    if(size < (_OFFSET_COMPLETION_STATUS + sizeof(_completionStatus)))
    {
        Log::warning("[CommandPacket] deserialize failed at completion status");
        return false;
    }
    _completionStatus = buffer[_OFFSET_COMPLETION_STATUS];

    if(size < (_OFFSET_DATA_SIZE + sizeof(_dataSize)))
    {
        Log::warning("[CommandPacket] deserialize failed at data size");
        return false;
    }
    _dataSize = buffer[_OFFSET_DATA_SIZE];
    
    if(size < (_OFFSET_DATA + _dataSize))
    {
        Log::warning("[CommandPacket] deserialize failed at data size check");
        return false;
    }
    std::memcpy(_data, buffer + _OFFSET_DATA, size);
    return true;
}
