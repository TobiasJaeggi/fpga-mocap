import asyncio
import json
import logging
import queue
import threading
import time
import typing
from ipaddress import IPv4Address
from pathlib import Path

import dearpygui.dearpygui as dpg
import numpy as np

import blobReceiver
import cameraCalibration
import commandSender
import configSender
import frameReceiver
import logReceiver
import positionCalibration

VAO_DEFAULT_IP: typing.Final = "10.0.0.10"
VAO_DEFAULT_NETMASK: typing.Final = "255.255.255.0"
VAO_DEFAULT_GATEWAY: typing.Final = "10.0.0.1"
VAO_DEFAULT_MAC: typing.Final = "00:80:e1:00:00:00"
VAO_DEFAULT_COMMAND_HANDLER_TCP_PORT: typing.Final = 80
FRAME_RECEIVER_DEFAULT_TCP_PORT: typing.Final = 1055
IMAGE_WIDTH: typing.Final = 1280
IMAGE_HEIGHT: typing.Final = 800
IMAGE_CHANNELS: typing.Final = 4
DEFAULT_LOG_FILE: typing.Final = Path(f"/tmp/frameReceiver/logs/{time.strftime('%Y%m%d_%H%M%S')}.log")
DEFAULT_SNAPSHOTS_DIR: typing.Final = Path("/tmp/frameReceiver/snapshots/")
DEFAULT_CONFIG_DIR: typing.Final = Path.cwd()
DEFAULT_CHECKERBOARD_SIZE: typing.Final = (12, 9)
DEFAULT_CHECKERBOARD_CELL_EDGE_LENGTH_M: typing.Final = 0.06
MAX_BLOBS_IN_OVERLAY: typing.Final = 100


def add_vertical_separator(width: int, height: int) -> None:
    dpg.add_spacer(width=width - 1)
    with dpg.drawlist(width=1, height=height):
        dpg.draw_line((0, 0), (0, height), color=(78, 78, 78, 255), thickness=2)


