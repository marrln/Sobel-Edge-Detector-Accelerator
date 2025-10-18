"""
Utilities for loading and displaying images.

This module provides functions to load raw and txt image files, and display them using matplotlib.

Example usage:
    show_image(outputs_dir, 'output_software_lena_512_512_raw', 512, 512)
    show_image(outputs_dir, 'output_hw_lena_512_512_csv.txt', 510, 510)
    show_image(data_dir, 'lena_512_512_raw', 512, 512)
"""

import os

import numpy as np
from matplotlib import pyplot as plt

__all__ = ['show_image', 'load_raw_image', 'load_txt_image']


def show_raw_image(dir: str, filename: str, width: int, height: int) -> None:
    """
    Display a raw image file.

    Args:
        dir: Directory containing the file.
        filename: Name of the raw file.
        width: Image width.
        height: Image height.
    """
    img = load_raw_image(dir, filename, width, height)
    plt.imshow(img, cmap='gray')
    plt.title(filename)
    plt.axis('off')
    plt.show()


def show_txt_image(dir: str, txt_filename: str, width: int, height: int) -> None:
    """
    Display a TXT image file.

    Args:
        dir: Directory containing the file.
        txt_filename: Name of the TXT file.
        width: Image width.
        height: Image height.
    """
    try:
        img = load_txt_image(dir, txt_filename, width, height)
        plt.imshow(img, cmap='gray')
        plt.title(txt_filename)
        plt.axis('off')
        plt.show()
    except Exception as e:
        print(f'Error loading image: {e}')


def show_image(dir: str, filename: str, width: int, height: int) -> None:
    """
    Display an image based on file extension.

    Args:
        dir: Directory containing the file.
        filename: Name of the file.
        width: Image width.
        height: Image height.
    """
    if filename.endswith('raw'):
        show_raw_image(dir, filename, width, height)
    elif filename.endswith('.txt'):
        show_txt_image(dir, filename, width, height)
    else:
        print('Unsupported file format.')


def load_raw_image(dir: str, filename: str, width: int, height: int) -> np.ndarray:
    """
    Load a raw image file.

    Args:
        dir: Directory containing the file.
        filename: Name of the raw file.
        width: Image width.
        height: Image height.

    Returns:
        Loaded image as numpy array.

    Raises:
        ValueError: If data size doesn't match expected.
    """
    path = os.path.join(dir, filename)
    with open(path, 'rb') as f:
        data = np.frombuffer(f.read(), dtype=np.uint8)
    if data.size != width * height:
        raise ValueError(f'Expected at least {width*height} pixels, got {data.size}')
    if 'hw' in filename:
        return data.reshape((height-2, width-2))
    else:
        return data.reshape((height, width))


def load_txt_image(dir: str, filename: str, width: int, height: int) -> np.ndarray:
    """
    Load a TXT image file.

    Args:
        dir: Directory containing the file.
        filename: Name of the TXT file.
        width: Image width.
        height: Image height.

    Returns:
        Loaded image as numpy array.

    Raises:
        ValueError: If filename doesn't contain 'hw' or 'sw'.
    """
    path = os.path.join(dir, filename)
    data = np.loadtxt(path, dtype=np.uint8)
    if 'hw' in filename:
        return data.reshape((height - 2, width - 2))
    if 'sw' in filename:
        return data.reshape((height, width))
    raise ValueError('Filename must contain either "hw" or "sw" to determine format')