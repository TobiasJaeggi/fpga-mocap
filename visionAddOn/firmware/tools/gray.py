import matplotlib.pyplot as plt

from skimage import data
from skimage.color import rgb2gray
import numpy

original = data.astronaut()
grayscale = rgb2gray(original)

grayscale_10bit = grayscale / 1.0 * 1024
grayscale_10bit = grayscale_10bit.astype(numpy.uint16)

grayscale_8bit = grayscale_10bit >> 2 # cut of 2 lsb to go to 8 bit
grayscale_8bit = grayscale_8bit.astype(numpy.uint8)

# underexpose image a tiny bit to prevent clipping
exposure = 0.99
grayscale_10bit_uexp = grayscale * exposure / 1.0 * 1024
grayscale_10bit_uexp = grayscale_10bit_uexp.astype(numpy.uint16)
grayscale_8bit_uexp = grayscale_10bit_uexp >> 2 # cut of 2 lsb to go to 8 bit
grayscale_8bit_uexp = grayscale_8bit_uexp.astype(numpy.uint8)

fig, axes = plt.subplots(1, 4, figsize=(8, 4))
ax = axes.ravel()
ax[0].imshow(original)
ax[0].set_title("Original")

ax[1].imshow(grayscale_10bit, cmap=plt.cm.gray)
ax[1].set_title("Grayscale 10bit")

ax[2].imshow(grayscale_8bit, cmap=plt.cm.gray)
ax[2].set_title("Grayscale 8bit")

ax[3].imshow(grayscale_8bit_uexp, cmap=plt.cm.gray, vmin=0, vmax=255)
ax[3].set_title("Grayscale 8bit underexposed")

fig.tight_layout()
plt.show()

