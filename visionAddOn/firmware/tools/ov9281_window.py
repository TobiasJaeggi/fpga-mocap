import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import typing
# Sensor
IMAGE_ARRAY_FULL = (1296, 816)
IMAGE_ARRAY_USABLE = (1280, 800)

# user config
ISP_START: typing.Tuple[int, int] = (0, 0)
ISP_END: typing.Tuple[int, int] = (IMAGE_ARRAY_FULL[0] - 1, IMAGE_ARRAY_FULL[1] - 1)
DATA_OUTPUT: typing.Tuple[int,int] = (640, 480)
DATA_OFFSET: typing.Tuple[int,int] = (int((ISP_END[0] - ISP_START[0]) / 2), int((ISP_END[1] - ISP_START[1]) / 2))
#"Array horizontal and vertical start point" 0x0
TIMING_X_ADDR_START_HB_DEFAULT: int = 0x00  # 0x3800
TIMING_X_ADDR_START_LB_DEFAULT: int = 0x00  # 0x3801
TIMING_Y_ADDR_START_HB_DEFAULT: int = 0x00  # 0x3802
TIMING_Y_ADDR_START_LB_DEFAULT: int = 0x00  # 0x3803
#"Array horizontal and vertical end point" 1295x815
TIMING_X_ADDR_END_HB_DEFAULT: int = 0x05  # 0x3804
TIMING_X_ADDR_END_LB_DEFAULT: int = 0x0F  # 0x3805
TIMING_Y_ADDR_END_HB_DEFAULT: int = 0x03  # 0x3806
TIMING_Y_ADDR_END_LB_DEFAULT: int = 0x2F  # 0x3807
#"ISP output width and height" 2400x800
TIMING_X_OUTPUT_SIZE_HB_DEFAULT: int = 0x05  # 0x3808
TIMING_X_OUTPUT_SIZE_LB_DEFAULT: int = 0x00  # 0x3809
TIMING_Y_OUTPUT_SIZE_HB_DEFAULT: int = 0x03  # 0x380A
TIMING_Y_OUTPUT_SIZE_LB_DEFAULT: int = 0x20  # 0x380B
#"Total horizontal and vertical timing size "728x910 <- ??must be increased to to work for DVP??
TIMING_HTS_HB_DEFAULT: int = 0x02  # 0x380C
TIMING_HTS_LB_DEFAULT: int = 0xD8  # 0x380D
TIMING_VTS_HB_DEFAULT: int = 0x03  # 0x380E
TIMING_VTS_LB_DEFAULT: int = 0x8E  # 0x380F
#"ISP horizontal and vertical window offset" 8x8
TIMING_ISP_X_WIN_HB_DEFAULT: int = 0x00  # 0x3810
TIMING_ISP_X_WIN_LB_DEFAULT: int = 0x08  # 0x3811
TIMING_ISP_Y_WIN_HB_DEFAULT: int = 0x00  # 0x3812
TIMING_ISP_Y_WIN_LB_DEFAULT: int = 0x08  # 0x3813
#TIMING_X_INC_DEFAULT: int = 0x11  # 0x3814
#TIMING_Y_INC_DEFAULT: int = 0x11  # 0x3815

TIMING_X_ADDR_START_HB: int = TIMING_X_ADDR_START_HB_DEFAULT # (0xFF00 & ISP_START[0]) >> 8 # 0x3800
TIMING_X_ADDR_START_LB: int = TIMING_X_ADDR_START_LB_DEFAULT # (0x00FF & ISP_START[0]) >> 0 # 0x3801
TIMING_Y_ADDR_START_HB: int = TIMING_Y_ADDR_START_HB_DEFAULT # (0xFF00 & ISP_START[1]) >> 8 # 0x3802
TIMING_Y_ADDR_START_LB: int = TIMING_Y_ADDR_START_LB_DEFAULT # (0x00FF & ISP_START[1]) >> 0 # 0x3803
TIMING_X_ADDR_END_HB: int = TIMING_X_ADDR_END_HB_DEFAULT # (0xFF00 & ISP_END[0]) >> 8 # 0x3804
TIMING_X_ADDR_END_LB: int = TIMING_X_ADDR_END_LB_DEFAULT # (0x00FF & ISP_END[0]) >> 0 # 0x3805
TIMING_Y_ADDR_END_HB: int = TIMING_Y_ADDR_END_HB_DEFAULT # (0xFF00 & ISP_END[1]) >> 8 # 0x3806
TIMING_Y_ADDR_END_LB: int = TIMING_Y_ADDR_END_LB_DEFAULT # (0x00FF & ISP_END[1]) >> 0 # 0x3807
TIMING_X_OUTPUT_SIZE_HB: int = TIMING_X_OUTPUT_SIZE_HB_DEFAULT # (0xFF00 & DATA_OUTPUT[0]) >> 8 # 0x3808
TIMING_X_OUTPUT_SIZE_LB: int = TIMING_X_OUTPUT_SIZE_LB_DEFAULT # (0x00FF & DATA_OUTPUT[0]) >> 0 # 0x3809
TIMING_Y_OUTPUT_SIZE_HB: int = TIMING_Y_OUTPUT_SIZE_HB_DEFAULT # (0xFF00 & DATA_OUTPUT[1]) >> 8 # 0x380A
TIMING_Y_OUTPUT_SIZE_LB: int = TIMING_Y_OUTPUT_SIZE_LB_DEFAULT # (0x00FF & DATA_OUTPUT[1]) >> 0  # 0x380B
TIMING_HTS_HB: int = TIMING_HTS_HB_DEFAULT  # 0x380C
TIMING_HTS_LB: int = TIMING_HTS_LB_DEFAULT  # 0x380D
TIMING_VTS_HB: int = TIMING_VTS_HB_DEFAULT  # 0x380E
TIMING_VTS_LB: int = TIMING_VTS_LB_DEFAULT  # 0x380F
TIMING_ISP_X_WIN_HB: int = TIMING_ISP_X_WIN_HB_DEFAULT # (0xFF00 & DATA_OFFSET[0]) >> 8 # 0x3810
TIMING_ISP_X_WIN_LB: int = TIMING_ISP_X_WIN_LB_DEFAULT # (0x00FF & DATA_OFFSET[0]) >> 0 # 0x3811
TIMING_ISP_Y_WIN_HB: int = TIMING_ISP_Y_WIN_HB_DEFAULT # (0xFF00 & DATA_OFFSET[1]) >> 8 # 0x3812
TIMING_ISP_Y_WIN_LB: int = TIMING_ISP_Y_WIN_LB_DEFAULT # (0x00FF & DATA_OFFSET[1]) >> 0 # 0x3813
# TIMING_X_INC: int = TIMING_X_INC_DEFAULT # 0x3814
# TIMING_Y_INC: int = TIMING_Y_INC_DEFAULT # 0x3815
# 0x3816-0x381F DEBUG CTRL
# TODO: there is more!

