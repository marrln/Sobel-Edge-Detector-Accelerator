"""
Utilities for plotting and analyzing Sobel edge detection results.

This module provides functions to compute Sobel edges, compare hardware and software
implementations, and visualize distributions and debug outputs.
"""

import os

import cv2 
import numpy as np
from matplotlib import pyplot as plt

from util import load_raw_image, load_txt_image

__all__ = ['compute_sobel', 'compare_with_software_sobel', 'compare_sobel_distributions', 'debug_sobel_output']


def compute_sobel(image: np.ndarray) -> np.ndarray:
    """
    Compute Sobel edge detection on an image.

    Args:
        image: Input grayscale image.

    Returns:
        Sobel edge magnitude image.
    """
    sobel_x = cv2.Sobel(image, cv2.CV_64F, 1, 0, ksize=3)
    sobel_y = cv2.Sobel(image, cv2.CV_64F, 0, 1, ksize=3)
    software_sobel = cv2.magnitude(sobel_x, sobel_y)
    software_sobel = np.clip(software_sobel, 0, 255).astype(np.uint8)
    return software_sobel


def compare_with_software_sobel(
    original_dir: str,
    original_file: str,
    hw_dir: str,
    hw_file: str,
    sw_file: str = 'output_software_lena_512_512_raw',
    width: int = 512,
    height: int = 512
) -> None:
    """
    Compare hardware and software Sobel implementations with visualizations.

    Args:
        original_dir: Directory of original image.
        original_file: Original image filename.
        hw_dir: Directory of hardware output.
        hw_file: Hardware output filename.
        sw_file: Software output filename.
        width: Image width.
        height: Image height.
    """
    original = load_raw_image(original_dir, original_file, width, height)
    software_sobel = compute_sobel(original)
    hw_sobel = load_txt_image(hw_dir, hw_file, width, height)
    sw_output = load_raw_image(hw_dir, sw_file, width, height)

    plt.figure(figsize=(16, 8))
    plt.suptitle('Comparison of Hardware vs Software Sobel Edge Detection')
    plt.subplot(2, 4, 1)
    plt.imshow(original, cmap='gray')
    plt.title(f'Original Lena ({width}x{height})')
    plt.axis('off')
    plt.subplot(2, 4, 2)
    plt.imshow(software_sobel, cmap='gray')
    plt.title(f'Software Sobel by Open CV ({width}x{height})')
    plt.axis('off')
    plt.subplot(2, 4, 3)
    plt.imshow(hw_sobel, cmap='gray')
    plt.title(f'Hardware Sobel ({width-2}x{height-2})')
    plt.axis('off')
    plt.subplot(2, 4, 4)
    plt.imshow(sw_output, cmap='gray')
    plt.title(f'Software Output ({width}x{height})')
    plt.axis('off')

    zoom_region = (slice(200, 300), slice(200, 300))  # 100x100 region
    plt.subplot(2, 4, 5)
    plt.imshow(original[zoom_region], cmap='gray')
    plt.title('Original (Zoomed)')
    plt.axis('off')
    plt.subplot(2, 4, 6)
    plt.imshow(software_sobel[zoom_region], cmap='gray')
    plt.title('Software Sobel (Zoomed)')
    plt.axis('off')
    plt.subplot(2, 4, 7)
    plt.imshow(hw_sobel[zoom_region], cmap='gray')
    plt.title('Hardware Sobel (Zoomed)')
    plt.axis('off')
    plt.subplot(2, 4, 8)
    plt.imshow(sw_output[zoom_region], cmap='gray')
    plt.title('Software Output (Zoomed)')
    plt.axis('off')
    plt.tight_layout()
    plt.show()

    print(f"Software Sobel range: [{np.min(software_sobel)}, {np.max(software_sobel)}]")
    print(f"Hardware Sobel range: [{np.min(hw_sobel)}, {np.max(hw_sobel)}]")
    print(f"Software Output range: [{np.min(sw_output)}, {np.max(sw_output)}]")


def compare_sobel_distributions(
    hw_dir: str,
    hw_file: str,
    sw_dir: str,
    sw_file: str,
    width: int = 512,
    height: int = 512
) -> None:
    """
    Compare pixel value distributions of hardware and software Sobel outputs.

    Args:
        hw_dir: Directory of hardware output.
        hw_file: Hardware output filename.
        sw_dir: Directory of software output.
        sw_file: Software output filename.
        width: Image width.
        height: Image height.
    """
    hw_sobel = load_txt_image(hw_dir, hw_file, width, height)
    sw_output = load_raw_image(sw_dir, sw_file, width, height)

    plt.figure(figsize=(10, 6))
    plt.hist(hw_sobel.flatten(), bins=50, alpha=0.3, label='Hardware Sobel', color='black')
    plt.hist(sw_output.flatten(), bins=50, alpha=0.3, label='Software Output', color='red')
    plt.title('Comparison of Sobel Value Distributions')
    plt.xlabel('Pixel Value')
    plt.ylabel('Frequency')
    plt.legend()
    plt.tight_layout()
    plt.grid()
    plt.show()
    print(f"Hardware Sobel - Mean: {np.mean(hw_sobel):.2f}, Std: {np.std(hw_sobel):.2f}")
    print(f"Software Output - Mean: {np.mean(sw_output):.2f}, Std: {np.std(sw_output):.2f}")


def debug_sobel_output(dir: str, filename: str, width: int = 512, height: int = 512) -> None:
    """
    Debug a Sobel output by displaying image, histogram, and zoom.

    Args:
        dir: Directory of the file.
        filename: Filename of the output.
        width: Image width.
        height: Image height.
    """
    if 'txt' in filename:
        img = load_txt_image(dir, filename, width, height)
        data = img.flatten()
    elif 'raw' in filename:
        img = load_raw_image(dir, filename, width, height)
        data = img.flatten()
    else:
        print('Unsupported file format')
        return

    print(f"Total pixels: {data.size}")
    print(f"Mean value: {np.mean(data):.2f}")
    plt.figure(figsize=(15, 5))
    plt.subplot(1, 3, 1)
    plt.imshow(img, cmap='gray')
    plt.title('Sobel Output')
    plt.axis('off')
    plt.subplot(1, 3, 2)
    plt.hist(data, bins=50, alpha=0.4)
    plt.title('Pixel Value Distribution')
    plt.subplot(1, 3, 3)
    plt.imshow(img[200:300, 200:300], cmap='gray')
    plt.title('100x100 Zoom')
    plt.axis('off')
    plt.tight_layout()
    plt.show()