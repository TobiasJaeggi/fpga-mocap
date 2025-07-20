import click
import errno
import json
import logging
import typing
from ipaddress import IPv4Address
from pathlib import Path
import numpy as np

from commandSender import CommandSender
from numpyArrayEncoder import NumpyArrayEncoder

def fetch_calibration_data(
    ip: IPv4Address,
) -> typing.Tuple[
    np.typing.NDArray, np.typing.NDArray, np.typing.NDArray, np.typing.NDArray
]:
    """Fetch calibration data from device
    Args:
        ip (ipaddress.IPv4Address): device ip address
    Returns:
        calibration data (
        camera_matrix (NDArray 3x3):  camera intrinsic matrix A [[fx, 0, cx], [0, fy, cy], [0, 0, 1]]
        rotation_matrix (NDArray 3x3): TODO
        translation_vector (NDArray 3x1): TODO
        distortion_coefficients (NDArray 1x5): TODO
    )
    """
    command_sender = CommandSender(target_ip=str(ip))
    try:
        camera_matrix = command_sender.calibration_load_camera_matrix()
        rotation_matrix = command_sender.calibration_load_rotation_matrix()
        translation_vector = command_sender.calibration_load_translation_vector()
        distortion_coefficients = (
            command_sender.calibration_load_distortion_coefficients()
        )
    except OSError as e:  # catch no route to host
        if e.errno == errno.EHOSTUNREACH:
            raise Exception(f"no route to {ip}") from e
    logging.info("calibration data retrieved")
    if (
        camera_matrix is None
        or rotation_matrix is None
        or translation_vector is None
        or distortion_coefficients is None
    ):
        raise ValueError(
            "Failed to fetch calibration data: one or more matrices are None"
        )
    if (
        np.isnan(camera_matrix).any()
        or np.isnan(rotation_matrix).any()
        or np.isnan(translation_vector).any()
        or np.isnan(distortion_coefficients).any()
    ):
        raise ValueError(
            "Failed to fetch calibration data: one or more matrices contain the value nan"
        )
    return camera_matrix, rotation_matrix, translation_vector, distortion_coefficients


def get_calibration_data(ip: IPv4Address) -> dict:
    """Fetch calibration data from device
    Args:
        device (ipaddress.IPv4Address): device ip address
    Returns:
        dict containing calibration data
    )
    """
    camera_matrix, rotation_matrix, translation_vector, distortion_coefficients = (
        fetch_calibration_data(ip=ip)
    )
    d = {
        str(ip): {
            "camera_matrix": camera_matrix,
            "rotation_matrix": rotation_matrix,
            "translation_vector": translation_vector,
            "distortion_coefficients": distortion_coefficients,
        }
    }
    return d



@click.command()
@click.argument(
    "FILE",
    required=True,
)
@click.argument(
    "IP",
    nargs=-1,
    required=True,
)
def main(file, ip):
    """Dump config into json files

        IP: one or multiple device IPs
    """
    
    devices = [IPv4Address(i) for i in ip]
    calibration_data =  {}
    for device in devices:
        calibration_data |= get_calibration_data(ip=device)
    
    with open(file, "w") as f:
        f.write(json.dumps(calibration_data, indent=4, cls=NumpyArrayEncoder))

if __name__ == "__main__":
    main()