# data input
# NOTE: OV9281 manual states that only the 2 lsb of upper bytes are used, but default value is larger so we just take the whole byte instead
horizontal_start = ((0xFF & TIMING_X_ADDR_START_HB) << 8) + (0xFF & TIMING_X_ADDR_START_LB)
vertical_start = ((0xFF & TIMING_Y_ADDR_START_HB) << 8) + (0xFF & TIMING_Y_ADDR_START_LB)
horizontal_end = ((0xFF & TIMING_X_ADDR_END_HB) << 8) + (0xFF & TIMING_X_ADDR_END_LB)
vertical_end = ((0xFF & TIMING_Y_ADDR_END_HB) << 8) + (0xFF & TIMING_Y_ADDR_END_LB)

print(f"horizontal_start {horizontal_start}")
print(f"vertical_start {vertical_start}")
print(f"horizontal_end {horizontal_end}")
print(f"vertical_end {vertical_end}")

# windowing offset (data output offset)
isp_horizontal_windowing_offset = ((0xFF & TIMING_ISP_X_WIN_HB) << 8) + (
    0xFF & TIMING_ISP_X_WIN_LB
)
isp_vertical_windowing_offset = ((0xFF & TIMING_ISP_Y_WIN_HB) << 8) + (
    0xFF & TIMING_ISP_Y_WIN_LB
)
print(f"isp_horizontal_windowing_offset {isp_horizontal_windowing_offset}")
print(f"isp_vertical_windowing_offset {isp_vertical_windowing_offset}")

# windowing size (data output size)
isp_horizontal_output_width = ((0xFF & TIMING_X_OUTPUT_SIZE_HB) << 8) + (
    0xFF & TIMING_X_OUTPUT_SIZE_LB
)
isp_vertical_output_width = ((0xFF & TIMING_Y_OUTPUT_SIZE_HB) << 8) + (
    0xFF & TIMING_Y_OUTPUT_SIZE_LB
)
print(f"isp_horizontal_output_width {isp_horizontal_output_width}")
print(f"isp_vertical_output_width {isp_vertical_output_width}")


# ??? -> blanking time = image_time - total?
total_horizontal_size = ((0xFF & TIMING_HTS_HB) << 8) + (0xFF & TIMING_HTS_LB)
total_vertical_size = ((0xFF & TIMING_VTS_HB) << 8) + (0xFF & TIMING_VTS_LB)
print(f"total_horizontal_size {total_horizontal_size}")
print(f"total_vertical_size {total_vertical_size}")

image_array_usable_origin = (
    (IMAGE_ARRAY_FULL[0] - IMAGE_ARRAY_USABLE[0]) / 2,
    (IMAGE_ARRAY_FULL[1] - IMAGE_ARRAY_USABLE[1]) / 2,
)

fig, ax = plt.subplots()
ax.plot()