class Commander:
    def __init__(self) -> None:
        self._logger = logging.getLogger("Commander")
        self._logger.setLevel(logging.INFO)

        # vao: visionAddOn
        self._blob_receiver_upd_port = "1056"
        self._vao_log_level = commandSender.LogLevel.INFO.name

        self._command_sender = commandSender.CommandSender(
            target_ip=VAO_DEFAULT_IP,
            target_command_handler_port=VAO_DEFAULT_COMMAND_HANDLER_TCP_PORT,
        )
        self._frame_receiver = frameReceiver.FrameReceiver(
            command_sender=self._command_sender,
            rx_tcp_port=FRAME_RECEIVER_DEFAULT_TCP_PORT,
        )
        self._log_list: typing.List[str] = []
        self._log_queue: queue.Queue = queue.Queue()
        self._log_receiver: logReceiver.LogReceiver = logReceiver.LogReceiver(
            log_queue=self._log_queue
        )
        log_thread = threading.Thread(target=self._log_receiver.server)
        log_thread.start()
        DEFAULT_LOG_FILE.parent.mkdir(parents=True, exist_ok=True)

        self._camera_calibration = cameraCalibration.CameraCalibration(
            images_dir=DEFAULT_SNAPSHOTS_DIR,
            checkerboard_size=DEFAULT_CHECKERBOARD_SIZE,
            checkerboard_cell_edge_length_m=DEFAULT_CHECKERBOARD_CELL_EDGE_LENGTH_M,
        )

        self._position_calibration = positionCalibration.PositionCalibration(
            image=Path(),
            checkerboard_size=DEFAULT_CHECKERBOARD_SIZE,
            checkerboard_cell_edge_length_m=DEFAULT_CHECKERBOARD_CELL_EDGE_LENGTH_M,
            camera_matrix=np.zeros((3, 3), dtype=float),
            distortion_coefficients=np.zeros((1, 5), dtype=float),
        )

        self._coordinates_queue: queue.Queue = queue.Queue(maxsize=10)
        self._blob_receiver = blobReceiver.BlobReceiverThreadWrapper(
            thread_safe_coordinates_queue=self._coordinates_queue
        )

        dpg.create_context()
        dpg.create_viewport(
            title="Commander",
            width=1640,
            height=1200,
        )
        dpg.setup_dearpygui()

        with dpg.window(tag="commander"):
            self.setup_command_strip()
            with dpg.child_window(
                tag="main_window",
                height=840,
                autosize_x=True,
                autosize_y=False,
            ):
                with dpg.tab_bar(tag="main_tab_bar"):
                    with dpg.tab(tag="camera_tab", label="Camera"):
                        self.setup_camera_tab()
                    with dpg.tab(tag="calibrate_optics_tab", label="Calibrate Optics"):
                        self.setup_calibrate_optics_tab()
                    with dpg.tab(
                        tag="calibrate_position_tab", label="Calibrate Position"
                    ):
                        self.setup_calibrate_position_tab()
                    with dpg.tab(
                        tag="config_file_tab", label="Configuration File"
                    ):
                        self.setup_config_file_tab()    
            self.setup_log_window()

        dpg.set_primary_window("commander", True)

        dpg.show_viewport()
        self._logger.debug("instance created")

    def setup_command_strip(self) -> None:
        with dpg.child_window(
            tag="command_strip",
            height=130,
            autosize_x=True,
            autosize_y=False,
        ):
            with dpg.group(horizontal=True):
                with dpg.group(horizontal=False):
                    dpg.add_text(default_value="visionAddOn network configuration")

                    def _set_vao_ip(sender, app_data):
                        self._command_sender.target_ip(app_data)

                    dpg.add_input_text(
                        tag="vao_ip",
                        label="IP",
                        default_value=VAO_DEFAULT_IP,
                        width=100,
                        callback=_set_vao_ip,
                    )

                    def _set_vao_command_handler_tcp_port(sender, app_data):
                        self._command_sender.target_command_handler_port(int(app_data))

                    dpg.add_input_text(
                        tag="vao_command_handler_tcp_port",
                        label="Command Handler TCP Port",
                        default_value=VAO_DEFAULT_COMMAND_HANDLER_TCP_PORT,
                        width=100,
                        callback=_set_vao_command_handler_tcp_port,
                    )
                add_vertical_separator(width=20, height=110)
                with dpg.group(horizontal=False):
                    dpg.add_text(default_value="Host network configuration")

                    def _set_frame_receiver_tcp_port(sender, app_data):
                        self._frame_receiver.rx_tcp_port(app_data)

                    dpg.add_input_text(
                        tag="frame_receiver_tcp_port",
                        label="Frame Receiver TCP Port",
                        default_value=FRAME_RECEIVER_DEFAULT_TCP_PORT,
                        width=100,
                        callback=_set_frame_receiver_tcp_port,
                    )

                    def _set_blob_receiver_upd_port(sender, app_data):
                        self._blob_receiver_upd_port = app_data

                    dpg.add_input_text(
                        tag="blob_receiver_upd_port",
                        label="Blob Receiver UDP Port",
                        default_value=self._blob_receiver_upd_port,
                        width=100,
                        callback=_set_blob_receiver_upd_port,
                    )
                add_vertical_separator(width=20, height=110)

                with dpg.group(horizontal=False):
                    dpg.add_text(
                        default_value="Update visionAddOn network configuration"
                    )
                    WIDTH_CONFIG_INPUT = 160
                    dpg.add_input_text(
                        tag="vao_new_ip",
                        label="IP",
                        default_value=VAO_DEFAULT_IP,
                        width=WIDTH_CONFIG_INPUT,
                    )
                    dpg.add_input_text(
                        tag="vao_new_netmask",
                        label="Netmask",
                        default_value=VAO_DEFAULT_NETMASK,
                        width=WIDTH_CONFIG_INPUT,
                    )
                    dpg.add_input_text(
                        tag="vao_new_gateway",
                        label="Gateway",
                        default_value=VAO_DEFAULT_GATEWAY,
                        width=WIDTH_CONFIG_INPUT,
                    )
                    dpg.add_input_text(
                        tag="vao_new_mac",
                        label="MAC",
                        default_value=VAO_DEFAULT_MAC,
                        width=WIDTH_CONFIG_INPUT,
                    )
                with dpg.group(horizontal=False):
                    dpg.add_spacer(height=20)

                    def _vao_get_network_configuration(sender):
                        result = self._command_sender.network_get_config()
                        if result is None:
                            self._logger.warning("get network config failed")
                            return
                        mac, ip, netmask, gateway = result
                        (dpg.set_value("vao_new_mac", mac),)
                        (dpg.set_value("vao_new_ip", ip),)
                        (dpg.set_value("vao_new_netmask", netmask),)
                        (dpg.set_value("vao_new_gateway", gateway),)

                    dpg.add_button(
                        tag="vao_ge_get_network_configuration",
                        label="Get",
                        width=100,
                        callback=_vao_get_network_configuration,
                    )

                    def _vao_set_network_configuration(sender):
                        self._command_sender.network_set_config(
                            mac=dpg.get_value("vao_new_mac"),
                            ip=dpg.get_value("vao_new_ip"),
                            netmask=dpg.get_value("vao_new_netmask"),
                            gateway=dpg.get_value("vao_new_gateway"),
                        )

                    dpg.add_button(
                        tag="vao_set_network_configuration",
                        label="Set",
                        width=100,
                        callback=_vao_set_network_configuration,
                    )

                    def _vao_persist_network_configuration(sender):
                        self._command_sender.network_persist_config()

                    dpg.add_button(
                        tag="vao_persist_network_configuration",
                        label="Persist",
                        width=100,
                        callback=_vao_persist_network_configuration,
                    )

    def setup_camera_tab(self) -> None:
        with dpg.group(horizontal=True):
            with dpg.group(horizontal=False):
                dpg.add_text(default_value="camera control")

                def _capture_and_transfer_frame(sender):
                    label = "snapshot_" + time.strftime("%Y%m%d_%H%M%S")
                    ip = dpg.get_value("vao_ip")
                    dir = DEFAULT_SNAPSHOTS_DIR / Path(ip.replace(".", "_"))
                    file_path = asyncio.run(
                        self._frame_receiver.receiveSnapshot(label=label, dir=dir)
                    )
                    if file_path:
                        width, height, channels, data = dpg.load_image(str(file_path))
                        dpg.set_value(self._preview_texture_id, data)
                    else:
                        self._logger.warning("loading snapshot failed")

                dpg.add_button(
                    tag="capture_and_transfer_frame",
                    label="Capture",
                    width=100,
                    callback=_capture_and_transfer_frame,
                )
                dpg.add_spacer(height=15)

                def _set_vao_fps(sender, app_data):
                    self._command_sender.fps(fps=commandSender.Fps[app_data])

                dpg.add_combo(
                    label="Camera FPS",
                    tag="set_camera_fps",
                    items=[ll.name for ll in commandSender.Fps],
                    default_value=commandSender.Fps._72.name,
                    width=100,
                    callback=_set_vao_fps,
                )

                def _set_vao_exposure(sender, app_data):
                    self._command_sender.exposure(level=app_data)

                EXPOSURE_MIN = 0
                EXPOSURE_MAX = 0x3FF

                dpg.add_input_int(
                    label=f"Manual exposure [{EXPOSURE_MIN}-{EXPOSURE_MAX}]",
                    tag="camera_manual_exposure",
                    min_value=EXPOSURE_MIN,
                    max_value=EXPOSURE_MAX,
                    min_clamped=True,
                    max_clamped=True,
                    default_value=EXPOSURE_MAX / 2,
                    width=100,
                    callback=_set_vao_exposure,
                )  # TODO: correct max level

                def _set_vao_gain(sender, app_data):
                    self._command_sender.gain(level=int(app_data), band=0)

                GAIN_MIN = 0
                GAIN_MAX = 31

                dpg.add_input_int(
                    label=f"Manual gain [{GAIN_MIN}-{GAIN_MAX}]",
                    tag="camera_manual_gain",
                    min_value=GAIN_MIN,
                    max_value=GAIN_MAX,
                    min_clamped=True,
                    max_clamped=True,
                    default_value=GAIN_MAX / 2,
                    width=100,
                    callback=_set_vao_gain,
                )

                dpg.add_spacer(height=15)

                def _set_vao_white_balance(sender, app_data):
                    self._command_sender.white_balance(
                        rgb=(
                            int(app_data[0] * 1023),
                            int(app_data[1] * 1023),
                            int(app_data[2] * 1023),
                        ),
                    )

                dpg.add_color_picker(
                    label="Manual white balance",
                    tag="camera_manual_white_balance",
                    no_alpha=True,
                    display_rgb=True,
                    width=100,
                    callback=_set_vao_white_balance,
                )

                dpg.add_spacer(height=15)

                def _set_pipeline_bin_threshold(sender, app_data):
                    self._command_sender.pipeline_binarization_threshold(
                        threshold=app_data
                    )

                BIN_THRESHOLD_MIN = 0
                BIN_THRESHOLD_MAX = 0xFF

                dpg.add_input_int(
                    label=f"Binarization threshold [{BIN_THRESHOLD_MIN}-{BIN_THRESHOLD_MAX}]",
                    tag="pipeline_bin_threshold",
                    min_value=BIN_THRESHOLD_MIN,
                    max_value=BIN_THRESHOLD_MAX,
                    min_clamped=True,
                    max_clamped=True,
                    default_value=BIN_THRESHOLD_MAX / 2,
                    width=100,
                    callback=_set_pipeline_bin_threshold,
                )

                def _set_pipeline_input(sender, app_data):
                    self._command_sender.pipeline_input(
                        input=commandSender.PipelineInput[app_data]
                    )

                dpg.add_combo(
                    label="Pipeline input",
                    tag="set_pipeline_input",
                    items=[ll.name for ll in commandSender.PipelineInput],
                    default_value=commandSender.PipelineInput.CAMERA.name,
                    width=100,
                    callback=_set_pipeline_input,
                )

                def _set_pipeline_output(sender, app_data):
                    self._command_sender.pipeline_output(
                        output=commandSender.PipelineOutput[app_data]
                    )

                dpg.add_combo(
                    label="Pipeline output",
                    tag="set_pipeline_output",
                    items=[ll.name for ll in commandSender.PipelineOutput],
                    default_value=commandSender.PipelineOutput.UNPROCESSED.name,
                    width=100,
                    callback=_set_pipeline_output,
                )

                dpg.add_spacer(height=15)

                def _strobe_enable_pulse(sender, app_data):
                    self._command_sender.strobe_enable_pulse(enable=app_data)

                dpg.add_checkbox(
                    tag="strobe_enable_pulse",
                    label="Strobe enable pulse",
                    default_value=False,
                    callback=_strobe_enable_pulse,
                )

                def _set_strobe_on_delay(sender, app_data):
                    self._command_sender.strobe_on_delay(delay_cycles=app_data)

                STROBE_ON_DELAY_MIN = 0
                STROBE_ON_DELAY_MAX = (
                    2**30
                )  # FIXME: up to u32 but there seems to be an issue with add_input_int

                dpg.add_input_int(
                    label=f"Strobe on delay [{STROBE_ON_DELAY_MIN}-{STROBE_ON_DELAY_MAX}]",
                    tag="strobe_on_delay",
                    min_value=STROBE_ON_DELAY_MIN,
                    max_value=STROBE_ON_DELAY_MAX,
                    min_clamped=True,
                    max_clamped=True,
                    default_value=1_000_000,
                    width=100,
                    callback=_set_strobe_on_delay,
                )

                def _set_strobe_hold_time(sender, app_data):
                    self._command_sender.strobe_hold_time(hold_cycles=app_data)

                STROBE_HOLD_TIME_MIN = 0
                STROBE_HOLD_TIME_MAX = (
                    2**30
                )  # FIXME: up to u32 but there seems to be an issue with add_input_int

                dpg.add_input_int(
                    label=f"Strobe hold time [{STROBE_HOLD_TIME_MIN}-{STROBE_HOLD_TIME_MAX}]",
                    tag="strobe_hold_time",
                    min_value=STROBE_HOLD_TIME_MIN,
                    max_value=STROBE_HOLD_TIME_MAX,
                    min_clamped=True,
                    max_clamped=True,
                    default_value=1_300_000,
                    width=100,
                    callback=_set_strobe_hold_time,
                )

                def _strobe_enable_constant(sender, app_data):
                    self._command_sender.strobe_enable_constant(enable=app_data)

                dpg.add_checkbox(
                    tag="strobe_enable_constant",
                    label="Strobe enable constant",
                    default_value=False,
                    callback=_strobe_enable_constant,
                )
                dpg.add_spacer(height=15)

                def _marker_overlay(sender, app_data):
                    if app_data:
                        self._blob_receiver.reset()
                        self._blob_receiver.serve()
                    else:
                        self._blob_receiver.stop()

                dpg.add_checkbox(
                    tag="marker_overlay",
                    label="show markers",
                    default_value=False,
                    callback=_marker_overlay,
                )

            with dpg.texture_registry(show=False):
                self._preview_texture_id = dpg.add_dynamic_texture(
                    width=IMAGE_WIDTH,
                    height=IMAGE_HEIGHT,
                    default_value=[0] * IMAGE_WIDTH * IMAGE_HEIGHT * IMAGE_CHANNELS,
                )
            dpg.add_image(self._preview_texture_id, tag="snapshot")

            OFF_CANVAS = (-100, -100)
            self._blob_ids: typing.List[str] = []
            with dpg.viewport_drawlist():
                for i in range(0, MAX_BLOBS_IN_OVERLAY):
                    blob_id = f"blob_{i}"
                    dpg.draw_rectangle(
                        tag=blob_id,
                        pmin=(0, 0),
                        pmax=(1, 1),
                        color=(255, 0, 0),
                        thickness=2,
                    )
                    self._blob_ids.append(blob_id)

            def _clear_all_blobs():
                for id in self._blob_ids:
                    dpg.configure_item(id, pmin=OFF_CANVAS, pmax=OFF_CANVAS)

            def _draw_overlay():
                time.sleep(
                    1
                )  # FIXME: find a proper way to wait for image pos to be valid. Without sleep, position is [0,0]
                image_position = dpg.get_item_rect_min("snapshot")

                last_clear_request = time.time()
                clear_request = False
                PERSISTANCE_S = 0.5  # how long a blob remains on screen if no new coordinates are received
                while True:
                    try:
                        addr, coords = self._coordinates_queue.get(
                            block=True, timeout=0.1
                        )
                    except queue.Empty:
                        _clear_all_blobs()
                        continue
                    if self._coordinates_queue.full():
                        self._logger.warning(
                            f"can't keep up with blob rx queue, flushing {self._coordinates_queue.qsize()} items"
                        )
                        while not self._coordinates_queue.empty():
                            _, _ = self._coordinates_queue.get(block=False)
                        self._logger.warning(
                            f"after flush: {self._coordinates_queue.qsize()} items"
                        )
                        continue

                    vao_ip = IPv4Address(dpg.get_value("vao_ip"))

                    if addr != vao_ip:
                        # prevent flashing
                        if clear_request:
                            if (time.time() - last_clear_request) > PERSISTANCE_S:
                                _clear_all_blobs()
                                clear_request = False
                        else:
                            clear_request = True
                            last_clear_request = time.time()
                        continue

                    clear_request = False

                    blob_index = 0
                    for coord in coords:
                        if blob_index >= len(self._blob_ids):
                            # can't draw more, drop the rest (the remaining coords might not be from the currently selected vao)
                            break
                        x_min, x_max, y_min, y_max = coord
                        pmin = (x_min + image_position[0], y_min + image_position[1])
                        pmax = (x_max + image_position[0], y_max + image_position[1])
                        dpg.configure_item(
                            self._blob_ids[blob_index], pmin=pmin, pmax=pmax
                        )
                        blob_index += 1

                    # hide the rest
                    for id in self._blob_ids[blob_index:]:
                        dpg.configure_item(id, pmin=OFF_CANVAS, pmax=OFF_CANVAS)

            coords_consumer = threading.Thread(target=_draw_overlay, daemon=True)
            coords_consumer.start()

    def setup_calibrate_optics_tab(self):
        def _set_source_path(sender, app_data):
            if sender == "file_dialog_camera_calibration_image_directory":
                dpg.set_value(
                    "camera_calibration_images_directory_path",
                    app_data["file_path_name"],
                )
            elif sender == "file_dialog_camera_calibration_camera_calibration_output":
                dpg.set_value(
                    "camera_calibration_output_file", app_data["file_path_name"]
                )

        dpg.add_file_dialog(
            directory_selector=True,
            show=False,
            callback=_set_source_path,
            tag="file_dialog_camera_calibration_image_directory",
            width=700,
            height=400,
            default_path=str(DEFAULT_SNAPSHOTS_DIR),
        )

        with dpg.group(horizontal=True):
            dpg.add_button(
                label="Browse",
                callback=lambda: dpg.show_item(
                    "file_dialog_camera_calibration_image_directory"
                ),
            )
            dpg.add_input_text(
                tag="camera_calibration_images_directory_path",
                default_value=str(DEFAULT_SNAPSHOTS_DIR),
                width=400,
                label="Image directory",
            )

        def _set_checkerboard_size(sender, app_data):
            self._camera_calibration.checkerboard_size = (
                dpg.get_value("camera_calibration_checkerboard_row"),
                dpg.get_value("camera_calibration_checkerboard_columns"),
            )

        dpg.add_input_int(
            tag="camera_calibration_checkerboard_row",
            label="checkerboard rows",
            default_value=12,
            width=70,
            callback=_set_checkerboard_size,
        )
        dpg.add_input_int(
            tag="camera_calibration_checkerboard_columns",
            label="checkerboard columns",
            default_value=9,
            width=70,
        )

        def _set_checkerboard_cell_edge_length(sender, app_data):
            self._camera_calibration.checkerboard_cell_edge_length_m = app_data

        dpg.add_input_float(
            tag="camera_calibration_checkerboard_cell_edge_length_m",
            label="checkerboard cell edge length [m]",
            default_value=0.06,
            width=70,
            step=0,
            callback=_set_checkerboard_cell_edge_length,
        )

        with dpg.group(horizontal=True):

            def _update_calibration_data_from_file():
                with open(dpg.get_value("camera_calibration_output_file"), "r") as f:
                    json_doc = json.load(f)
                mtx = np.reshape(json_doc["camera_matrix"], shape=(3, 3))
                dist = np.reshape(json_doc["distortion_coefficients"], shape=(1, 5))
                err = json_doc["mean_reprojection_error"]
                dpg.set_value("camera_matrix_file", f"camera matrix:\n{mtx}")
                dpg.set_value(
                    "distortion_coefficients_file", f"distortion coefficients:\n{dist}"
                )
                dpg.set_value(
                    "mean_reprojection_error_file", f"mean reprojection error:\n{err}"
                )

            def _compute_camera_matrix(sender):
                self._camera_calibration.images_dir = Path(
                    dpg.get_value("camera_calibration_images_directory_path")
                )
                calibration_file = self._camera_calibration.compute_camera_matrix(
                    show_overlay=dpg.get_value("compute_camera_matrix_show_overlay")
                )
                if calibration_file is None:
                    self._logger.error("computing camera calibration failed")
                    return
                self._logger.info(f"calibration data stored to {calibration_file}")
                dpg.set_value("camera_calibration_output_file", str(calibration_file))
                _update_calibration_data_from_file()

            dpg.add_button(
                tag="compute_camera_matrix",
                label="Compute camera matrix",
                callback=_compute_camera_matrix,
            )
            dpg.add_checkbox(
                tag="compute_camera_matrix_show_overlay",
                label="Show overlay",
                default_value=True,
            )

        dpg.add_spacer(height=5)
        dpg.add_separator()

        with dpg.file_dialog(
            directory_selector=False,
            show=False,
            callback=_set_source_path,
            tag="file_dialog_camera_calibration_camera_calibration_output",
            width=700,
            height=400,
            default_path=str(DEFAULT_SNAPSHOTS_DIR),
        ):
            dpg.add_file_extension(".json")

        with dpg.group(horizontal=True):
            dpg.add_button(
                label="Browse",
                callback=lambda: dpg.show_item(
                    "file_dialog_camera_calibration_camera_calibration_output"
                ),
            )
            dpg.add_input_text(
                tag="camera_calibration_output_file",
                default_value=str(DEFAULT_SNAPSHOTS_DIR),
                width=400,
                label="Camera calibration file",
            )
        dpg.add_button(
            label="Reload", callback=lambda: _update_calibration_data_from_file()
        )
        with dpg.child_window(
            tag="camera_calibration_data_file_window",
            width=1080,
            height=140,
            autosize_x=True,
            autosize_y=False,
        ):
            dpg.add_text(tag="camera_matrix_file", default_value="")
            dpg.add_text(tag="distortion_coefficients_file", default_value="")
            dpg.add_text(tag="mean_reprojection_error_file", default_value="")

        def _persist_calibration_data(sender):
            with open(dpg.get_value("camera_calibration_output_file"), "r") as f:
                json_load = json.load(f)
                mtx = np.asarray(json_load["camera_matrix"])
                dist = np.asarray(json_load["distortion_coefficients"])
                self._command_sender.calibration_store_camera_matrix(mtx)
                self._command_sender.calibration_store_distortion_coefficients(dist)

        dpg.add_button(
            tag="persist_camera_calibration_data",
            label="Persist to device",
            callback=_persist_calibration_data,
            width=200,
        )

        dpg.add_spacer(height=5)
        dpg.add_separator()

        def _load_calibration_data(sender):
            mtx = self._command_sender.calibration_load_camera_matrix()
            dist = self._command_sender.calibration_load_distortion_coefficients()
            dpg.set_value("camera_matrix_device", f"camera matrix:\n{mtx}")
            dpg.set_value(
                "distortion_coefficients_device", f"distortion coefficients:\n{dist}"
            )

        dpg.add_button(
            tag="load_camera_calibration_data",
            label="Load from device",
            callback=_load_calibration_data,
            width=200,
        )

        with dpg.child_window(
            tag="camera_calibration_data_device_window",
            width=1080,
            height=110,
            autosize_x=True,
            autosize_y=False,
        ):
            dpg.add_text(tag="camera_matrix_device", default_value="")
            dpg.add_text(tag="distortion_coefficients_device", default_value="")

    def setup_calibrate_position_tab(self) -> None:
        def _set_source_path(sender, app_data):
            if sender == "file_dialog_position_calibration_image":
                dpg.set_value(
                    "position_calibration_image_path", app_data["file_path_name"]
                )
            elif (
                sender == "file_dialog_position_calibration_position_calibration_output"
            ):
                dpg.set_value(
                    "position_calibration_output_file", app_data["file_path_name"]
                )

        with dpg.file_dialog(
            directory_selector=False,
            show=False,
            callback=_set_source_path,
            tag="file_dialog_position_calibration_image",
            width=700,
            height=400,
            default_path=str(DEFAULT_SNAPSHOTS_DIR),
        ):
            dpg.add_file_extension(".png")

        with dpg.group(horizontal=True):
            dpg.add_button(
                label="Browse",
                callback=lambda: dpg.show_item(
                    "file_dialog_position_calibration_image"
                ),
            )
            dpg.add_input_text(
                tag="position_calibration_image_path",
                default_value=str(DEFAULT_SNAPSHOTS_DIR),
                width=400,
                label="Image",
            )

        def _set_checkerboard_size(sender, app_data):
            self._position_calibration.checkerboard_size = (
                dpg.get_value("position_calibration_checkerboard_row"),
                dpg.get_value("position_calibration_checkerboard_columns"),
            )

        dpg.add_input_int(
            tag="position_calibration_checkerboard_row",
            label="checkerboard rows",
            default_value=12,
            width=70,
            callback=_set_checkerboard_size,
        )
        dpg.add_input_int(
            tag="position_calibration_checkerboard_columns",
            label="checkerboard columns",
            default_value=9,
            width=70,
        )

        def _set_checkerboard_cell_edge_length(sender, app_data):
            self._position_calibration.checkerboard_cell_edge_length_m = app_data

        dpg.add_input_float(
            tag="position_calibration_checkerboard_cell_edge_length_m",
            label="checkerboard cell edge length [m]",
            default_value=0.06,
            width=70,
            step=0,
            callback=_set_checkerboard_cell_edge_length,
        )

        with dpg.group(horizontal=True):

            def _update_calibration_data_from_file():
                with open(dpg.get_value("position_calibration_output_file"), "r") as f:
                    json_doc = json.load(f)
                rot = np.reshape(json_doc["rotation_matrix"], shape=(3, 3))
                trans = np.reshape(json_doc["translation_vector"], shape=(3, 1))
                dpg.set_value("rotation_matrix_file", f"rotation matrix:\n{rot}")
                dpg.set_value(
                    "translation_vector_file", f"translation vector:\n{trans}"
                )

            def _compute_camera_position(sender):
                self._position_calibration.camera_matrix = (
                    self._command_sender.calibration_load_camera_matrix()
                )
                self._position_calibration.distortion_coefficients = (
                    self._command_sender.calibration_load_distortion_coefficients()
                )
                self._position_calibration.image = Path(
                    dpg.get_value("position_calibration_image_path")
                )
                calibration_file = self._position_calibration.compute_camera_position(
                    show_overlay=dpg.get_value("compute_camera_position_show_overlay")
                )
                if calibration_file is None:
                    self._logger.error("computing camera position failed")
                    return
                self._logger.info(f"calibration data stored to {calibration_file}")
                dpg.set_value("position_calibration_output_file", str(calibration_file))
                _update_calibration_data_from_file()

            dpg.add_button(
                tag="compute_camera_position",
                label="Compute camera position",
                callback=_compute_camera_position,
            )
            dpg.add_checkbox(
                tag="compute_camera_position_show_overlay",
                label="Show overlay",
                default_value=True,
            )

        dpg.add_spacer(height=5)
        dpg.add_separator()

        with dpg.file_dialog(
            directory_selector=False,
            show=False,
            callback=_set_source_path,
            tag="file_dialog_position_calibration_position_calibration_output",
            width=700,
            height=400,
            default_path=str(DEFAULT_SNAPSHOTS_DIR),
        ):
            dpg.add_file_extension(".json")

        with dpg.group(horizontal=True):
            dpg.add_button(
                label="Browse",
                callback=lambda: dpg.show_item(
                    "file_dialog_position_calibration_position_calibration_output"
                ),
            )
            dpg.add_input_text(
                tag="position_calibration_output_file",
                default_value=str(DEFAULT_SNAPSHOTS_DIR),
                width=400,
                label="Position calibration file",
            )
        dpg.add_button(
            label="Reload", callback=lambda: _update_calibration_data_from_file()
        )

        with dpg.child_window(
            tag="position_calibration_data_file_window",
            width=1080,
            height=130,
            autosize_x=True,
            autosize_y=False,
        ):
            dpg.add_text(tag="rotation_matrix_file", default_value="")
            dpg.add_text(tag="translation_vector_file", default_value="")

        def _persist_calibration_data(sender):
            with open(dpg.get_value("position_calibration_output_file"), "r") as f:
                json_load = json.load(f)
                rot = np.asarray(json_load["rotation_matrix"])
                trans = np.asarray(json_load["translation_vector"])
                self._logger.error(f"translation vec{trans}")
                self._command_sender.calibration_store_rotation_matrix(rot)
                self._command_sender.calibration_store_translation_vector(trans)

        dpg.add_button(
            tag="persist_position_calibration_data",
            label="Persist to device",
            callback=_persist_calibration_data,
            width=200,
        )

        dpg.add_spacer(height=5)
        dpg.add_separator()

        def _load_calibration_data(sender):
            rot = self._command_sender.calibration_load_rotation_matrix()
            trans = self._command_sender.calibration_load_translation_vector()
            dpg.set_value("rotation_matrix_device", f"rotation matrix:\n{rot}")
            dpg.set_value("translation_vector_device", f"translation vector:\n{trans}")

        dpg.add_button(
            tag="load_position_calibration_data",
            label="Load from device",
            callback=_load_calibration_data,
            width=200,
        )

        with dpg.child_window(
            tag="position_calibration_data_device_window",
            width=1080,
            height=130,
            autosize_x=True,
            autosize_y=False,
        ):
            dpg.add_text(tag="rotation_matrix_device", default_value="")
            dpg.add_text(tag="translation_vector_device", default_value="")

    def setup_config_file_tab(self) -> None:
        def _set_source_path(sender, app_data):
                dpg.set_value(
                    "config_file_path", app_data["file_path_name"]
                )

        with dpg.file_dialog(
            directory_selector=False,
            show=False,
            callback=_set_source_path,
            tag="file_dialog_config_file",
            width=700,
            height=400,
            default_path=str(DEFAULT_CONFIG_DIR),
        ):
            dpg.add_file_extension(".json")

        with dpg.group(horizontal=True):
            dpg.add_button(
                label="Browse",
                callback=lambda: dpg.show_item(
                    "file_dialog_config_file"
                ),
            )
            dpg.add_input_text(
                tag="config_file_path",
                default_value=str(DEFAULT_CONFIG_DIR),
                width=400,
                label="Configuration file",
            )
    
        def _apply_config_file(sender):
            configSender.apply_config_file(Path(dpg.get_value("config_file_path")))
        dpg.add_button(
            tag="apply_config_file",
            label="Apply config file",
            callback=_apply_config_file,
            width=200,
        )
    
    def setup_log_window(self) -> None:
        with dpg.child_window(tag="log_window", autosize_x=True, autosize_y=True):
            with dpg.group(horizontal=True):
                dpg.add_text(default_value="Log configuration")
                vao_log_levels = [ll.name for ll in commandSender.LogLevel]

                def _set_vao_log_level(sender, app_data):
                    self._vao_log_level = app_data
                    self._command_sender.log_level(
                        commandSender.LogLevel[self._vao_log_level]
                    )

                dpg.add_combo(
                    tag="vao_log_level",
                    items=vao_log_levels,
                    default_value=self._vao_log_level,
                    width=100,
                    callback=_set_vao_log_level,
                )
                dpg.add_input_text(
                    tag="log_file_path", default_value=str(DEFAULT_LOG_FILE), width=400
                )

                def _save_log(sender):
                    with open(dpg.get_value("log_file_path"), "w") as f:
                        f.writelines("\n".join(self._log_list))

                dpg.add_button(
                    tag="save_log", label="save", width=100, callback=_save_log
                )
                dpg.add_checkbox(
                    tag="log_auto_scroll", label="auto scroll", default_value=True
                )
            with dpg.child_window(
                tag="log_scroll",
                autosize_x=True,
                autosize_y=True,
            ):
                dpg.add_text("", tag="log_text")

                def _consume():
                    while True:
                        addr, msg = self._log_queue.get()
                        self._log_list.append(f"{addr} | {msg}")
                        log_text = "\n".join(self._log_list)
                        dpg.set_value("log_text", log_text)
                        if dpg.get_value("log_auto_scroll"):
                            dpg.set_y_scroll(
                                "log_scroll", dpg.get_y_scroll_max("log_scroll") + 20
                            )

                log_consumer = threading.Thread(target=_consume, daemon=True)
                log_consumer.start()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    Commander()
    dpg.start_dearpygui()
    dpg.destroy_context()
