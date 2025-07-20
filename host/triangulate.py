#!/usr/bin/env python

import asyncio
import collections
import json
import logging
import queue
import sys
import time
import typing
from ipaddress import IPv4Address
from pathlib import Path
from threading import Thread
from vispy.visuals.transforms import STTransform

import click
import cv2
import numpy as np
import vispy.scene
from vispy.scene import visuals

from blobReceiver import BlobReceiver
from fetchCalibrationData import fetch_calibration_data

logging.basicConfig(
    level=logging.INFO, style="{", format="[{threadName} ({thread})] {message}"
)


class Camera(typing.NamedTuple):
    P: np.typing.NDArray
    R: np.typing.NDArray  # 3x3 rotation matrix
    T: np.typing.NDArray  # 3x1 translation vector
    K: np.typing.NDArray  # 3x3 camera matrix
    d: np.typing.NDArray  # 1x5 distortion coefficients


CameraSet = typing.NewType("CameraSet", typing.Dict[IPv4Address, Camera])


def undistort_point(
    pt: np.typing.NDArray, camera: Camera
) -> np.typing.NDArray:  # (1,2)
    # Undistort to normalized coordinates
    pt = np.asarray(pt, dtype=np.float32).reshape(1, 1, 2)
    try:
        undistorted_norm = cv2.undistortPoints(
            src=pt,
            cameraMatrix=camera.K,
            distCoeffs=camera.d,
        )
        # undistorted_norm = cv2.undistortPoints(pt, cameraMatrix=camera.K, distCoeffs=camera.d)
    except Exception as e:
        print(pt)
        print(camera.K)
        print(camera.d)
        raise e
    #  Convert back to pixel coordinates
    undistorted_pixel = cv2.convertPointsToHomogeneous(undistorted_norm)[:, 0, :]
    undistorted_pixel = (camera.K @ undistorted_pixel.T).T
    undistorted_pixel = undistorted_pixel[:, :2] / undistorted_pixel[:, 2:]
    print(f"distorted: {pt}, undistorted: {undistorted_pixel}")
    return undistorted_pixel


# TODO: def triangulate_multi_view(pts_2d_list, proj_mats):
# def triangulate_multi_view(pts_2d_list, proj_mats):
#    A = []
#    for pt, P in zip(pts_2d_list, proj_mats):
#        x, y = pt[0], pt[1]
#        A.append(x * P[2] - P[0])
#        A.append(y * P[2] - P[1])
#    A = np.stack(A)
#    _, _, Vt = np.linalg.svd(A)
#    X = Vt[-1]
#    return X[:3] / X[3]
def midpoint_triangulate(points: np.typing.NDArray, cameras: typing.List[Camera]):
    # source: https://stackoverflow.com/questions/28779763/generalisation-of-the-mid-point-method-for-triangulation-to-n-points
    """
    Args:
        x:   Set of 2D points in homogeneous coords, (3 x n) matrix
        cameras: Collection of n objects, each containing member variables
                 cam.P - 3x4 camera matrix
                 cam.R - 3x3 rotation matrix
                 cam.T - 3x1 translation matrix
    Returns:
        midpoint: 3D point in homogeneous coords, (4 x 1) matrix
    """
    n = len(cameras)  # No. of cameras

    I = np.eye(3)  # 3x3 identity matrix
    A = np.zeros((3, n))
    B = np.zeros((3, n))
    sigma2 = np.zeros((3, 1))

    for i, camera in enumerate(cameras):
        a = -np.transpose(camera.R).dot(camera.T)  # ith camera position
        A[:, i, None] = a

        # TODO: n points
        b = np.linalg.pinv(camera.P).dot(points[:, i])  # Directional vector
        # b = np.linalg.pinv(cameraSet[device].P).dot(x[:, i])  # Directional vector
        b = b / b[3]
        b = b[:3, None] - a
        b = b / np.linalg.norm(b)
        B[:, i, None] = b

        sigma2 = sigma2 + b.dot(b.T.dot(a))

    C = (n * I) - B.dot(B.T)
    Cinv = np.linalg.inv(C)
    sigma1 = np.sum(A, axis=1)[:, None]
    m1 = I + B.dot(np.transpose(B).dot(Cinv))
    m2 = Cinv.dot(sigma2)

    midpoint = (1 / n) * m1.dot(sigma1) - m2
    return np.vstack((midpoint, 1))