rect_image_array_full = Rectangle(
    xy=(0, 0),
    width=IMAGE_ARRAY_FULL[0] - 1,
    height=IMAGE_ARRAY_FULL[1] - 1,
    fill=False,
    edgecolor="black",
)
rect_image_array_usable = Rectangle(
    xy=image_array_usable_origin,
    width=IMAGE_ARRAY_USABLE[0],
    height=IMAGE_ARRAY_USABLE[1],
    fill=False,
    edgecolor="orange",
)
isp_input_origin = (
    horizontal_start,
    vertical_start,
)
rect_isp_input = Rectangle(
    xy=isp_input_origin,
    width=horizontal_end - horizontal_start,
    height=vertical_end - vertical_start,
    fill=False,
    edgecolor="green",
)

data_output_origin = (
    isp_input_origin[0] + isp_horizontal_windowing_offset,
    isp_input_origin[1] + isp_vertical_windowing_offset,
)
rect_data_output = Rectangle(
    xy=data_output_origin,
    width=isp_horizontal_output_width,
    height=isp_vertical_output_width,
    fill=False,
    edgecolor="red",
)

ax.add_patch(rect_image_array_full)
ax.add_patch(rect_image_array_usable)
ax.add_patch(rect_isp_input)
ax.add_patch(rect_data_output)

ax.legend(
    [rect_image_array_full, rect_image_array_usable, rect_isp_input, rect_data_output],
    ["image array full", "image array usable", "ISP input", "data output"],
)

plt.show()
exit()
# {0x3800[9:8], 0x3801[7:0]}
# 0x00 0x00

# {0x3802[9:8], 0x3803[7:0]}
# 0x00 0x00

# {0x3804[9:8], 0x3805[7:0]}
# 0x05 0x0F
# 0b0000_0101 0b0000_1111
# 0b01_0000_1111 -> 0d271

# {0x3806[9:8], 0x3807[7:0]}
# 0x03 0x2F
# 0b0000_0011 0b0010_1111
# 0b11_0010_1111 -> 0d815


# DVP control registers

VSYNC_RISE_LNT_HB_DEFAULT: int = 0x00  # 0x4702
VSYNC_RISE_LNT_LB_DEFAULT: int = 0x02  # 0x4703
VSYNC_FALL_LNT_HB_DEFAULT: int = 0x00  # 0x4704
VSYNC_FALL_LNT_LB_DEFAULT: int = 0x06  # 0x4705
VSYNC_CHG_PCNT_HB_DEFAULT: int = 0x00  # 0x4706
VSYNC_CHG_PCNT_LB_DEFAULT: int = 0x10  # 0x4707
VSYNC_RISE_LNT_HB: int = VSYNC_RISE_LNT_HB_DEFAULT  # 0x4702
VSYNC_RISE_LNT_LB: int = VSYNC_RISE_LNT_LB_DEFAULT  # 0x4703
VSYNC_FALL_LNT_HB: int = VSYNC_FALL_LNT_HB_DEFAULT  # 0x4704
VSYNC_FALL_LNT_LB: int = VSYNC_FALL_LNT_LB_DEFAULT  # 0x4705
VSYNC_CHG_PCNT_HB: int = VSYNC_CHG_PCNT_HB_DEFAULT  # 0x4706
VSYNC_CHG_PCNT_LB: int = VSYNC_CHG_PCNT_LB_DEFAULT  # 0x4707

vsync_rise_lnt: int = ((0xFF & VSYNC_RISE_LNT_HB) << 8) + (0xFF & VSYNC_RISE_LNT_LB)
vsync_fall_lnt: int = ((0xFF & VSYNC_FALL_LNT_HB) << 8) + (0xFF & VSYNC_FALL_LNT_LB)
vsync_chg_pcnt: int = ((0xFF & VSYNC_CHG_PCNT_HB) << 8) + (0xFF & VSYNC_CHG_PCNT_LB)

print(f"vsync_rise_lnt {vsync_rise_lnt}")
print(f"vsync_fall_lnt {vsync_fall_lnt}")
print(f"vsync_chg_pcnt {vsync_chg_pcnt}")


print("---")

print("1280x800")
print(
    f"timing x end {((0x3 & 0x05) << 8) + (0xFF & 0x0F)}"
)  # {0x3804[9:8], 0x3805[7:0]}
print(
    f"timing y end {((0x3 & 0x03) << 8) + (0xFF & 0x2F)}"
)  # {0x3806[9:8], 0x3807[7:0]}

print("1280x720")
print(
    f"timing x end {((0x3 & 0x05) << 8) + (0xFF & 0x0F)}"
)  # {0x3804[9:8], 0x3805[7:0]}
print(
    f"timing y end {((0x3 & 0x02) << 8) + (0xFF & 0xDF)}"
)  # {0x3806[9:8], 0x3807[7:0]}

print("640x400")
print(
    f"timing x end {((0x3 & 0x05) << 8) + (0xFF & 0x0F)}"
)  # {0x3804[9:8], 0x3805[7:0]}
print(
    f"timing y end {((0x3 & 0x03) << 8) + (0xFF & 0x2F)}"
)  # {0x3806[9:8], 0x3807[7:0]}


print(f"horizontal timing size {((0x02) << 8) + (0xD8)}")  # {0x380C[15:8], 0x380D[7:0]}
print(f"vertical timing size {((0x03) << 8) + (0x8E)}")  # {0x380E[15:8], 0x380F[7:0]}
