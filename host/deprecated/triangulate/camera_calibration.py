# copy pasta https://docs.opencv.org/4.x/dc/dbb/tutorial_py_calibration.html
import cv2
import glob
import json
import numpy as np
from pathlib import Path
 
print("TODO:\n" \
      + "   - scale of squares\n" \
      + "   - plot checker board corners on undistored image using camera matrix." \
      + " The same transformation will be done to the detected IR markers. See https://docs.opencv.org/4.x/d7/d53/tutorial_py_pose.html\n" \
    )

# https://pynative.com/python-serialize-numpy-ndarray-into-json/
# https://stackoverflow.com/questions/26646362/numpy-array-is-not-json-serializable
# https://github.com/mpld3/mpld3/issues/434#issuecomment-340255689
class NumpyArrayEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, np.integer):
            return int(obj)
        elif isinstance(obj, np.floating):
            return float(obj)
        elif isinstance(obj, np.ndarray):
            return obj.tolist()
        else:
            return super(NumpyArrayEncoder, self).default(obj)

def main():
    # termination criteria
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.001)
    wait_for_ms = 1
    preview_size = 640

    images, pattern_size, square_size_m = (glob.glob('../testscene/out/views/views*.png'), (11,8), 0.12)

    output_folder = Path('../testscene/out/doc/')
    output_folder_distorted = output_folder / Path('distorted')
    output_folder_distorted_cropped = output_folder / Path('distorted_cropped')
    output_folder_distorted.mkdir(parents=True, exist_ok=True)
    output_folder_distorted_cropped.mkdir(parents=True, exist_ok=True)

    # prepare object points, like (0,0,0), (1,0,0), (2,0,0) ....,(6,5,0)
    objp = np.zeros((pattern_size[0]*pattern_size[1],3), np.float32)
    objp[:,:2] = np.mgrid[0:pattern_size[0],0:pattern_size[1]].T.reshape(-1,2)*square_size_m

    # Arrays to store object points and image points from all the images.
    objpoints = [] # 3d point in real world space
    imgpoints = [] # 2d points in image plane.

    assert len(images) > 0, "no images found"
    print(images)

    for fname in images:
        img = cv2.imread(fname)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        # Find the chess board corners
        ret, corners = cv2.findChessboardCorners(gray, pattern_size, None)
        if not ret:
            print("no corners found")
        # If found, add object points, image points (after refining them)
        if ret is True:
            objpoints.append(objp)

            # sub-pixel accurate location of corners, see https://theailearner.com/tag/cv2-cornersubpix/
            corners2 = cv2.cornerSubPix(image=gray, corners=corners, winSize=(11,11), zeroZone=(-1,-1), criteria=criteria)

            imgpoints.append(corners2)

            # Draw and display the corners
            cv2.drawChessboardCorners(image=img, patternSize=(pattern_size[0],pattern_size[1]), corners=corners2, patternWasFound=ret)
            aspect_ratio = img.shape[0]/img.shape[1]
            cv2.imshow('img', cv2.resize(img, (preview_size, int(preview_size*aspect_ratio))))
            cv2.waitKey(wait_for_ms)

    cv2.destroyAllWindows()
    print(f"calibration base on {len(objpoints)} of {len(images)} images")

    # returns the camera matrix, distortion coefficients, rotation and translation vectors
    ret, mtx, dist, rvecs, tvecs = cv2.calibrateCamera(objectPoints=objpoints, imagePoints=imgpoints, imageSize=gray.shape[::-1], cameraMatrix=None, distCoeffs=None)
    print(f"Camera Matrix:\n{mtx}")

    h,  w = img.shape[:2]
    # different alpha different OptimalNewCameraMatrix
    # alpha=0, it returns undistorted image with minimum unwanted pixels.
    # So it may even remove some pixels at image corners. 
    # alpha=1, all pixels are retained with some extra black images.
    alpha = 1
    newcameramtx, roi = cv2.getOptimalNewCameraMatrix(cameraMatrix=mtx, distCoeffs=dist, imageSize=(w,h), alpha=alpha, newImgSize=(w,h))
    print(f"Optimal New Camera Matrix:\n{newcameramtx}")

    for fname in images:
        # undistort
        img = cv2.imread(fname)
        dst = cv2.undistort(img, mtx, dist, None, newcameramtx)

        # crop the image
        x, y, w, h = roi
        dst_cropped = dst[y:y+h, x:x+w]
        file_path_out_distorted = output_folder_distorted / Path(fname).name
        print(file_path_out_distorted)
        cv2.imwrite(str(file_path_out_distorted), dst)
        try:
            file_path_out_distorted_cropped = output_folder_distorted_cropped / Path(fname).name
            cv2.imwrite(str(file_path_out_distorted_cropped), dst_cropped)
        except cv2.error:
            print("cropped image is empty")

        
    total_error = 0
    for i in range(len(objpoints)):
        # Projects 3D points to an image plane.
        imgpoints2, _ = cv2.projectPoints(objpoints[i], rvecs[i], tvecs[i], mtx, dist)
        error = cv2.norm(imgpoints[i], imgpoints2, cv2.NORM_L2)/len(imgpoints2)
        total_error += error
    mean_error = total_error/len(objpoints)
    print(f"total error: {total_error}")
    print(f"mean error: {mean_error}")

    calib_data = {
        "camera_matrix": mtx, # camera matrix
        "distortion_coefficients": dist, # distortion coefficients
        "rotation_vectors": rvecs, # rotation vectors
        "translation_vectors": tvecs, # translation vectors
        "total_error": total_error,
        "mean_error": mean_error,
        "pattern_size": pattern_size,
        "images": images
    }

    with open(output_folder / Path("calibration_data.json"), "w") as outfile:
        outfile.write(json.dumps(calib_data, indent=4, cls=NumpyArrayEncoder))

if __name__ == "__main__":
    main()
