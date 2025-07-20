# FPGA-based low-cost motion capture
Infrared-based motion capture.
Image processing is done the [GECKO5Education](https://github.com/logisim-evolution/GECKO5Education), an educational FPGA platform.
I created this system as part of masters degree in electrical engineering at Bern University of Applied Sciences (BFH).

> [!NOTE]
> Solving marker correspondence using epipolar geometry is not yet implemented.
> As a result, the Python software is currently only able to track a single marker.

# Blob Detector
Marker detection unit hosting FGPA, microcontroller, IR camera, IR LEDs and PoE module.
<p float="left">
  <img src="doc/blobDetectorFront.png" height="400px" />
  <img src="doc/blobDetectorBack.png"  height="400px" />
</p>

# Demo
The system tracking a reflective marker.
![demo](doc/mocap.gif)
[demo video](https://youtu.be/6Va6dF9vp88)

# Mechanical design
[onshape project](https://cad.onshape.com/documents/1d5331a2d4403797078fc34d/w/9683c0b739c4abd1173768d9/e/775ed87ad6031a9883c39a66?renderMode=0&uiState=687d36ef6178f96628e9789b)

# Documentation
`doc/Low-Cost_Motion_Capture.pdf`
