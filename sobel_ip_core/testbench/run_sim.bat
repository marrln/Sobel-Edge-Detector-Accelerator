@echo off
REM Vivado 2022.2 Simulation Runner for Windows
REM Automatically loads Vivado environment if needed

echo ========================================
echo Sobel IP Core Testbench
echo Vivado 2022.2
echo ========================================
echo.

REM Check if Vivado is in PATH
where vivado >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Vivado not in PATH. Attempting to load settings...
    
    REM Try to run settings64.bat
    if exist "C:\Xilinx\Vivado\2022.2\settings64.bat" (
        echo Loading Vivado 2022.2 environment...
        call "C:\Xilinx\Vivado\2022.2\settings64.bat"
        echo.
    ) else (
        echo ERROR: Vivado 2022.2 not found at C:\Xilinx\Vivado\2022.2\
        echo Please install Vivado 2022.2 or update the path in this script.
        pause
        exit /b 1
    )
)

echo Running simulation...
echo.

vivado -mode batch -source run_sim.tcl

echo.
echo ========================================
echo Simulation complete!
echo ========================================
echo Results are located in:
echo   C:\Temp\sobel_work\
echo.
echo Check the following files:
echo   - simulation_report.txt
echo   - output_lena_512_512_raw
echo ========================================
pause
