# copy pasta https://docs.opencv2.org/4.x/d7/d53/tutorial_py_pose.html

import cv2
import glob
import json
import logging
import numpy as np
import matplotlib.pyplot as plt
import skimage
import skimage.transform.hough_transform as ht
from typing import NamedTuple

from pathlib import Path

# Blender
#
#      +z
#       |
# +x____|
#        \
#        +y
#
# OpenCV
#
#      -z              +y
#       |       +x___ /
# +x____|            |
#        \           |
#        -y          +z
#
# matplotlib
#
#      +z
#       |
# +x____|
#        \
#        +y

TO_CV = np.array([[1,0,0],[0,-1,0],[0,0,-1]])
TO_CV_HOM = np.array([[1,0,0,0],[0,-1,0,0],[0,0,-1,0],[0,0,0,1]])
FROM_CV = np.linalg.inv(TO_CV)
FROM_CV_HOM = np.linalg.inv(TO_CV_HOM)

def draw(img, corners, imgpts):
    corner = tuple(map(int, corners[0].ravel()))
    # color is BGR! fuck the guy who did this... 
    red = (0,0,255)
    green = (0,255,0)
    blue = (255,0,0)
    img = cv2.line(img=img, pt1=corner, pt2=tuple(map(int, imgpts[0].ravel())), color=red, thickness=5) # X
    img = cv2.line(img=img, pt1=corner, pt2=tuple(map(int, imgpts[1].ravel())), color=green, thickness=5) # Y
    img = cv2.line(img=img, pt1=corner, pt2=tuple(map(int, imgpts[2].ravel())), color=blue, thickness=5) # Z
    return img

def mouse_callback(event,x,y,flags, params):
    img, projection_matrix = params
    if event == cv2.EVENT_LBUTTONDOWN:
        px=x
        py=y
        Z=0 # TODO: why vector notation?
        X=np.linalg.inv(
            np.hstack((projection_matrix[:,0:2],np.array([[-1*px],[-1*py],[-1]])))
            ).dot((-Z*projection_matrix[:,2]-projection_matrix[:,3]))
        cv2.circle(img=img,center=(x,y),radius=2,color=(0, 255, 255,0),thickness=-1)
        cv2.putText(img=img, text=str(["{:.2f}".format(c) for c in X ]), org=(x+3,y-3), fontScale=1, fontFace= 1 , color=(255, 0, 255), thickness=2)


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


def cast_ray(intrinsic_matrix, rotation_matrix, translation_vector, pixel_coords):
    # Intrinsic matrix: K
    K = intrinsic_matrix
    
    # Extrinsic matrix: R and t
    R = rotation_matrix
    t = translation_vector.reshape(3, 1)
    
    # Pixel coordinates in homogeneous form
    u, v = pixel_coords
    pixel_homogeneous = np.array([u, v, 1.0])

    # Step 1: Convert pixel to camera coordinates
    p_c = np.linalg.inv(K) @ pixel_homogeneous  # Ray direction in camera space
    
    # Step 2: Transform ray direction to world coordinates
    p_w = R.T @ p_c  # Rotate to world coordinates
    
    # Step 3: Find camera origin in world coordinates
    o_w = -R.T @ t   # Camera origin in world coordinates
    
    # Return the ray in parametric form (origin and direction)
    return o_w.flatten(), p_w.flatten()

def undistort_point(pt, K, dist_coeffs):
    # Undistort to normalized coordinates
    pt = np.asarray(pt, dtype=np.float32).reshape(1, 1, 2)
    try:
        undistorted_norm = cv2.undistort_point(
            src=pt,
            cameraMatrix=K,
            distCoeffs=dist_coeffs,
        )
    except Exception as e:
        print(pt)
        print(K)
        print(dist_coeffs)
        raise e
    #  Convert back to pixel coordinates
    undistorted_pixel = cv2.convertPointsToHomogeneous(undistorted_norm)[:, 0, :]
    undistorted_pixel = (K @ undistorted_pixel.T).T
    undistorted_pixel = undistorted_pixel[:, :2] / undistorted_pixel[:, 2:]
    print(f"distorted: {pt}, undistorted: {undistorted_pixel}")
    return undistorted_pixel

