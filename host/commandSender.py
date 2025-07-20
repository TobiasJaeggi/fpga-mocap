import ipaddress
import logging
import socket
import struct
from enum import Enum
from typing import Optional, Tuple

import numpy as np

from commandPacket import CommandPacket

BROADCAST_REQUEST_ID = 0

# FIXME: bytearray endianness


class CommandIds(Enum):
    NACK = 0x00
    ACK = 0x01
    LOG_SET_LEVEL = 0x10
    CAMERA_REQUEST_CAPTURE = 0x20
    CAMERA_REQUEST_TRANSFER = 0x21
    CAMERA_SET_WHITE_BALANCE = 0x22
    CAMERA_SET_EXPOSURE = 0x23
    CAMERA_SET_GAIN = 0x24
    CAMERA_SET_FPS = 0x25
    NETWORK_GET_CONFIG = 0x30
    NETWORK_SET_CONFIG = 0x31
    NETWORK_PERSIST_CONFIG = 0x32
    CALIBRATION_LOAD_CAMERA_MATRIX = 0x40
    CALIBRATION_STORE_CAMERA_MATRIX = 0x41
    CALIBRATION_LOAD_DISTORTION_COEFFICIENTS = 0x42
    CALIBRATION_STORE_DISTORTION_COEFFICIENTS = 0x43
    CALIBRATION_LOAD_ROTATION_MATRIX = 0x44
    CALIBRATION_STORE_ROTATION_MATRIX = 0x45
    CALIBRATION_LOAD_TRANSLATION_VECTOR = 0x46
    CALIBRATION_STORE_TRANSLATION_VECTOR = 0x47
    PIPELINE_SET_INPUT = 0x50
    PIPELINE_SET_OUTPUT = 0x51
    PIPELINE_SET_BINARIZATION_THRESHOLD = 0x52
    STROBE_ENABLE_PULSE = 0x60
    STROBE_SET_ON_DELAY = 0x61
    STROBE_SET_HOLD_TIME = 0x62
    STROBE_ENABLE_CONSTANT = 0x63
    UNDEFINED = 0xFF


class CompletionStatus(Enum):
    COMPLETION_FAILURE = 0x00
    COMPLETION_SUCCESS = 0x01
    UNDEFINED = 0xFF


class LogLevel(Enum):
    TRACE = 0
    DEBUG = 1
    INFO = 2
    WARNING = 3
    ERROR = 4


class PipelineInput(Enum):
    CAMERA = 0
    FAKE_STATIC = 1
    FAKE_MOVING = 2


class PipelineOutput(Enum):
    UNPROCESSED = 0
    BINARIZED = 1


class Fps(Enum):
    _13 = 0
    _72 = 1


