#ifndef SOBEL_H
#define SOBEL_H

#include <stdio.h>
#include <stdint.h>
#include "sobel_constants.h"

// --- Sobel Processing ---
/**
 * Apply Sobel filter using Manhattan distance (|Gx| + |Gy|)
 * @param input Input image [ROW][COLUMN]
 * @param output Output image [ROW][COLUMN]
 */
void sobel_manhattan(uint8_t input[ROW][COLUMN], uint8_t output[ROW][COLUMN]);

/**
 * Apply Sobel filter using Euclidean distance (sqrt(Gx² + Gy²))
 * @param input Input image [ROW][COLUMN]
 * @param output Output image [ROW][COLUMN]
 */
void sobel_euclidean(uint8_t input[ROW][COLUMN], uint8_t output[ROW][COLUMN]);

#endif // SOBEL_H