class Triangulate:
    def __init__(
        self,
        coordinates_queue: asyncio.Queue,
        render_queue: queue.Queue,
        record_queue: typing.Optional[queue.Queue] = None,
    ) -> None:
        self._coordinates_queue = coordinates_queue

        self._ip_to_camera: CameraSet = CameraSet({})
        self._ip_to_coords: typing.Dict[IPv4Address, np.typing.NDArray] = {}
        self._render_queue = render_queue
        self._record_queue = record_queue

    def _flush_queue(self):
        """Flush queue containing coordinates"""

        while not self._coordinates_queue.empty():
            try:
                self._coordinates_queue.get_nowait()
                self._coordinates_queue.task_done()
            except asyncio.QueueEmpty:
                break

    async def triangulate(
        self,
        devices: typing.List[IPv4Address],
        calibration_data: typing.Optional[Path] = None,
    ):
        for ip in devices:
            if calibration_data is None:
                (
                    camera_matrix,
                    rotation_matrix,
                    translation_vector,
                    distortion_coefficients,
                ) = fetch_calibration_data(ip=ip)
            else:
                with open(calibration_data, "r") as f:
                    json_doc = json.load(f)
                    device = json_doc[str(ip)]
                    camera_matrix = np.reshape(device["camera_matrix"], shape=(3, 3))
                    rotation_matrix = np.reshape(
                        device["rotation_matrix"], shape=(3, 3)
                    )
                    translation_vector = np.reshape(
                        device["translation_vector"], shape=(3, 1)
                    )
                    distortion_coefficients = np.reshape(
                        device["distortion_coefficients"], shape=(1, 5)
                    )

            self._ip_to_camera[ip] = Camera(
                P=camera_matrix @ np.hstack((rotation_matrix, translation_vector)),
                R=rotation_matrix,
                T=translation_vector,
                K=camera_matrix,
                d=distortion_coefficients,
            )
            self._ip_to_coords[ip] = np.empty((3, 0), dtype=int)

        self._flush_queue()
        logging.info("waiting for incoming coordinates")
        while True:
            ip, coords = await self._coordinates_queue.get()
            logging.debug(f"{ip} | {coords}")

            if len(coords) == 0:
                self._ip_to_coords[ip] = np.empty((3, 0), dtype=int)
            else:
                c: np.typing.NDArray = np.empty((3, 0), dtype=int)
                for bb in coords:
                    x_min, x_max, y_min, y_max = bb
                    com_x = int(x_min + ((x_max - x_min) / 2))
                    com_y = int(y_min + ((y_max - y_min) / 2))
                    com = np.array([[com_x, com_y]])
                    com = undistort_point(com, self._ip_to_camera[ip])
                    # homogeneous coordinates
                    homo: np.typing.NDArray = np.hstack([com, np.array([[1]])]).reshape(
                        3, 1
                    )
                    # append
                    c = np.hstack((c, homo))
                    # TODO: undistort point
                self._ip_to_coords[ip] = c

            points: np.typing.NDArray = np.empty((3, 0), dtype=int)
            cameras: typing.List[Camera] = []
            for ip in self._ip_to_coords:
                # FIXME: for now we only take the 1st detected coordinate
                if self._ip_to_coords[ip].shape[1] == 0:  # no points
                    continue
                else:
                    points = np.hstack(
                        (points, self._ip_to_coords[ip][:, 0].T.reshape(3, 1))
                    )
                    cameras.append(self._ip_to_camera[ip])
                # FIXME: simply use: (all points)
                # points = np.hstack((points,  self._ip_to_coords[ip]))

            if points.shape[1] == 0 or points.shape[1] == 1:  # not enough points
                self._render_queue.put(None)
                continue

            p = midpoint_triangulate(points=points, cameras=cameras)
            p = p[0:3].reshape((1, 3))
            if self._render_queue.full():
                logging.warning("Render queue is full, dropping data")
            else:
                self._render_queue.put(p)
            if self._record_queue is not None:
                if self._record_queue.full():
                    logging.warning("Record queue is full, dropping data")
                else:
                    self._record_queue.put((time.time(), p))


