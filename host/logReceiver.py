import logging
import socket
from queue import Queue


class LogReceiver:
    def __init__(self, log_queue: Queue, target_log_port: int = 1057) -> None:
        self._target_log_port = target_log_port
        self._log_queue = log_queue
        self._logger = logging.getLogger("LogReceiver")
        self._logger.setLevel(logging.INFO)
        self._logger.debug("instance created")

    def server(self):
        server_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        # Enable SO_REUSEADDR to allow immediate reuse after aborting
        server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server_socket.bind(("0.0.0.0", self._target_log_port))
        self._logger.debug(f"Listening on UDP port {self._target_log_port}...")

        #try:
        while True:
            message, address = server_socket.recvfrom(512)
            self._logger.debug(f"{address}|{message}")
            self._log_queue.put((address[0], message))
         #finally:
         #    server_socket.close()
