import asyncio
import logging
import socket
import struct
from pathlib import Path
from typing import Optional

from PIL import Image

from commandSender import CommandSender

IMAGE_WIDTH = 1280
IMAGE_HEIGHT = 800


class FrameReceiver:
    def __init__(self, command_sender: CommandSender, rx_tcp_port: int = 1055) -> None:
        self._rx_tcp_port = rx_tcp_port
        self._command_sender = command_sender
        self._logger = logging.getLogger("FrameReceiver")
        self._logger.setLevel(logging.INFO)
        self._logger.debug("instance created")

    def rx_tcp_port(self, rx_tcp_port: int):
        self._rx_tcp_port = rx_tcp_port
        self._logger.info(f"frame receiver tcp port updated to {self._rx_tcp_port}")

    async def _start_rx_server(
        self, rx_socket_ready: asyncio.Event, label: str, dir: Path
    ) -> Path:
        self._logger.debug("staring rx server")
        dir.mkdir(parents=True, exist_ok=True)
        file_path = dir / Path(label + ".bin")
        server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        # Enable SO_REUSEADDR to allow immediate reuse after aborting
        server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server_socket.setblocking(False)
        self._logger.debug(f"binding socket to port {self._rx_tcp_port}")
        server_socket.bind(("0.0.0.0", self._rx_tcp_port))
        self._logger.debug("socket bound")
        server_socket.listen(5)
        self._logger.debug(f"Listening on port {self._rx_tcp_port}...")
        rx_socket_ready.set()
        loop = asyncio.get_event_loop()
        try:
            while True:
                self._logger.debug("ready to accept incoming connections")
                # Accept an incoming connection
                client_socket, client_address = await loop.sock_accept(server_socket)
                self._logger.info(f"Connection from {client_address}")
                try:
                    with open(file_path, "wb") as f:
                        while True:
                            data = await loop.sock_recv(client_socket, 1024)
                            if not data:
                                self._logger.warning("dropping empty message")
                                break
                            f.write(data)
                except Exception as e:
                    logging.error(f"e {e}")
                finally:
                    client_socket.close()
                    break
        finally:
            server_socket.close()
        return file_path

    async def receiveSnapshot(
        self, label: str, dir: Path = Path("/tmp/frameReceiver/snapshots/")
    ) -> Optional[Path]:
        if not self._command_sender.capture():
            self._logger.warning("capture failed")
            return None  # TODO
        self._logger.debug("capture success")
        rx_socket_ready = asyncio.Event()
        receive_task = asyncio.create_task(
            self._start_rx_server(rx_socket_ready=rx_socket_ready, dir=dir, label=label)
        )
        self._logger.debug("waiting for rx socket to be ready")
        await rx_socket_ready.wait()
        self._logger.debug("socket ready, requesting transfer")
        transfer_success = await asyncio.to_thread(self._command_sender.transfer)
        binary_file = await receive_task
        if not transfer_success:
            self._logger.warning("transfer failed")
            return None  # TODO

        self._logger.info(f"binary file saved to {binary_file}")
        #image_file = self._convert(file=binary_file, label=label)
        image_file = self._convert_gray(file=binary_file, label=label)
        binary_file.unlink()
        logging.info(f"image saved to {image_file}")
        return image_file

    @staticmethod
    def _rgb565_to_rgb888(pixel):
        # Extract red, green, and blue components
        red = (pixel >> 11) & 0x1F  # Extract bits 11-15
        green = (pixel >> 5) & 0x3F  # Extract bits 5-10
        blue = pixel & 0x1F  # Extract bits 0-4
        # Convert to 8-bit per channel (0-255 range)
        # chatgpt magic...
        red = (red << 3) | (red >> 2)  # Scale 5-bit to 8-bit
        green = (green << 2) | (green >> 4)  # Scale 6-bit to 8-bit
        blue = (blue << 3) | (blue >> 2)  # Scale 5-bit to 8-bit
        return (red, green, blue)

    def _convert(self, file: Path, label: str) -> Path:
        with open(file, "rb") as f:
            data = f.read()
        rgb565_pixels = struct.unpack(">" + "H" * (len(data) // 2), data)
        img = Image.new(mode="RGB", size=(IMAGE_WIDTH, IMAGE_HEIGHT))
        rgb888_pixels = [
            FrameReceiver._rgb565_to_rgb888(rgb565_pixel)
            for rgb565_pixel in rgb565_pixels
        ]
        logging.debug(f"number of pixels: {len(rgb888_pixels)}")
        img.putdata(rgb888_pixels)
        img_path = file.with_suffix(".png")
        img.save(img_path)
        return img_path

    def _convert_gray(self, file: Path, label: str) -> Path:
        with open(file, "rb") as f:
            data = f.read()
        print(f"data len: {len(data)}")
        img = Image.frombytes(mode="L", size=(IMAGE_WIDTH, IMAGE_HEIGHT), data=data)        
        img_path = file.with_suffix(".png")
        img.save(img_path)
        return img_path