def midpoint_triangulate(x, cam):
    # source: https://stackoverflow.com/questions/28779763/generalisation-of-the-mid-point-method-for-triangulation-to-n-points
    """
    Args:
        x:   Set of 2D points in homogeneous coords, (3 x n) matrix
        cam: Collection of n objects, each containing member variables
                 cam.P - 3x4 camera matrix
                 cam.R - 3x3 rotation matrix
                 cam.T - 3x1 translation matrix
    Returns:
        midpoint: 3D point in homogeneous coords, (4 x 1) matrix
    """
    n = len(cam)                                         # No. of cameras

    I = np.eye(3)                                        # 3x3 identity matrix
    A = np.zeros((3,n))
    B = np.zeros((3,n))
    sigma2 = np.zeros((3,1))

    for i in range(n):
        a = -np.transpose(cam[i].R).dot(cam[i].T)        # ith camera position
        A[:,i,None] = a

        b = np.linalg.pinv(cam[i].P).dot(x[:,i])              # Directional vector
        b = b / b[3]
        b = b[:3,None] - a
        b = b / np.linalg.norm(b)
        B[:,i,None] = b

        sigma2 = sigma2 + b.dot(b.T.dot(a))

    C = (n * I) - B.dot(B.T)
    Cinv = np.linalg.inv(C)
    sigma1 = np.sum(A, axis=1)[:,None]
    m1 = I + B.dot(np.transpose(B).dot(Cinv))
    m2 = Cinv.dot(sigma2)

    midpoint = (1/n) * m1.dot(sigma1) - m2        
    return np.vstack((midpoint, 1))

class Camera(NamedTuple):
    P: np.array
    R: np.array
    T: np.array

