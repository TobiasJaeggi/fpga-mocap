#!/usr/bin/env python
import queue
import typing

import pygame

import blobReceiver


def draw_screen(screen, coords: typing.List[typing.Tuple[int, int, int, int]]) -> None:
    CIRCLE_SIZE: typing.Final[int] = 5
    screen.fill("black")
    for coord in coords:
        x_min, x_max, y_min, y_max = coord
        com_x = int(x_min + ((x_max - x_min) / 2))
        com_y = int(y_min + ((y_max - y_min) / 2))
        pygame.draw.circle(screen, "white", (com_x, com_y), CIRCLE_SIZE)
    pygame.display.flip()


def draw_loop(queue: queue.Queue, resolution: typing.Tuple[int, int], fps: int) -> None:
    pygame.init()
    screen = pygame.display.set_mode(resolution)
    clock = pygame.time.Clock()
    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                exit(0)
        if not queue.empty():
            _ip, coords = queue.get_nowait()
            draw_screen(screen=screen, coords=coords)

        clock.tick(fps)


def main() -> None:
    QUEUE_SIZE: typing.Final[int] = 5
    RESOLUTION: typing.Final[typing.Tuple[int, int]] = (1280, 800)
    FPS: typing.Final[int] = 120
    coordinates_queue: queue.Queue = queue.Queue(maxsize=QUEUE_SIZE)
    blob_receiver = blobReceiver.BlobReceiverThreadWrapper(
        thread_safe_coordinates_queue=coordinates_queue
    )
    blob_receiver.serve()
    pygame.display.set_caption("blob receiver")
    icon = pygame.image.load("icon.svg")
    pygame.display.set_icon(icon)
    draw_loop(queue=coordinates_queue, resolution=RESOLUTION, fps=FPS)


if __name__ == "__main__":
    main()