def render(render_queue: queue.Queue):
    canvas = vispy.scene.SceneCanvas(keys="interactive", show=True, size=(1500,1200))
    vb0 = vispy.scene.widgets.ViewBox(border_color="white", parent=canvas.scene)
    vb1 = vispy.scene.widgets.ViewBox(border_color="white", parent=canvas.scene)
    vb2 = vispy.scene.widgets.ViewBox(border_color="white", parent=canvas.scene)
    vb3 = vispy.scene.widgets.ViewBox(border_color="white", parent=canvas.scene)

    # Put ViewBoxes in a grid
    grid = canvas.central_widget.add_grid()
    
    grid.padding = 6
    grid.add_widget(vb0, row=0, col=0, row_span=3, col_span=3)
    grid.add_widget(vb1, row=0, col=3)
    grid.add_widget(vb2, row=1, col=3)
    grid.add_widget(vb3, row=2, col=3)


    # vispy coordinate system
    #
    #      +z
    #       |
    # +x____|
    #        \
    #        +y
    #
    # (x, y , z)
    # (red, green, blue)
    origin = (0,0,0) # 
    scatters = []
    for vb in [vb0, vb1, vb2, vb3]:
        scatter = visuals.Markers()
        scatter.set_data(
            np.array([[0, 0, 0]]),
            edge_width=0,
            face_color=(1, 1, 1, 1),
            size=5,
        )
        scatters.append(scatter)
        vb.add(scatter)
        axis = visuals.XYZAxis(parent=vb.scene)
        # Scale the axis (change its length)
        axis.transform = STTransform(scale=(0.1, 0.1, 0.1), translate=origin)
      
    center = origin
    distance = 0.3
    #vb0.camera = "arcball"  # https://vispy.org/api/vispy.scene.cameras.html#module-vispy.scene.cameras
    #vb0.camera.center = center
    #vb0.camera.distance = distance
    vb0.camera = vispy.scene.TurntableCamera(fov=45, distance=distance, center=center, elevation=45, azimuth=135)
    vb1.camera = vispy.scene.TurntableCamera(fov=45, distance=distance, center=center, elevation=90, azimuth=0)
    vb2.camera = vispy.scene.TurntableCamera(fov=45, distance=distance, center=center, elevation=0, azimuth=90)
    vb3.camera = vispy.scene.TurntableCamera(fov=45, distance=distance, center=center, elevation=0, azimuth=0)

    # Store recent frames with associated alpha values
    MAX_HISTORY = 30  # Number of frames to persist
    ALPHA_DECAY = 0.98  # Alpha decay factor per frame
    POINT_SIZE = 5
    history = collections.deque(maxlen=MAX_HISTORY)  # stores (points, alpha)

    def update(event):
        try:
            if not render_queue.empty():
                p = render_queue.get_nowait()
                if p is None:
                    # hide markers
                    for scatter in scatters:
                        scatter.set_data(
                            np.array([[0, 0, 0]]),
                            edge_width=0,
                            face_color=(1, 1, 1, 0),
                            size=12,
                        )
                else:
                    logging.info(p)
                    # transform coordinate system to the one the robot arm uses
                    p_new = p.copy()
                    p_new[:,0] = p[:,1] * 1
                    p_new[:,1] = p[:,0] * 1
                    p_new[:,2] = p[:,2] * -1
                    # Add new point with full alpha
                    history.appendleft((p_new, 1.0))  # (points, alpha)

            # Compose point cloud from faded history
            all_points = []
            all_colors = []
            for i, (points, alpha) in enumerate(history):
                faded_alpha = alpha * (ALPHA_DECAY**i)
                colors = np.tile((1, 1, 1, faded_alpha), (points.shape[0], 1))
                all_points.append(points)
                all_colors.append(colors)

            if all_points:
                merged_points = np.vstack(all_points)
                merged_colors = np.vstack(all_colors)
            else:
                merged_points = np.array([[0, 0, 0]])
                merged_colors = np.array([[1, 1, 1, 0]])

            for scatter in scatters:
                scatter.set_data(
                    merged_points,
                    edge_width=0,
                    face_color=merged_colors,
                    size=POINT_SIZE,
                )
        except Exception as e:
            logging.warning(e)

    if sys.flags.interactive != 1:
        timer = vispy.app.Timer()
        timer.connect(update)
        timer.start()
        canvas.measure_fps()
        vispy.app.run()


