@echo off
REM Run Sobel software on lena image
set PATH="C:\Program Files (x86)\Dev-Cpp\MinGW64\bin\gcc.exe";%PATH% gcc -std=c99 -o sobel_sw.exe main.c sobel.c timer.c util.c
set INPUT=..\data\raw\lena_512_512_raw
set OUTPUT=..\data\outputs\output_software_lena_512_512_raw

REM Build the software if needed (uncomment if using gcc)
gcc -std=c99 -o sobel_sw.exe main.c sobel.c timer.c util.c

REM Run the executable
sobel_sw.exe %INPUT% %OUTPUT%

pause