def main():
    plt.ion()
    plt.show(block=False)
    marker_position_blender = (0.12, 0.8, 1.5)
    logging.basicConfig(level=logging.INFO)
    logging.debug(f"opencv version {cv2.__version__}")
    images = '../testscene/out/views/*.png'
    calibration_data = "../testscene/out/doc/calibration_data.json"
    square_size_m = 0.12
    mtx, dist, _, _, pattern_size, image_list = load(calibration_data)

    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.001)
    objp = np.zeros((pattern_size[0]*pattern_size[1],3), np.float32)
    objp[:,:2] = np.mgrid[0:pattern_size[0],0:pattern_size[1]].T.reshape(-1,2)*square_size_m

    axis = np.float32([[1,0,0], [0,1,0], [0,0,1]]).reshape(-1,3) * TO_CV
    rays = []
    cameras = []
    points = np.empty((3,0))
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
            ret, rotation_vector, translation_vector = cv2.solvePnP(objp, corners2, mtx, dist)
            # https://stackoverflow.com/questions/14444433/calculate-camera-world-position-with-opencv-python
            rotation_matrix = cv2.Rodrigues(rotation_vector)[0]
            # rotation_matrix: R in https://en.wikipedia.org/wiki/Camera_resectioning
            # translation_vector: T in https://en.wikipedia.org/wiki/Camera_resectioning
            logging.info(f"rotation_matrix:\n{rotation_matrix}\n---")
            logging.info(f"translation_vector:\n{translation_vector}\n---")

            # extrinsic_matrix: K in https://en.wikipedia.org/wiki/Camera_resectioning
            extrinsic_matrix = np.vstack((np.hstack((rotation_matrix, translation_vector)) ,np.array([[0,0,0,1]])))
            logging.info(f"extrinsic_matrix:\n{extrinsic_matrix}\n---")
            
            # camera_position_world: C in https://en.wikipedia.org/wiki/Camera_resectioning
            #camera_position_world = -np.array(rotation_matrix).T @ np.array(translation_vector)
            extrinsic_matrix_inverse = np.linalg.inv(extrinsic_matrix)
            camera_position_world_hom = extrinsic_matrix_inverse @ np.array([[0,0,0,1]]).T # mimikry (5.4)
            camera_position_world = camera_position_world_hom[:-1,:]
            logging.info(f"camera_position_world_hom:\n{camera_position_world_hom}\n---")
            logging.info(f"camera_position_world:\n{camera_position_world}\n---")

            # FIXME: both camera_postition[1] and camera_postition[2] are wrong, * -1
            #camera_position_world[1] = camera_position_world[1] * -1
            #camera_position_world[2] = camera_position_world[2] * -1

            # 1. place chess board on floor, this will be world origin?
            # 2. get rvec and tvec by solving PnP
            # 3. compute and store Projection matrix
            # 4. place object on floor, projection matrix can be applied at origin of object (2D image coord) to get world coords (where the object is in real world)
            plt.close('all')

            params = cv2.SimpleBlobDetector.Params()
            params.filterByCircularity = True
            params.minCircularity = 0.8
            detector = cv2.SimpleBlobDetector.create(parameters=params)
            img_marker_layer = img[:,:,0] - img[:,:,1] - img[:,:,2]
            cv2.imshow("img_marker_layer", cv2.resize(img_marker_layer, (960, 540)))
            keypoints = detector.detect(img_marker_layer)
            im_with_keypoints = cv2.drawKeypoints(img_marker_layer, keypoints, np.array([]), (0,0,255), cv2.DRAW_MATCHES_FLAGS_DRAW_RICH_KEYPOINTS)
            # Show keypoints
            cv2.imshow("Keypoints", im_with_keypoints)

            if len(keypoints) == 0:
                marker_principal_point = None
                logging.warning(f"no marker found")
            else:
                if len(keypoints) != 1:
                    logging.warning(f"more than one marker found")
                marker_principal_point = (keypoints[0].pt[0], keypoints[0].pt[1], 1) # z = 1 -> Why 1? Do I need to use the instrinsic matrix in some way to get from image plane to camera reference frame?
            logging.info(f"marker position: {marker_principal_point}")

            fig = plt.figure()
            ax = fig.add_subplot(projection='3d')

            # chessboard
            board_coordinates_blender = np.array([0.6, -0.42, 0])
            board_size = (1.56, 1.2)
            board_offset_to_center = (-board_size[0]/2,-board_size[1]/2)
            board_xy = np.meshgrid([0+board_offset_to_center[0]+board_coordinates_blender[0], board_size[0]+board_offset_to_center[0]+board_coordinates_blender[0]], [0+board_offset_to_center[1]+board_coordinates_blender[1], board_size[1]+board_offset_to_center[1]+board_coordinates_blender[1]])
            board_z = np.array([[board_coordinates_blender[2],board_coordinates_blender[2]], [board_coordinates_blender[2],board_coordinates_blender[2]]])
            board_xyz= np.array([board_xy[0],board_xy[1],board_z])
            ax.plot_surface(board_xyz[0], board_xyz[1], board_xyz[2],  alpha=0.5)

            # camera position
            camera_position_matplotlib = FROM_CV @ camera_position_world 
            ax.scatter(camera_position_matplotlib[0], camera_position_matplotlib[1], camera_position_matplotlib[2], marker='x')

            # camera direction
            # TODO: draw fov indicator
            # rays from camera to marker
            if marker_principal_point is not None:
                camera_matrix = mtx @ np.hstack((rotation_matrix, translation_vector))
                cameras.append(Camera(P=camera_matrix, R=rotation_matrix, T=translation_vector))
                points = np.hstack((points,np.array([marker_principal_point]).T))
                cv2.circle(img=img,center=(int(marker_principal_point[0]),int(marker_principal_point[1])),radius=3,color=(0, 255, 255,0),thickness=-1)
                origin, direction = cast_ray(intrinsic_matrix=mtx, rotation_matrix=rotation_matrix, translation_vector=translation_vector, pixel_coords=(marker_principal_point[0],marker_principal_point[1]))
                origin = FROM_CV @ np.array([origin]).T
                direction = FROM_CV @ np.array([direction]).T
                logging.info(f"ray at {origin} pointing to {direction}")
                rays.append((origin, direction))
                ax.quiver(origin[0], origin[1], origin[2], direction[0], direction[1], direction[2], length=10, colors='b', arrow_length_ratio=0.1)

            # marker truth
            ax.scatter(marker_position_blender[0], marker_position_blender[1], marker_position_blender[2], marker='o', color='r')

            # origin
            ax.quiver(0,0,0,1,0,0, length=0.3, colors='r')
            ax.quiver(0,0,0,0,1,0, length=0.3, colors='g')
            ax.quiver(0,0,0,0,0,1, length=0.3, colors='b')
    
            ax.set_xlabel('X / m')
            ax.set_ylabel('Y / m')
            ax.set_zlabel('Z / m')
            ax.set_xlim((-6,6))
            ax.set_ylim((-6,6))
            ax.set_zlim((-6,6))
            plt.pause(0.001)
            plt.draw()
            plt.pause(0.001)

            # project 3D points to image plane
            imgpts, jac = cv2.projectPoints(axis, rotation_vector, translation_vector, mtx, dist)
            img = draw(img,corners2,imgpts)
                        
            cv2.namedWindow('img')
            #cv2.setMouseCallback('img', mouse_callback, param=(img, projection_matrix))
           
            cv2.imwrite(str(Path(fname).with_suffix('')) + '_overlay.png', img)
            cv2.imshow('img', img)
            k = cv2.waitKey(20) & 0xFF

