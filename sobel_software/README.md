# Sobel Edge Detector - Software Implementation

This folder contains a software implementation of the Sobel edge detection algorithm in C, with timing utilities for performance analysis.

## Overview

The Sobel edge detector is an image processing operator used for edge detection. This implementation provides two variants:
- **Manhattan Distance**: `|Gx| + |Gy|` (faster, less accurate)
- **Euclidean Distance**: `√(Gx² + Gy²)` (slower, more accurate)

## Folder Structure

```
sobel_software/
├── main.c              # Main program with performance analysis
├── sobel.c             # Sobel algorithm implementations
├── sobel.h             # Sobel function declarations
├── util.c              # Utility functions
├── util.h              # Utility function declarations
├── timer.c             # Timing functions
├── timer.h             # Timing function declarations
├── sobel_constants.h   # Image dimension constants (ROW, COLUMN)
└── README.md           # This file
```

### Arguments
- `<input_raw_file>`: Path to input raw image file (512x512 pixels, grayscale)
- `<output_raw_file>`: Path for output edge-detected image

### Output Files
The program generates two output files:
1. `<output_raw_file>` - Manhattan distance result
2. `euclidean_<output_raw_file>` - Euclidean distance result

## Image Format

- **Format**: Raw binary (8-bit grayscale)
- **Dimensions**: 512×512 pixels (configurable in `sobel_constants.h`)

## Performance Output

The program displays timing information for:
- Image loading time
- Manhattan processing time
- Euclidean processing time
- Image saving time
- Total execution time
- Speedup factor (Manhattan vs Euclidean)
