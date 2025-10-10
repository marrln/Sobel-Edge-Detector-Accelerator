#include "sobel.h"
#include "sobel_constants.h"
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <stdint.h>

// --- Sobel Kernels ---
static const int Gx[3][3] = {{-1, 0, 1}, {-2, 0, 2}, {-1, 0, 1}};
static const int Gy[3][3] = {{-1, -2, -1}, {0, 0, 0}, {1, 2, 1}};

// --- Sobel Processing ---
static int get_padded_pixel(uint8_t input[ROW][COLUMN], int row, int col) {
    // Handle border by mirroring
    int r = row < 0 ? 0 : (row >= ROW ? ROW - 1 : row);
    int c = col < 0 ? 0 : (col >= COLUMN ? COLUMN - 1 : col);
    return input[r][c];
}

void sobel_manhattan(uint8_t input[ROW][COLUMN], uint8_t output[ROW][COLUMN]) {
    for (int r = 0; r < ROW; r++) {
        for (int c = 0; c < COLUMN; c++) {
            int sx = 0, sy = 0;
            
            // Apply Sobel kernel
            for (int i = -1; i <= 1; i++) {
                for (int j = -1; j <= 1; j++) {
                    int pixel = get_padded_pixel(input, r + i, c + j);
                    sx += pixel * Gx[i + 1][j + 1];
                    sy += pixel * Gy[i + 1][j + 1];
                }
            }
            
            // Manhattan magnitude and clamp to 0-255
            int magnitude = abs(sx) + abs(sy);
            output[r][c] = magnitude > 255 ? 255 : magnitude;
        }
    }
}

void sobel_euclidean(uint8_t input[ROW][COLUMN], uint8_t output[ROW][COLUMN]) {
    for (int r = 0; r < ROW; r++) {
        for (int c = 0; c < COLUMN; c++) {
            int sx = 0, sy = 0;
            
            // Apply Sobel kernel
            for (int i = -1; i <= 1; i++) {
                for (int j = -1; j <= 1; j++) {
                    int pixel = get_padded_pixel(input, r + i, c + j);
                    sx += pixel * Gx[i + 1][j + 1];
                    sy += pixel * Gy[i + 1][j + 1];
                }
            }
            
            // Euclidean magnitude and clamp to 0-255
            int magnitude = (int)(sqrt(sx * sx + sy * sy) + 0.5);
            output[r][c] = magnitude > 255 ? 255 : magnitude;
        }
    }
}