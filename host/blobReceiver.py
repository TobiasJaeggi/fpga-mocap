#!/usr/bin/env python
import asyncio
import logging
import math
import queue
import socket
import threading
import time
import typing
from ipaddress import IPv4Address
from pathlib import Path

import click

logging.basicConfig(
    level=logging.INFO, style="{", format="[{threadName} ({thread})] {message}"
)


def recorder(thread_safe_coordinates_queue: queue.Queue, file: Path) -> None:
    open(file, "w").close()
    while True:
        with open(file, "a") as f:
            while not thread_safe_coordinates_queue.empty():
                f.write(f"{thread_safe_coordinates_queue.get()}\n")
        time.sleep(0.1)


# https://lucas-six.github.io/python-cookbook/recipes/core/udp_server_asyncio.html
class BlobReceiver(asyncio.DatagramProtocol):
    def __init__(
        self,
        coordinates_queue: typing.Union[asyncio.Queue, queue.Queue],
        record_to: typing.Optional[Path] = None,
    ) -> None:
        self._coordinates_queue = coordinates_queue
        self._BITS_X: typing.Final[int] = math.ceil(math.log2(1280))
        self._BITS_Y: typing.Final[int] = math.ceil(math.log2(800))
        FEATURE_WIDTH: typing.Final[int] = (self._BITS_X + self._BITS_Y) * 2
        self._BYTES_PADDED_FEATURE_VECTOR: typing.Final[int] = math.ceil(
            FEATURE_WIDTH / 8.0
        )
        self._ip_to_previous_frame_count: typing.Dict[IPv4Address, int] = {}

        if record_to is not None:
            self._file_queue: queue.Queue = queue.Queue(maxsize=1000)
            threading.Thread(
                target=recorder,
                args=(
                    self._file_queue,
                    record_to,
                ),
            ).start()
            self._record = True
        else:
            self._record = False

    def _get_coords(
        self, ip: IPv4Address, data: bytes
    ) -> typing.List[typing.Tuple[int, int, int, int]]:
        OFFSET_FRAME_COUNT: typing.Final[int] = 0
        SIZE_FRAME_COUNT: typing.Final[int] = 1
        OFFSET_LENGTH: typing.Final[int] = OFFSET_FRAME_COUNT + SIZE_FRAME_COUNT
        SIZE_LENGTH: typing.Final[int] = 1
        OFFSET_FEATURES: typing.Final[int] = OFFSET_LENGTH + SIZE_LENGTH

        frame_count: typing.Final[int] = int.from_bytes(
            data[OFFSET_FRAME_COUNT : OFFSET_FRAME_COUNT + SIZE_FRAME_COUNT], "little"
        )
        if ip not in self._ip_to_previous_frame_count:
            self._ip_to_previous_frame_count[ip] = frame_count
            logging.info(f"new device found: {ip}")
        elif abs(frame_count - self._ip_to_previous_frame_count[ip]) not in (1, 255):
            logging.error(
                f"missed at least one frame! (from {self._ip_to_previous_frame_count[ip]} to {frame_count})"
            )
        self._ip_to_previous_frame_count[ip] = frame_count

        number_of_features: typing.Final[int] = int.from_bytes(
            data[OFFSET_LENGTH : OFFSET_LENGTH + SIZE_LENGTH], "little"
        )

        if number_of_features != ((len(data) - SIZE_FRAME_COUNT - SIZE_LENGTH) / self._BYTES_PADDED_FEATURE_VECTOR):
            raise ValueError

        OFFSET_Y_MAX: typing.Final[int] = 0
        OFFSET_Y_MIN: typing.Final[int] = OFFSET_Y_MAX + self._BITS_Y
        OFFSET_X_MAX: typing.Final[int] = OFFSET_Y_MIN + self._BITS_Y
        OFFSET_X_MIN: typing.Final[int] = OFFSET_X_MAX + self._BITS_X

        MASK_X: typing.Final[int] = (1 << self._BITS_X) - 1
        MASK_Y: typing.Final[int] = (1 << self._BITS_Y) - 1

        vecs_int = []
        for i in range(0, number_of_features):
            offset_current_feature_vector = (
                OFFSET_FEATURES + i * self._BYTES_PADDED_FEATURE_VECTOR
            )
            padded_feature_vector = int.from_bytes(
                data[
                    offset_current_feature_vector : offset_current_feature_vector
                    + self._BYTES_PADDED_FEATURE_VECTOR
                    + 1
                ],
                "little",
            )
            x_min = (padded_feature_vector >> OFFSET_X_MIN) & MASK_X
            x_max = (padded_feature_vector >> OFFSET_X_MAX) & MASK_X
            y_min = (padded_feature_vector >> OFFSET_Y_MIN) & MASK_Y
            y_max = (padded_feature_vector >> OFFSET_Y_MAX) & MASK_Y
            logging.debug(
                f"x_min: {x_min}, x_max: {x_max}, y_min: {y_min}, y_max: {y_max}"
            )
            vecs_int.append((x_min, x_max, y_min, y_max))
        return vecs_int

    def connection_made(  # type: ignore[override]
        self, transport: asyncio.DatagramTransport
    ) -> None:
        self.transport = transport
        sock = transport.get_extra_info("socket")
        server_address = transport.get_extra_info("sockname")
        assert sock.getsockname() == server_address
        logging.debug(f"Server address: {server_address}")

    def connection_lost(self, exc) -> None:
        logging.warning("connection lost")

    def pause_writing(self) -> None:
        logging.warning("pause writing")

    def resume_writing(self) -> None:
        logging.info("resume writing")

    def datagram_received(self, data: bytes, addr: tuple[str, int]) -> None:
        """Called when a datagram is received

        Args:
            data (bytes): data
            addr (tuple[str, int]): remote ip, remote port
        """
        sock = self.transport.get_extra_info("socket")
        assert sock.type is socket.SOCK_DGRAM
        assert not sock.getsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR)
        assert sock.gettimeout() == 0.0

        logging.debug(f"server: {data!r}, from: {addr}")

        ip = IPv4Address(addr[0])
        try:
            coords = self._get_coords(ip, data)
        except ValueError:
            logging.warning("Invalid data format, dropping message")
            return

        try:
            self._coordinates_queue.put_nowait((ip, coords))
        except (asyncio.QueueFull, queue.Full):
            logging.warning(f"coordinates queue full, dropping message from {ip}")

        if self._record:
            try:
                # TODO: once the blob receiver hardware sends out a timestamp, use it instead of time.time()
                self._file_queue.put_nowait((time.time(), ip, coords))
            except (asyncio.QueueFull, queue.Full):
                logging.warning(f"record queue full, dropping message from {ip}")

    def error_received(self):
        logging.warning("error received")

    async def serve(
        self,
        host_ip: IPv4Address = IPv4Address("0.0.0.0"),
        udp_port: int = 1056,
        stop_event: typing.Optional[asyncio.Event] = None,
    ) -> None:
        loop = asyncio.get_running_loop()
        transport, _ = await loop.create_datagram_endpoint(
            lambda: self,
            (str(host_ip), udp_port),
            reuse_port=True,
        )
        logging.info("server running")
        try:
            while (stop_event is None) or (
                not stop_event.is_set()
            ):  # run until stop event
                await asyncio.sleep(1)
            logging.info("BlobReceiver server: stop event")
        finally:
            transport.close()
            logging.info("BlobReceiver server: stopped")


