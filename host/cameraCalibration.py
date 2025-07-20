import glob
import json
import logging
from pathlib import Path
from typing import Tuple, List

import cv2
import numpy as np
from numpyArrayEncoder import NumpyArrayEncoder
from typing import Optional


class CameraCalibration:
    def __init__(
        self,
        images_dir: Path,
        checkerboard_size: tuple[int, int],
        checkerboard_cell_edge_length_m: float,
    ):
        """create an instance of CameraCalibration
        Args:
            images (Path): The path to the directory containing the calibration images.
            checkerboard_size (tuple[int, int]): The dimensions of the checkerboard pattern used for calibration, specified as (rows, columns).
            checkerboard_cell_edge_length_m (float): The length of one side of a checkerboard cell
            in meters.
        """
        self._logger = logging.getLogger("CameraCalibration")
        self._logger.setLevel(logging.INFO)
        self.images_dir = images_dir
        self.checkerboard_size = checkerboard_size
        self.checkerboard_cell_edge_length_m = checkerboard_cell_edge_length_m
        self._logger.debug("instance created")

    @property
    def images_dir(self) -> Path:
        return self._images_dir

    @images_dir.setter
    def images_dir(self, value: Path):
        self._images_dir = value
        self._reload_images()

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

    def _reload_images(self):
        self._images = glob.glob(str(self._images_dir) + "/*.png")

    def compute_camera_matrix(
        self, show_overlay: bool = True
    ) -> Optional[Path]:
        """Perform camera calibration
        Args:
            show_overlay (bool): If True, displays the checkerboard overlay on the images during processing.
        Returns:
            Path: The path to the JSON file containing the calibration data.
        """
        if len(self._images) <= 0:
            self._logger.warning(f"no images found in {self._images_dir}")
            return None
        # termination criteria
        criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.001)
        # prepare object points, like (0,0,0), (1,0,0), (2,0,0) ....,(6,5,0)
        objp = np.zeros((self._pattern_size[0] * self._pattern_size[1], 3), np.float32)
        objp[:, :2] = (
            np.mgrid[0 : self._pattern_size[0], 0 : self._pattern_size[1]].T.reshape(
                -1, 2
            )
            * self._cell_edge_length_m
        )

        # Arrays to store object points and image points from all the images.
        objpoints = []  # 3d point in real world space
        imgpoints = []  # 2d points in image plane.

        for fname in self._images:
            self._logger.debug(f"processing image: {fname}")
            img = cv2.imread(fname)
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            # Find the chess board corners
            ret, corners = cv2.findChessboardCorners(gray, self._pattern_size, None)
            if not ret:
                self._logger.warning(f"no corners found in {fname}")

            # If found, add object points, image points (after refining them)
            if ret is True:
                objpoints.append(objp)

                # sub-pixel accurate location of corners, see https://theailearner.com/tag/cv2-cornersubpix/
                corners2 = cv2.cornerSubPix(
                    image=gray,
                    corners=corners,
                    winSize=(11, 11),
                    zeroZone=(-1, -1),
                    criteria=criteria,
                )

                imgpoints.append(corners2)

                if show_overlay:
                    # Draw and display the corners
                    cv2.drawChessboardCorners(
                        image=img,
                        patternSize=(self._pattern_size[0], self._pattern_size[1]),
                        corners=corners2,
                        patternWasFound=ret,
                    )
                    cv2.imshow("img", img)
                    cv2.waitKey(200)

        cv2.destroyAllWindows()
        # returns the camera matrix, distortion coefficients, rotation and translation vectors
        ret, mtx, dist, rvecs, tvecs = cv2.calibrateCamera(
            objectPoints=objpoints,
            imagePoints=imgpoints,
            imageSize=gray.shape[::-1],
            cameraMatrix=None,
            distCoeffs=None,
        )
        self._logger.info(f"Camera Matrix:\n{mtx}")
        h, w = img.shape[:2]
        # different alpha different OptimalNewCameraMatrix
        # alpha=0, it returns undistorted image with minimum unwanted pixels.
        # So it may even remove some pixels at image corners.
        # alpha=1, all pixels are retained with some extra black images.
        alpha = 1
        newcameramtx, roi = cv2.getOptimalNewCameraMatrix(
            cameraMatrix=mtx,
            distCoeffs=dist,
            imageSize=(w, h),
            alpha=alpha,
            newImgSize=(w, h),
        )
        self._logger.info(f"Optimal New Camera Matrix:\n{newcameramtx}")

        dir_undistorted = self._images_dir / Path("undistorted")
        dir_undistorted.mkdir(parents=True, exist_ok=True)
        dir_cropped = self._images_dir / Path("cropped")
        dir_cropped.mkdir(parents=True, exist_ok=True)

        for fname in self._images:
            # undistort
            img = cv2.imread(fname)
            dst = cv2.undistort(img, mtx, dist, None, newcameramtx)

            # crop the image
            x, y, w, h = roi
            dst_cropped = dst[y : y + h, x : x + w]

            cv2.imwrite(str(dir_undistorted / Path(fname).name), dst)
            try:
                cv2.imwrite(str(dir_cropped / Path(fname).name), dst_cropped)
            except cv2.error:
                self._logger.warning("cropped image is empty")

        reprojection_error: List[float] = []
        total_error = 0.0
        for i in range(len(objpoints)):
            # Projects 3D points to an image plane.
            imgpoints2, _ = cv2.projectPoints(
                objpoints[i], rvecs[i], tvecs[i], mtx, dist
            )
            error = cv2.norm(imgpoints[i], imgpoints2, cv2.NORM_L2) / len(imgpoints2)
            reprojection_error.append(error)
            total_error += error
        mean_reprojection_error = total_error / len(objpoints)
        self._logger.info(f"reprojection error: {reprojection_error}")
        self._logger.info(f"mean reprojection error: {mean_reprojection_error}") # TODO: add to gui (unit is pixel)

        calibration_data = {
            "camera_matrix": mtx,  # camera matrix
            "distortion_coefficients": dist,  # distortion coefficients
            "rotation_vectors": rvecs,  # rotation vectors
            "translation_vectors": tvecs,  # translation vectors
            "reprojection_error": reprojection_error,
            "mean_reprojection_error": mean_reprojection_error,
            "pattern_size": self._pattern_size,
            "images": self._images,
        }
        json_file = self.images_dir / Path("camera_calibration_data.json")
        with open(json_file, "w") as outfile:
            outfile.write(json.dumps(calibration_data, indent=4, cls=NumpyArrayEncoder))
        return json_file
