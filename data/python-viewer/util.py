# Functions to load and display images
#
# Example usage:
# show_image(outputs_dir,'output_software_lena_512_512_raw', 512, 512)
# show_image(outputs_dir, 'output_hw_lena_512_512_csv.txt', 510, 510)
# show_image(data_dir, 'lena_512_512_raw', 512, 512)

import os
import numpy as np
from matplotlib import pyplot as plt

def show_raw_image(dir, filename, width, height):
    path = os.path.join(dir, filename)
    with open(path, 'rb') as f:
        data = np.frombuffer(f.read(), dtype=np.uint8)
    if data.size != width * height:
        print(f'Error: Expected {width*height} bytes, got {data.size}')
        return
    img = data.reshape((height, width))
    plt.imshow(img, cmap='gray')
    plt.title(filename)
    plt.axis('off')
    plt.show()

def show_txt_image(dir, txt_filename, width, height):
    path = os.path.join(dir, txt_filename)
    try:
        data = np.loadtxt(path, dtype=np.uint8)
        if data.size != width * height:
            print(f'Error: Expected {width*height} pixels, got {data.size}')
            return
        img = data.reshape((height, width))
        plt.imshow(img, cmap='gray')
        plt.title(txt_filename)
        plt.axis('off')
        plt.show()
    except Exception as e:
        print(f'Error loading image: {e}')

def show_image(dir, filename, width, height):
    if filename.endswith('raw'):
        show_raw_image(dir, filename, width, height)
    elif filename.endswith('.txt'):
        show_txt_image(dir, filename, width, height)
    else:
        print('Unsupported file format.')