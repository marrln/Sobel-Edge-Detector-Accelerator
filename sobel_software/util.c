#include <stdio.h>
#include <stdint.h>
#include "sobel_constants.h"

void print_matrix(const int *matrix, int rows, int cols) {
    for (int i = 0; i < rows; i++) {
        printf("\n| ");
        for (int j = 0; j < cols; j++) {
            printf("%d\t", matrix[i * cols + j]);
        }
        printf("|");
    }
    printf("\n");
}

int load_raw_image(const char *filename, uint8_t image[ROW][COLUMN]) {
    FILE *file = fopen(filename, "rb");
    if (!file) {
        perror("[ERROR] Opening input file");
        return 1;
    }
    
    int result = fread(image, 1, ROW * COLUMN, file) == ROW * COLUMN ? 0 : 1;
    fclose(file);
    return result;
}

int load_csv_image(FILE *file, uint8_t image[ROW][COLUMN]) {
    if (!file) return 1;
    
    for (int i = 0; i < ROW; i++) {
        for (int j = 0; j < COLUMN; j++) {
            if (fscanf(file, "%hhu", &image[i][j]) != 1) {
                fprintf(stderr, "[ERROR] Bad CSV value at %d,%d\n", i, j);
                return 1;
            }
        }
    }
    return 0;
}

int save_raw_image(const char *filename, uint8_t image[ROW][COLUMN]) {
    FILE *file = fopen(filename, "wb");
    if (!file) {
        perror("[ERROR] Opening output file");
        return 1;
    }
    
    int result = fwrite(image, 1, ROW * COLUMN, file) == ROW * COLUMN ? 0 : 1;
    fclose(file);
    return result;
}

int save_csv_image(FILE *file, uint8_t image[ROW][COLUMN]) {
    if (!file) return 1;
    
    rewind(file);
    for (int i = 0; i < ROW; i++) {
        for (int j = 0; j < COLUMN; j++) {
            if (fprintf(file, "%d\n", image[i][j]) < 0) {
                perror("[ERROR] Writing CSV");
                return 1;
            }
        }
    }
    return 0;
}