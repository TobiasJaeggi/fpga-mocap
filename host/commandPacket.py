import logging
import struct
from typing import Optional


class CommandPacket:
    _OFFSET_REQUEST_UID = 0
    _OFFSET_COMMAND_ID = _OFFSET_REQUEST_UID + 1
    _OFFSET_COMPLETION_STATUS = _OFFSET_COMMAND_ID + 1
    _OFFSET_DATA_SIZE = _OFFSET_COMPLETION_STATUS + 1
    _OFFSET_DATA = _OFFSET_DATA_SIZE + 1

    def __init__(
        self,
        request_id: int = 0,
        command_id: int = 0,
        completion_status: int = 0,
        data: Optional[bytes] = None,
    ) -> None:
        self._request_id = request_id
        self._command_id = command_id
        self._completion_status = completion_status
        if data is not None:
            self._data = data
            self._data_size = len(data)
        else:
            self._data_size = 0
            self._data = bytes(0)

    def __str__(self) -> str:
        s = (
            f"_request_id: {str(self._request_id)}\n"
            f"_command_id: {str(self._command_id)}\n"
            f"_completion_status: {str(self._completion_status)}\n"
            f"_data_size: {str(self._data_size)}\n"
            f"_data: {str(self._data)}"
        )
        return s

    def serialize(self) -> bytes:
        return struct.pack(
            f"<BBBB{self._data_size}s",
            self._request_id,
            self._command_id,
            self._completion_status,
            self._data_size,
            self._data,
        )

    def deserialize(self, buffer: bytes) -> bool:
        if len(buffer) < self._OFFSET_DATA:
            logging.error("[CommandPacket] Deserialize failed, buffer too small")
            return False

        self._request_id, self._command_id, self._completion_status, self._data_size = (
            struct.unpack("<BBBB", buffer[: self._OFFSET_DATA])
        )

        if len(buffer) < self._OFFSET_DATA + self._data_size:
            logging.error("[CommandPacket] Deserialize failed, data does not match specified size")
            return False

        self._data = buffer[self._OFFSET_DATA : self._OFFSET_DATA + self._data_size]
        return True

    @property
    def request_id(self) -> int:
        return self._request_id

    @request_id.setter
    def request_id(self, value: int) -> None:
        self._request_id = value

    @property
    def command_id(self) -> int:
        return self._command_id

    @command_id.setter
    def command_id(self, value: int) -> None:
        self._command_id = value

    @property
    def completion_status(self) -> int:
        return self._completion_status

    @completion_status.setter
    def completion_status(self, value: int) -> None:
        self._completion_status = value

    @property
    def data_size(self) -> int:
        return self._data_size

    @property
    def data(self) -> bytes:
        return self._data

    @data.setter
    def data(self, value: bytes) -> None:
        self._data = value
        self._data_size = len(value)
