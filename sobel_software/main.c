#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sobel.h"
#include "timer.h"
#include "util.h"
#include "sobel_constants.h"

int main(int argc, char *argv[]) {
    // Check command line arguments
    if (argc < 3) {
        printf("Usage: %s <input_raw_file> <output_raw_file>\n", argv[0]);
        printf("Example: %s ../data/raw/lena_512_512_raw output_sobel.raw\n", argv[0]);
        return 1;
    }

    const char *input_filename = argv[1];
    const char *output_filename = argv[2];

    // Allocate memory for input and output images
    uint8_t (*input_image)[COLUMN] = malloc(ROW * COLUMN * sizeof(uint8_t));
    uint8_t (*output_manhattan)[COLUMN] = malloc(ROW * COLUMN * sizeof(uint8_t));
    uint8_t (*output_euclidean)[COLUMN] = malloc(ROW * COLUMN * sizeof(uint8_t));

    if (!input_image || !output_manhattan || !output_euclidean) {
        printf("[ERROR] Memory allocation failed\n");
        free(input_image);
        free(output_manhattan);
        free(output_euclidean);
        return 1;
    }

    // Load input image
    printf("Loading image from: %s\n", input_filename);
    double start_time = get_current_time();
    if (load_raw_image(input_filename, input_image) != 0) {
        printf("[ERROR] Failed to load input image\n");
        free(input_image);
        free(output_manhattan);
        free(output_euclidean);
        return 1;
    }
    double load_time = get_elapsed_time(start_time);
    printf("Image loaded successfully in %.6f seconds\n", load_time);
    printf("Image dimensions: %d x %d\n\n", ROW, COLUMN);

    // Apply Sobel Manhattan distance
    printf("=== Sobel Manhattan Distance (|Gx| + |Gy|) ===\n");
    start_time = get_current_time();
    sobel_manhattan(input_image, output_manhattan);
    double manhattan_time = get_elapsed_time(start_time);
    printf("Processing time: %.6f seconds\n\n", manhattan_time);

    // Apply Sobel Euclidean distance
    printf("=== Sobel Euclidean Distance (sqrt(Gx² + Gy²)) ===\n");
    start_time = get_current_time();
    sobel_euclidean(input_image, output_euclidean);
    double euclidean_time = get_elapsed_time(start_time);
    printf("Processing time: %.6f seconds\n\n", euclidean_time);

    // Save output image (Manhattan version by default)
    printf("Saving Manhattan result to: %s\n", output_filename);
    start_time = get_current_time();
    if (save_raw_image(output_filename, output_manhattan) != 0) {
        printf("[ERROR] Failed to save output image\n");
        free(input_image);
        free(output_manhattan);
        free(output_euclidean);
        return 1;
    }
    double save_time = get_elapsed_time(start_time);
    printf("Output saved successfully in %.6f seconds\n\n", save_time);

    // Optionally save Euclidean version
    char euclidean_filename[256];
    snprintf(euclidean_filename, sizeof(euclidean_filename), "euclidean_%s", output_filename);
    printf("Saving Euclidean result to: %s\n", euclidean_filename);
    if (save_raw_image(euclidean_filename, output_euclidean) != 0) {
        printf("[ERROR] Failed to save Euclidean output image\n");
    } else {
        printf("Euclidean output saved successfully\n\n");
    }

    // Print summary
    printf("=== Performance Summary ===\n");
    printf("Load time:           %.6f seconds\n", load_time);
    printf("Manhattan time:      %.6f seconds\n", manhattan_time);
    printf("Euclidean time:      %.6f seconds\n", euclidean_time);
    printf("Save time:           %.6f seconds\n", save_time);
    printf("Total time:          %.6f seconds\n", load_time + manhattan_time + euclidean_time + save_time);
    printf("\nSpeedup factor (Manhattan vs Euclidean): %.2fx\n", euclidean_time / manhattan_time);

    // Clean up
    free(input_image);
    free(output_manhattan);
    free(output_euclidean);

    printf("\nProcessing complete!\n");
    return 0;
}
