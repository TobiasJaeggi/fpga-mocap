import math
import socket
import struct
from PIL import Image

def file_to_pixels(file_path: str):
    with open(file_path, 'rb') as f:
        data = f.read()
    print(len(data))
    uint16_list = struct.unpack('>' + 'H' * (len(data) // 2), data)
    return uint16_list

def rgb565_to_rgb888(pixel):
    # Extract red, green, and blue components
    red = (pixel >> 11) & 0x1F     # Extract bits 11-15
    green = (pixel >> 5) & 0x3F    # Extract bits 5-10
    blue = pixel & 0x1F            # Extract bits 0-4
    # Convert to 8-bit per channel (0-255 range)
    # chatgpt magic...
    red = (red << 3) | (red >> 2)    # Scale 5-bit to 8-bit
    green = (green << 2) | (green >> 4)  # Scale 6-bit to 8-bit
    blue = (blue << 3) | (blue >> 2)  # Scale 5-bit to 8-bit
    return (red, green, blue)

def convert(file_path: str):
    pixels = file_to_pixels(file_path)
    width = 640
    height = 480
    img = Image.new(mode='RGB', size=(width, height))
    rgb_pixels = [rgb565_to_rgb888(pixel) for pixel in pixels]
    print(len(rgb_pixels))
    img.putdata(rgb_pixels)
    img.save(file_path + '.png')

if __name__ == "__main__":
    convert("snapshot")