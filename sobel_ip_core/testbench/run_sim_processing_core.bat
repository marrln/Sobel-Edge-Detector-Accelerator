@echo off
REM Vivado 2022.2 Simulation Runner for Windows
REM Automatically loads Vivado environment and runs simulation script for Sobel Processing Core
echo Loading Vivado 2022.2 environment...
call "C:\Xilinx\Vivado\2022.2\settings64.bat"
echo Running simulation...
vivado -mode batch -source run_sim.tcl -tclargs sobel_processing_core_tb
pause