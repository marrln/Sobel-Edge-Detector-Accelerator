# Sobel Edge Detector Acceleration on Xilinx Zynq-7000 SoC

## Overview
This project presents the **design, implementation, and evaluation** of a complete **System-on-Chip (SoC)** solution for accelerating the **Sobel edge detection algorithm** on the **Xilinx Zynq-7000 AP SoC** platform.  
The main objective is to leverage the combined architecture of the **Processing System (PS)** and **Programmable Logic (PL)** of the Zynq device to achieve a significant performance improvement compared to a pure software implementation.

---

## System Description

### 1. Software Implementation
The Sobel edge detection algorithm was first implemented in **C** and executed on the **ARM Cortex-A9 cores** of the Zynq Processing System under a **PetaLinux** environment.  
This software version provided baseline **performance metrics**—such as execution time and throughput—used later for comparison with the hardware-accelerated implementation.

---

### 2. Hardware Acceleration (VHDL Implementation)
A dedicated **Sobel Edge Detector IP Core** was designed in **VHDL** to accelerate the computation within the **Programmable Logic (PL)**.  

**Key features:**
- **AXI4-Lite interface** for control and performance counter access  
- **AXI4-Stream interfaces** for image data input/output  
- **Full AXI DMA compatibility**  
- **Pipeline and parallel processing techniques** enabling processing rates up to **200 MSamples/sec** at **200 MHz**

After simulation and verification using a **VHDL testbench**, the IP Core was integrated into a complete SoC design.

---

### 3. System Integration
The full SoC connects the **Sobel IP Core** with an **AXI DMA** module, which manages data transfers between the **DDR3 DRAM** and the programmable logic.  
A **C-based user application** running under **PetaLinux** controls the hardware accelerator, manages DMA transfers, and collects performance data for direct comparison with the software-only implementation.

---

## Evaluation and Results
Both implementations—software-only and hardware-accelerated—were evaluated in terms of:

- **Execution time**
- **Throughput**
- **FPGA resource utilization**

The results showed a **significant speedup** of the Sobel edge detection when executed on the FPGA fabric, validating the advantages of **hardware/software co-design** for image processing applications.

---

## Tools & Technologies
- **Platform:** Xilinx Zynq-7000 AP SoC  
- **Languages:** C, VHDL  
- **Environment:** PetaLinux, Vivado Design Suite  
- **Interfaces:** AXI4-Lite, AXI4-Stream, AXI DMA  

---

## Repository Structure 

[sobel_software/](./sobel_software): Contains the C implementation of the Sobel algorithm with timing utilities.
[TODO] : Contains the VHDL implementation of the Sobel IP Core and related files.
[TODO] : Contains the Vivado project files for the complete SoC design integrating the Sobel IP Core.
[doc/](./doc): Contains the project description and report files.
[data/](./data): Contains sample images for testing the Sobel implementations.