def recorder(
    record_queue: queue.Queue,
    file: typing.Optional[Path] = None,
):
    if file is not None:
        open(file, "w").close()
        while True:
            with open(file, "a") as f:
                while not record_queue.empty():
                    ts, coords = record_queue.get()
                    f.write(f"({ts},{coords.tolist()})\n")
            time.sleep(0.1)


async def play_back_file(file: Path, coordinates_queue: asyncio.Queue):
    while True:
        with open(file, "r") as f:
            ts_prev = None
            for line in f:
                # FIXME: find a better way which does not use eval
                ts, ip, coords = eval(line, {"IPv4Address": IPv4Address})
                try:
                    coordinates_queue.put_nowait((ip, coords))
                except asyncio.QueueFull:
                    logging.warning(
                        f"coordinates queue full, dropping played back message from {ip}"
                    )
                # TODO: find a way to match timing recorded in file
                if ts_prev is not None:
                    sleep_for = ts - ts_prev
                else:
                    sleep_for = 0.001
                ts_prev = ts
                await asyncio.sleep(sleep_for)
        


async def async_rx(
    render_queue: queue.Queue,
    devices: typing.List[IPv4Address],
    record_2d_to: typing.Optional[Path] = None,
    record_queue: typing.Optional[queue.Queue] = None,
    play_from: typing.Optional[Path] = None,
    calibration_data: typing.Optional[Path] = None,
):
    coordinates_queue: asyncio.Queue = asyncio.Queue(maxsize=5)

    if play_from is None:
        blob_receiver = BlobReceiver(
            coordinates_queue=coordinates_queue, record_to=record_2d_to
        )
        UDP_PORT = 1056
        rx_task = asyncio.ensure_future(
            blob_receiver.serve(host_ip=IPv4Address("0.0.0.0"), udp_port=UDP_PORT)
        )
    else:
        rx_task = asyncio.ensure_future(
            play_back_file(file=play_from, coordinates_queue=coordinates_queue)
        )

    triangulate = Triangulate(
        coordinates_queue=coordinates_queue,
        render_queue=render_queue,
        record_queue=record_queue,
    )
    triangulate_task = asyncio.ensure_future(
        triangulate.triangulate(devices=devices, calibration_data=calibration_data)
    )

    try:
        await asyncio.gather(rx_task, triangulate_task)
    finally:
        rx_task.cancel()
        triangulate_task.cancel()


@click.command()
@click.argument(
    "IP",
    nargs=-1,
    required=True,
)
@click.option(
    "--record-2d",
    help="Optional path to a log file which records all the received 2d marker coordinates",
    type=click.Path(),
    default=None,
    nargs=1,
)
@click.option(
    "--record-3d",
    help="Optional path to a log file which records all the triangulated 3d marker coordinates",
    type=click.Path(),
    default=None,
    nargs=1,
)
@click.option(
    "-p",
    "--play-from",
    help="Optional path to a log file to play back recorded 2d marker coordinates",
    type=click.Path(),
    default=None,
    nargs=1,
)
@click.option(
    "-c",
    "--calibration-data",
    help="Optional path to a json file containing camera calibration data",
    type=click.Path(),
    default=None,
    nargs=1,
)
def main(ip, record_2d, record_3d, play_from, calibration_data) -> None:
    """Triangulate detected marker positions

    IP: one or multiple device IPs
    """

    # Validate mutual exclusivity
    if record_2d and play_from:
        # TODO: is there a way to do this with click decorators?
        raise click.UsageError(
            "Options --record-tp and --play-back are mutually exclusive."
        )

    devices = [IPv4Address(i) for i in ip]
    render_queue: queue.Queue = queue.Queue(maxsize=10)
    record_queue: queue.Queue = queue.Queue(maxsize=50)

    def rx():
        asyncio.run(
            async_rx(
                render_queue=render_queue,
                devices=devices,
                record_2d_to=record_2d,
                record_queue=record_queue,
                play_from=play_from,
                calibration_data=calibration_data,
            )
        )

    rx_thread = Thread(target=rx)
    rx_thread.start()

    record_thread = Thread(
        target=recorder,
        args=(record_queue, record_3d),
    )
    record_thread.start()

    render(render_queue=render_queue)


if __name__ == "__main__":
    main()
