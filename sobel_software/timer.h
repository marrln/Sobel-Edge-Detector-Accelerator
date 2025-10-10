#ifndef TIMER_H
#define TIMER_H

/**
 * Get current time in seconds with high precision (cross-platform)
 * Uses QueryPerformanceCounter on Windows and clock_gettime on Unix systems
 * @return Current time in seconds as double precision floating point
 */
double get_current_time(void);

/**
 * Returns elapsed time in seconds since the start time
 * @param start_time Starting time obtained from get_current_time()
 * @return Elapsed time in seconds as double precision floating point
 */
double get_elapsed_time(double start_time);

#endif