#            while(1):
#                cv2.imshow('img', img)
#                k = cv2.waitKey(20) & 0xFF
#                if k == 27:
#                    break
#                elif k == ord('n'):
#                    break

    #TODO: with all rays -> marker_position_estimate_world   
    fig = plt.figure()
    ax = fig.add_subplot(projection='3d')

    for ray in rays:
        origin, direction = ray
        ax.quiver(origin[0], origin[1], origin[2], direction[0], direction[1], direction[2], length=100, colors='b', arrow_length_ratio=0.01)
        plt.draw()
    # marker truth
    ax.scatter(marker_position_blender[0], marker_position_blender[1], marker_position_blender[2], marker='o', color='r')
    # origin
    ax.quiver(0,0,0,1,0,0, length=0.3, colors='r')
    ax.quiver(0,0,0,0,1,0, length=0.3, colors='g')
    ax.quiver(0,0,0,0,0,1, length=0.3, colors='b')
    ax.set_xlabel('X / m')
    ax.set_ylabel('Y / m')
    ax.set_zlabel('Z / m')
    ax.set_xlim((-3,3))
    ax.set_ylim((-3,3))
    ax.set_zlim((0,6))

    marker_position_triangulated_hom = midpoint_triangulate(points,cameras)
    marker_position_triangulated_hom = FROM_CV_HOM @ marker_position_triangulated_hom
    marker_position_triangulated = marker_position_triangulated_hom[:-1,:]

    logging.warning(f"Marker ground truth:\n{marker_position_blender}")
    logging.warning(f"Marker triangulated:\n{marker_position_triangulated}")
    logging.warning(f"Error: {np.linalg.norm(marker_position_triangulated.T-marker_position_blender)}")

    ax.scatter(marker_position_triangulated[0][0], marker_position_triangulated[1][0], marker_position_triangulated[2][0], marker='o', color='y')


    while(1):
        plt.pause(0.001)
        k = cv2.waitKey(20) & 0xFF
        if k == 27:
            break
        elif k == ord('n'):
            break
    
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