class BlobReceiverThreadWrapper:
    def __init__(
        self,
        thread_safe_coordinates_queue: queue.Queue,
        record_to: typing.Optional[Path] = None,
    ) -> None:
        self._coordinates_queue = thread_safe_coordinates_queue
        self._blob_receiver = BlobReceiver(
            coordinates_queue=thread_safe_coordinates_queue,
            record_to=record_to,
        )
        self._stop = asyncio.Event()
        self._thread: typing.Optional[threading.Thread] = None

    def serve(
        self,
        host_ip: IPv4Address = IPv4Address("0.0.0.0"),
        udp_port: int = 1056,
    ) -> None:
        if self._thread is None or not self._thread.is_alive():

            async def async_runner():
                rx = asyncio.create_task(
                    self._blob_receiver.serve(
                        stop_event=self._stop, host_ip=host_ip, udp_port=udp_port
                    )
                )
                try:
                    await asyncio.gather(rx)
                finally:
                    rx.cancel()

            def sync_runner():
                asyncio.run(async_runner())

            print("create thread")
            self._thread = threading.Thread(target=sync_runner)
            print("thread created")
            self._thread.start()
            print("launched")
        else:
            logging.warning(
                "serve blob receiver ignored, server thread already running"
            )

    def stop(self) -> None:
        if self._thread is not None and self._thread.is_alive():
            self._stop.set()
            print("waiting for join")
            self._thread.join()
            print("joined")

        else:
            logging.warning(
                "stop blob receiver server ignored, server thread already stopped or never ran"
            )

    def reset(self) -> None:
        if self._thread is not None and self._thread.is_alive():
            logging.warning(
                "reset blob receiver server ignored, server thread running, call stop first"
            )
        else:
            self._stop.clear()


QUEUE_DEPTH: typing.Final = 3


async def async_consume(coordinates_queue: asyncio.Queue) -> None:
    while True:
        ip, coords = await coordinates_queue.get()
        logging.info(f"{ip} | {coords}")


async def native(record_to: typing.Optional[Path] = None) -> None:
    coordinate_queue: asyncio.Queue = asyncio.Queue(maxsize=QUEUE_DEPTH)
    blob_receiver = BlobReceiver(
        coordinates_queue=coordinate_queue, record_to=record_to
    )
    server_task = asyncio.create_task(blob_receiver.serve())
    consumer_task = asyncio.create_task(
        async_consume(coordinates_queue=coordinate_queue)
    )

    try:
        await asyncio.gather(server_task, consumer_task)
    finally:
        server_task.cancel()
        consumer_task.cancel()


def consume(thread_safe_coordinates_queue: queue.Queue) -> None:
    while True:
        ip, coords = thread_safe_coordinates_queue.get()
        logging.info(f"{ip} | {coords}")


def thread_wrapper(record_to: typing.Optional[Path] = None) -> None:
    coordinates_queue: queue.Queue = queue.Queue(maxsize=QUEUE_DEPTH)
    wrapper = BlobReceiverThreadWrapper(
        thread_safe_coordinates_queue=coordinates_queue, record_to=record_to
    )
    threading.Thread(target=consume, args=(coordinates_queue,)).start()
    wrapper.serve()
    while True:
        import time

        time.sleep(1)


@click.command()
@click.option(
    "-m",
    "--mode",
    help="Select between asyncio native or thread wrapper execution",
    type=click.Choice(["NATIVE", "WRAPPER"]),
    #    case_sensitive=False,  # FIXME
    default="NATIVE",
    nargs=1,
)
@click.option(
    "-r",
    "--record-to",
    help="Optional path to a log file which records all the received coordinates",
    type=click.Path(),
    default=None,
    nargs=1,
)
def main(mode, record_to) -> None:
    click.echo(mode)
    match mode:
        case "NATIVE":
            asyncio.run(native(record_to=record_to))
        case "WRAPPER":
            thread_wrapper(record_to=record_to)
        case _:
            click.echo("invalid mode")


if __name__ == "__main__":
    main()
