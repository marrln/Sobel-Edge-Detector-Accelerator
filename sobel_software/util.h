#ifndef UTIL_H
#define UTIL_H

#include <stdio.h>
#include <stdint.h>
#include "sobel_constants.h"

/**
 * Prints a matrix in a clean table format
 * @param matrix Pointer to the first element of the matrix
 * @param rows Number of rows in the matrix
 * @param cols Number of columns in the matrix
 */
void print_matrix(const int *matrix, int rows, int cols);

/**
 * Load raw image data from file
 * @param filename Path to input file
 * @param image Output image buffer [ROW][COLUMN]
 * @return 0 on success, 1 on error
 */
int load_raw_image(const char *filename, uint8_t image[ROW][COLUMN]);

/**
 * Load image data from CSV file
 * @param file CSV file handle
 * @param image Output image buffer [ROW][COLUMN]
 * @return 0 on success, 1 on error
 */
int load_csv_image(FILE *file, uint8_t image[ROW][COLUMN]);

/**
 * Save image data as raw file
 * @param filename Path to output file
 * @param image Input image buffer [ROW][COLUMN]
 * @return 0 on success, 1 on error
 */
int save_raw_image(const char *filename, uint8_t image[ROW][COLUMN]);

/**
 * Save image data as CSV file
 * @param file CSV file handle
 * @param image Input image buffer [ROW][COLUMN]
 * @return 0 on success, 1 on error
 */
int save_csv_image(FILE *file, uint8_t image[ROW][COLUMN]);

#endif // UTIL_H