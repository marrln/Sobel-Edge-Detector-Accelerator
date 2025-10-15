@echo off
cd /d %~dp0
call C:\Xilinx\Vivado\2022.2\settings64.bat
vivado -mode batch -source run_sim.tcl -tclargs sobel_processing_core_tb