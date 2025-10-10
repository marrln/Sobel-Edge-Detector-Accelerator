#include <stdio.h>
#include <time.h>

#ifdef _WIN32
    #include <windows.h>
    #include <stdint.h>
#endif

double get_current_time(void) {
#ifdef _WIN32
    static LARGE_INTEGER frequency;
    static int frequency_initialized = 0;
    LARGE_INTEGER counter;
    
    if (!frequency_initialized) {
        QueryPerformanceFrequency(&frequency);
        frequency_initialized = 1;
    }
    
    QueryPerformanceCounter(&counter);
    return (double)counter.QuadPart / frequency.QuadPart;
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
#endif
}

double get_elapsed_time(double start_time) {
    return get_current_time() - start_time;
}