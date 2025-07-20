# copy pasta https://docs.opencv2.org/4.x/d7/d53/tutorial_py_pose.html

import cv2
import glob
import json
import logging
import numpy as np
from pathlib import Path

def draw(img, corners, imgpts):
    corner = tuple(map(int, corners[0].ravel()))
    img = cv2.line(img=img, pt1=corner, pt2=tuple(map(int, imgpts[0].ravel())), color=(255,0,0), thickness=5)
    img = cv2.line(img=img, pt1=corner, pt2=tuple(map(int, imgpts[1].ravel())), color=(0,255,0), thickness=5)
    img = cv2.line(img=img, pt1=corner, pt2=tuple(map(int, imgpts[2].ravel())), color=(0,0,255), thickness=5)
    return img

def load(json_file):
    with open(json_file, "r") as f:
        json_load = json.load(f)
        mtx = np.asarray(json_load["camera_matrix"])
        dist = np.asarray(json_load["distortion_coefficients"])
        rvecs = np.asarray(json_load["rotation_vectors"])
        tvecs = np.asarray(json_load["translation_vectors"])
        pattern_size = json_load["pattern_size"]
        image_list = json_load["images"]
    return mtx, dist, rvecs, tvecs, pattern_size, image_list

def main():
    logging.basicConfig(level=logging.DEBUG)
    logging.debug(f"opencv version {cv2.__version__}")
    images = '../testscene/out/views/*.png'
    calibration_data = "../testscene/out/doc/calibration_data.json"
    preview_size = 640
    square_size_m = 0.12

    mtx, dist, _, _, pattern_size, image_list = load(calibration_data)

    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.001)
    objp = np.zeros((pattern_size[0]*pattern_size[1],3), np.float32)
    objp[:,:2] = np.mgrid[0:pattern_size[0],0:pattern_size[1]].T.reshape(-1,2)# TODO: *square_size_m

    axis = np.float32([[3,0,0], [0,3,0], [0,0,-3]]).reshape(-1,3)

    for fname in glob.glob(images):
        if Path(fname).name not in [Path(image).name for image in image_list]:
            logging.warning(f"image {fname} not in calibration data set")
            continue
        img = cv2.imread(fname)
        gray = cv2.cvtColor(img,cv2.COLOR_BGR2GRAY)
        ret, corners = cv2.findChessboardCorners(gray, pattern_size, None)
        
        if ret is True:
            corners2 = cv2.cornerSubPix(image=gray, corners=corners, winSize=(11,11), zeroZone=(-1,-1), criteria=criteria)
    
            # Find the rotation and translation vectors.
            ret, rvecs, tvecs = cv2.solvePnP(objp, corners2, mtx, dist)
    
            # project 3D points to image plane
            imgpts, jac = cv2.projectPoints(axis, rvecs, tvecs, mtx, dist)
    
            img = draw(img,corners2,imgpts)
            aspect_ratio = img.shape[0]/img.shape[1]
            #cv2.imshow('img', cv2.resize(img, (preview_size, int(preview_size*aspect_ratio))))
            cv2.imshow('img', img)
            cv2.imwrite(str(Path(fname).with_suffix('')) + '_overlay.png', img)
            print(str(Path(fname).with_suffix('')) + '_overlay.png')
            wait_for_ms = 1
            cv2.waitKey(wait_for_ms)
    
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