class CommandSender:
    def __init__(
        self,
        target_ip: str = "10.0.0.1",  # TODO use ipaddress.IPv4Address type
        target_command_handler_port: int = 80,
    ):
        self._target_ip = target_ip
        self._target_command_handler_port = target_command_handler_port
        self._logger = logging.getLogger("CommandSender")
        self._logger.setLevel(logging.INFO)
        self._logger.debug("instance created")

    def _send(
        self, command: CommandPacket, blocking=True, timeout_s: int = 1
    ) -> Optional[bytes]:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        if not blocking:
            sock.settimeout(timeout_s)
            assert False, "not implemented"
        sock.connect((self._target_ip, self._target_command_handler_port))
        try:
            self._logger.debug(
                f"sending (request, command) ({command.request_id}, {command.command_id})"
            )
            sock.send(command.serialize())
            data = sock.recv(1024)
            if data is None:
                self._logger.warning(
                    f"no response received for (request, command) ({command.request_id}, {command.command_id})"
                )
                return None
            response = CommandPacket()
            response.deserialize(data)
            self._logger.debug(response)

            if response.request_id not in [command.request_id, BROADCAST_REQUEST_ID]:
                self._logger.error("received out of order response")
                return None
            if response.command_id is not command.command_id:
                self._logger.error(
                    f"response does not match request.\nrequest:\n{command}\nresponse:\n{response}"
                )
                return None
            match CompletionStatus(response.completion_status):
                case CompletionStatus.COMPLETION_SUCCESS:
                    self._logger.debug("completion success")
                    return response.data
                case CompletionStatus.COMPLETION_FAILURE:
                    self._logger.warning("completion failure")
                    return None
                case _:
                    self._logger.warning(
                        f"received invalid completion status {response.completion_status}"
                    )
                    return None

        finally:
            sock.close()

    def target_ip(self, ip: str):
        self._target_ip = ip

    def target_command_handler_port(self, port: int):
        self._target_command_handler_port = port

    def log_level(
        self,
        level: LogLevel,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.LOG_SET_LEVEL.value,
            data=bytearray([level.value]),
        )
        return self._send(c, blocking, timeout_s) is not None

    def capture(
        self, request_id: int = 1, blocking: bool = True, timeout_s: int = 1
    ) -> bool:
        c = CommandPacket(
            request_id=request_id, command_id=CommandIds.CAMERA_REQUEST_CAPTURE.value
        )
        return self._send(c, blocking, timeout_s) is not None

    def transfer(
        self, request_id: int = 1, blocking: bool = True, timeout_s: int = 1
    ) -> bool:
        c = CommandPacket(
            request_id=request_id, command_id=CommandIds.CAMERA_REQUEST_TRANSFER.value
        )
        return self._send(c, blocking, timeout_s) is not None

    def white_balance(
        self,
        rgb: Tuple[int, int, int],
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        red = struct.pack("<H", rgb[0])
        green = struct.pack("<H", rgb[1])
        blue = struct.pack("<H", rgb[2])
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.CAMERA_SET_WHITE_BALANCE.value,
            data=bytearray() + red + green + blue,
        )
        return self._send(c, blocking, timeout_s) is not None

    def exposure(
        self,
        level: float | int,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        level_integer: int = int(level)
        level_fraction: int = 0  # TODO
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.CAMERA_SET_EXPOSURE.value,
            data=bytearray()
            + struct.pack("<H", level_integer)
            + struct.pack("<B", level_fraction),
        )
        return self._send(c, blocking, timeout_s) is not None

    def gain(
        self,
        level: int,
        band: int,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.CAMERA_SET_GAIN.value,
            data=bytearray() + struct.pack("<B", level) + struct.pack("<B", band),
        )
        return self._send(c, blocking, timeout_s) is not None

    def fps(
        self,
        fps: Fps,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.CAMERA_SET_FPS.value,
            data=bytearray(struct.pack("<B", fps.value)),
        )
        return self._send(c, blocking, timeout_s) is not None

    def network_get_config(
        self,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> Optional[Tuple[str, str, str, str]]:  # TODO: use ipaddress types
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.NETWORK_GET_CONFIG.value,
        )
        data = self._send(c, blocking, timeout_s)
        if data is None:
            return None
        OFFSET_MAC = 0
        SIZE_MAC = 6
        OFFSET_IP = 6
        SIZE_IP = 4
        OFFSET_NETMASK = 10
        SIZE_NETMASK = 4
        OFFSET_GATEWAY = 14
        SIZE_GATEWAY = 4
        mac = struct.unpack("<BBBBBB", data[OFFSET_MAC : OFFSET_MAC + SIZE_MAC])
        ip = struct.unpack("<BBBB", data[OFFSET_IP : OFFSET_IP + SIZE_IP])
        netmask = struct.unpack(
            "<BBBB", data[OFFSET_NETMASK : OFFSET_NETMASK + SIZE_NETMASK]
        )
        gateway = struct.unpack(
            "<BBBB", data[OFFSET_GATEWAY : OFFSET_GATEWAY + SIZE_GATEWAY]
        )
        return (
            f"{mac[0]:02x}:{mac[1]:02x}:{mac[2]:02x}:{mac[3]:02x}:{mac[4]:02x}:{mac[5]:02x}",
            f"{ip[0]}.{ip[1]}.{ip[2]}.{ip[3]}",
            f"{netmask[0]}.{netmask[1]}.{netmask[2]}.{netmask[3]}",
            f"{gateway[0]}.{gateway[1]}.{gateway[2]}.{gateway[3]}",
        )

    def network_set_config(
        self,
        mac: str,
        ip: str,
        netmask: str,
        gateway: str,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        self._logger.info(f"mac {mac}, ip {ip}, netmask {netmask}, gateway {gateway}")
        mac_octets = list(map(lambda x: int(x, base=16), mac.split(":")))
        ip_octets = list(map(lambda x: int(x, base=10), ip.split(".")))
        netmask_octets = list(map(lambda x: int(x, base=10), netmask.split(".")))
        gateway_octets = list(map(lambda x: int(x, base=10), gateway.split(".")))
        if (
            (len(mac_octets) != 6)
            or (len(ip_octets) != 4)
            or (len(netmask_octets) != 4)
            or (len(gateway_octets) != 4)
        ):
            self._logger.warning("invalid arguments")
            return False

        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.NETWORK_SET_CONFIG.value,
            data=bytearray(mac_octets)
            + bytearray(ip_octets)
            + bytearray(netmask_octets)
            + bytearray(gateway_octets),
        )
        return self._send(c, blocking, timeout_s) is not None

    def network_persist_config(
        self,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        c = CommandPacket(
            request_id=request_id, command_id=CommandIds.NETWORK_PERSIST_CONFIG.value
        )
        return self._send(c, blocking, timeout_s) is not None

    def calibration_load_camera_matrix(
        self,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> Optional[np.typing.NDArray]:  # TODO: type hint 3x3 array
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.CALIBRATION_LOAD_CAMERA_MATRIX.value,
        )
        data = self._send(c, blocking, timeout_s)
        if data is None:
            return None
        camera_matrix = np.frombuffer(data, dtype="float32")
        return np.reshape(camera_matrix, shape=(3, 3))

    def calibration_store_camera_matrix(
        self,
        camera_matrix: np.typing.NDArray,  # TODO: type hint 3x3 array
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        assert camera_matrix.shape == (3, 3), "invalid camera matrix shape"
        camera_matrix = np.array(camera_matrix, dtype="float32")
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.CALIBRATION_STORE_CAMERA_MATRIX.value,
            data=bytearray(camera_matrix.tobytes(order="C")),
        )
        return self._send(c, blocking, timeout_s) is not None

    def calibration_load_distortion_coefficients(
        self,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> Optional[np.typing.NDArray]:  # TODO: type hint 1x5 array
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.CALIBRATION_LOAD_DISTORTION_COEFFICIENTS.value,
        )
        data = self._send(c, blocking, timeout_s)
        if data is None:
            return None
        distortion_coefficients = np.frombuffer(data, dtype="float32")
        return np.reshape(distortion_coefficients, shape=(1, 5))

    def calibration_store_distortion_coefficients(
        self,
        distortion_coefficients: np.typing.NDArray,  # TODO: type hint 1x5 array
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        assert distortion_coefficients.shape == (1, 5), (
            "invalid distortion coefficients shape"
        )
        distortion_coefficients = np.array(distortion_coefficients, dtype="float32")
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.CALIBRATION_STORE_DISTORTION_COEFFICIENTS.value,
            data=bytearray(distortion_coefficients.tobytes(order="C")),
        )
        return self._send(c, blocking, timeout_s) is not None

    def calibration_load_rotation_matrix(
        self,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> Optional[np.typing.NDArray]:  # TODO: type hint 3x3 array
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.CALIBRATION_LOAD_ROTATION_MATRIX.value,
        )
        data = self._send(c, blocking, timeout_s)
        if data is None:
            return None
        rotation_matrix = np.frombuffer(data, dtype="float32")
        return np.reshape(rotation_matrix, shape=(3, 3))

    def calibration_store_rotation_matrix(
        self,
        rotation_matrix: np.typing.NDArray,  # TODO: type hint 3x3 array
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        assert rotation_matrix.shape == (3, 3), "invalid rotation matrix shape"
        rotation_matrix = np.array(rotation_matrix, dtype="float32")
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.CALIBRATION_STORE_ROTATION_MATRIX.value,
            data=bytearray(rotation_matrix.tobytes(order="C")),
        )
        return self._send(c, blocking, timeout_s) is not None

    def calibration_load_translation_vector(
        self,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> Optional[np.typing.NDArray]:  # TODO: type hint 3x1 array
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.CALIBRATION_LOAD_TRANSLATION_VECTOR.value,
        )
        data = self._send(c, blocking, timeout_s)
        if data is None:
            return None
        translation_vector = np.frombuffer(data, dtype="float32")
        return np.reshape(translation_vector, shape=(3, 1))

    def calibration_store_translation_vector(
        self,
        translation_vector: np.typing.NDArray,  # TODO: type hint 3x1 array
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        assert translation_vector.shape == (3, 1), "invalid translation vector shape"
        translation_vector = np.array(translation_vector, dtype="float32")
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.CALIBRATION_STORE_TRANSLATION_VECTOR.value,
            data=bytearray(translation_vector.tobytes(order="C")),
        )
        return self._send(c, blocking, timeout_s) is not None

    def pipeline_input(
        self,
        input: PipelineInput,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.PIPELINE_SET_INPUT.value,
            data=bytearray([input.value]),
        )
        return self._send(c, blocking, timeout_s) is not None

    def pipeline_output(
        self,
        output: PipelineOutput,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.PIPELINE_SET_OUTPUT.value,
            data=bytearray([output.value]),
        )
        return self._send(c, blocking, timeout_s) is not None

    def pipeline_binarization_threshold(
        self,
        threshold: int,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.PIPELINE_SET_BINARIZATION_THRESHOLD.value,
            data=bytearray(struct.pack("<B", threshold)),
        )
        return self._send(c, blocking, timeout_s) is not None

    def strobe_enable_pulse(
        self,
        enable: bool,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.STROBE_ENABLE_PULSE.value,
            data=bytearray(struct.pack("<?", enable)),
        )
        return self._send(c, blocking, timeout_s) is not None

    def strobe_on_delay(
        self,
        delay_cycles: int,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.STROBE_SET_ON_DELAY.value,
            data=bytearray(struct.pack("<L", delay_cycles)),
        )
        return self._send(c, blocking, timeout_s) is not None

    def strobe_hold_time(
        self,
        hold_cycles: int,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.STROBE_SET_HOLD_TIME.value,
            data=bytearray(struct.pack("<L", hold_cycles)),
        )
        return self._send(c, blocking, timeout_s) is not None

    def strobe_enable_constant(
        self,
        enable: bool,
        request_id: int = 1,
        blocking: bool = True,
        timeout_s: int = 1,
    ) -> bool:
        c = CommandPacket(
            request_id=request_id,
            command_id=CommandIds.STROBE_ENABLE_CONSTANT.value,
            data=bytearray(struct.pack("<?", enable)),
        )
        return self._send(c, blocking, timeout_s) is not None
