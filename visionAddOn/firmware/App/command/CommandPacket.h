#ifndef VISIONADDON_APP_COMMAND_COMMANDPACKET_H
#define VISIONADDON_APP_COMMAND_COMMANDPACKET_H

#include <climits>
#include <cstddef>
#include <cstdint>
#include <tuple>

//TODO: use CommandTypes for relevant members

class CommandPacket final{
public:
    CommandPacket() = default;
    CommandPacket (const CommandPacket&) = delete;
    CommandPacket& operator=(const CommandPacket&) = delete;
    CommandPacket (const CommandPacket&&) = delete;
    CommandPacket& operator=(const CommandPacket&&) = delete;

    std::tuple<bool, size_t> toBytes(uint8_t* buffer, size_t size);
    bool fromBytes(const uint8_t* buffer, size_t size);

    void requestId(uint8_t requestId){_requestId = requestId;}
    uint8_t requestId(){return _requestId;}
    void commandId(uint8_t commandId){_commandId = commandId;}
    uint8_t commandId(){return _commandId;}
    void completionStatus(uint8_t completionStatus){_completionStatus = completionStatus;}
    uint8_t completionStatus(){return _completionStatus;}
    void dataSize(uint8_t dataSize){_dataSize = dataSize;}
    uint8_t dataSize(){return _dataSize;}
    uint8_t* data(){return _data;}
    static constexpr size_t DATA_SIZE_MAX = UINT8_MAX;
private:
    uint8_t _requestId {0U};
    uint8_t _commandId {0U};
    uint8_t _completionStatus {0U};
    uint8_t _dataSize {0U};
    uint8_t _data[DATA_SIZE_MAX] = {};

    static constexpr size_t _OFFSET_REQUEST_ID {0};
    static constexpr size_t _OFFSET_COMMAND_ID {_OFFSET_REQUEST_ID + sizeof(_requestId)};
    static constexpr size_t _OFFSET_COMPLETION_STATUS {_OFFSET_COMMAND_ID + sizeof(_commandId)};
    static constexpr size_t _OFFSET_DATA_SIZE {_OFFSET_COMPLETION_STATUS + sizeof(_completionStatus)};
    static constexpr size_t _OFFSET_DATA {_OFFSET_DATA_SIZE + sizeof(_dataSize)};
};

#endif // VISIONADDON_APP_COMMAND_COMMANDPACKET_H