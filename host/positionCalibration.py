import glob
import json
import logging
from pathlib import Path
from typing import Any, Dict, Optional, Tuple

import cv2
import numpy as np

from numpyArrayEncoder import NumpyArrayEncoder


class PositionCalibration:
    def __init__(
        self,
        image: Path,
        checkerboard_size: tuple[int, int],
        checkerboard_cell_edge_length_m: float,
        camera_matrix: np.typing.NDArray,
        distortion_coefficients: np.typing.NDArray,
    ):
        """create an instance of PositionCalibration
        Args:
            image (Path): The path to the image used to calibrate the position
            checkerboard_size (tuple[int, int]): The dimensions of the checkerboard pattern used for calibration, specified as (rows, columns).
            checkerboard_cell_edge_length_m (float): The length of one side of a checkerboard cell
            in meters.
            camera_matrix (NDArray 3x3):  camera intrinsic matrix A [[fx, 0, cx], [0, fy, cy], [0, 0, 1]]
            distortion_coefficients (NDArray 1x5): distortion coefficients [k1, k2, p1, p2, k3]
        """
        self._logger = logging.getLogger("CameraCalibration")
        self._logger.setLevel(logging.INFO)
        self.image = image
        self.checkerboard_size = checkerboard_size
        self.checkerboard_cell_edge_length_m = checkerboard_cell_edge_length_m
        self.camera_matrix = camera_matrix
        self.distortion_coefficients = distortion_coefficients
        self._logger.debug("instance created")

    @property
    def image(self) -> Path:
        return self._image

    @image.setter
    def image(self, value: Path):
        self._image = value

    @property
    def checkerboard_size(self) -> Tuple[int, int]:
        assert len(self._pattern_size) == 2
        return tuple([e + 1 for e in self._pattern_size])  # from OpenCV size

    @checkerboard_size.setter
    def checkerboard_size(self, value: Tuple[int, int]):
        self._pattern_size = [e - 1 for e in value]  # to OpenCV size

    @property
    def checkerboard_cell_edge_length_m(self) -> float:
        return self._cell_edge_length_m

    @checkerboard_cell_edge_length_m.setter
    def checkerboard_cell_edge_length_m(self, value: float):
        self._cell_edge_length_m = value

    @property
    def camera_matrix(self) -> np.typing.NDArray:
        return self._camera_matrix

    @camera_matrix.setter
    def camera_matrix(self, value: np.typing.NDArray):
        assert value.shape == (3, 3), "invalid camera matrix shape"
        self._camera_matrix = value

    @property
    def distortion_coefficients(self) -> np.typing.NDArray:  # 1x5
        return self._distortion_coefficients

    @distortion_coefficients.setter
    def distortion_coefficients(self, value: np.typing.NDArray):  # 1x5
        assert value.shape == (1, 5), "invalid distortion coefficients shape"
        self._distortion_coefficients = value

    def compute_camera_position(self, show_overlay: bool = True) -> Optional[Path]:
        """Perform position calibration
        Args:
            show_overlay (bool): If True, displays the checkerboard overlay on the image during processing.
        Returns:
            Path: The path to the JSON file containing the calibration data.
        """
        img = cv2.imread(str(self.image))
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        pattern_size = [e - 1 for e in self.checkerboard_size]  # to OpenCV size
        ret, corners = cv2.findChessboardCorners(gray, pattern_size, None)
        if ret is False:
            self._logger.error(f"no corners found in image {str(self.image)}")
            return None

        # termination criteria
        criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.001)

        corners2 = cv2.cornerSubPix(
            image=gray,
            corners=corners,
            winSize=(11, 11),
            zeroZone=(-1, -1),
            criteria=criteria,
        )


        if show_overlay:
            # Draw and display the corners
            cv2.drawChessboardCorners(
                image=img,
                patternSize=(self._pattern_size[0], self._pattern_size[1]),
                corners=corners2,
                patternWasFound=ret,
            )
            cv2.imshow("img", img)
            cv2.waitKey(1000)
        cv2.destroyAllWindows()

        objp = np.zeros((pattern_size[0] * pattern_size[1], 3), np.float32)
        objp[:, :2] = (
            np.mgrid[0 : pattern_size[0], 0 : pattern_size[1]].T.reshape(-1, 2)
            * self.checkerboard_cell_edge_length_m
        )
        # Find the rotation and translation vectors.
        ret, rotation_vector, translation_vector = cv2.solvePnP(
            objp, corners2, self.camera_matrix, self.distortion_coefficients
        )
        # https://stackoverflow.com/questions/14444433/calculate-camera-world-position-with-opencv-python
        rotation_matrix = cv2.Rodrigues(rotation_vector)[0]
        # rotation_matrix: R in https://en.wikipedia.org/wiki/Camera_resectioning
        # translation_vector: T in https://en.wikipedia.org/wiki/Camera_resectioning

        self._logger.info(f"rotation_vector: {rotation_vector}")
        self._logger.info(f"translation_vector: {translation_vector}")
        self._logger.info(f"rotation_matrix: {rotation_matrix}")

        calibration_data = {
            "camera_matrix": self.camera_matrix,
            "distortion_coefficients": self.distortion_coefficients,
            "rotation_vector": rotation_vector,
            "translation_vector": translation_vector,
            "rotation_matrix": rotation_matrix,
            "pattern_size": self._pattern_size,
            "image": str(self.image),
        }
        json_file = self.image.parent / Path("position_calibration_data.json")
        logging.info(f"json_file: {json_file}")
        with open(json_file, "w") as outfile:
            outfile.write(json.dumps(calibration_data, indent=4, cls=NumpyArrayEncoder))
        return json_file


def main():
    camera_matrix = np.array(
        [
            [371.3541565418916, 0.0, 297.67039988882146],
            [0.0, 425.66620694975444, 213.39786917871035],
            [0.0, 0.0, 1.0],
        ]
    )

    distortion_coefficients = np.array(
        [
            [
                -0.369203046708034,
                0.14081738312315015,
                -0.0006183676435891658,
                -0.0009667343104861819,
                -0.024258248782296505,
            ]
        ]
    )
    p = PositionCalibration(
        image=Path(
            "/tmp/frameReceiver/snapshots/10_0_0_1/snapshot_20250326_102437.png"
        ),
        checkerboard_size=(12, 9),
        checkerboard_cell_edge_length_m=0.06,
        camera_matrix=camera_matrix,
        distortion_coefficients=distortion_coefficients,
    ).compute_camera_position(),
    print(p)

if __name__ == "__main__":
    main()
