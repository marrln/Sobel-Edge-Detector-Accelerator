# Sobel Edge Detector IP Core

Clean VHDL implementation of a Sobel edge detection accelerator IP core based on the architecture from YannosK/Sobel_Edge_Detector_on_Zynq7000_SoC.

## Architecture Overview

The Sobel IP core implements a pipelined edge detection algorithm using AXI4-Stream interfaces.

### Module Hierarchy

```
sobel_processor
├── top_level_module
│   ├── scaler (optional preprocessing)
│   ├── window_buffer (3x3 sliding window)
│   └── sobel_pipeline
│       ├── kernel_application (Gx and Gy convolution)
│       │   ├── derivative_1d (multiply by [-1, 0, +1])
│       │   └── smoother_1d (multiply by [1, 2, 1])
│       ├── gradient_adder_tree (sum Gx and Gy in adder tree)
│       ├── gradient_magnitude (compute |Gx| and |Gy|)
│       └── magnitude_adder (add and saturate to 8-bit)
├── pixel_counter (input pixel counter)
├── cycle_counter (cycle counter)
└── pixel_counter (output pixel counter)
```

## File Descriptions

- **my_types.vhd**: Type definitions for pixel windows and data arrays
- **scaler.vhd**: Optional input scaling stage
- **window_buffer.vhd**: Line buffer creating 3x3 pixel windows
- **derivative_1d.vhd**: First convolution stage ([-1, 0, +1] weights)
- **smoother_1d.vhd**: Second convolution stage ([1, 2, 1] weights)
- **kernel_application.vhd**: Applies Gx and Gy Sobel kernels in parallel
- **gradient_adder.vhd**: Handshaking 2-input adder
- **gradient_adder_tree.vhd**: Hierarchical adder tree for Gx and Gy gradient summation
- **gradient_magnitude.vhd**: Absolute value computation
- **magnitude_adder.vhd**: Final addition with saturation
- **sobel_pipeline.vhd**: Complete Sobel pipeline
- **pixel_counter.vhd**: Pixel counter with reset on frame end
- **cycle_counter.vhd**: Cycle counter with enable control
- **top_level_module.vhd**: Processing pipeline
- **sobel_processor.vhd**: Top-level with counters and control

## Interface Specifications

### AXI4-Stream Signals
- `s_axis_tdata[7:0]`: Input pixel data (8-bit grayscale)
- `s_axis_tvalid`: Input data valid signal
- `s_axis_tready`: Backpressure from IP to source
- `s_axis_tlast`: Frame end marker
- `m_axis_tdata[7:0]`: Output edge-detected pixel
- `m_axis_tvalid`: Output data valid signal
- `m_axis_tready`: Backpressure from sink to IP
- `m_axis_tlast`: Frame end marker

### Control Signals
- `clk_int`: Internal processing clock
- `clk_ext`: External interface clock
- `rst_n`: Active-low reset
- `en`: Enable signal for processing

### Monitoring Outputs
- `input_pixel_cnt[31:0]`: Number of pixels received
- `output_pixel_cnt[31:0]`: Number of pixels output
- `cycle_cnt[31:0]`: Processing cycles elapsed

## Algorithm

The Sobel operator computes image gradients using two 3x3 kernels:

**Gx (horizontal):**
```
[-1  0  +1]
[-2  0  +2]
[-1  0  +1]
```

**Gy (vertical):**
```
[-1 -2 -1]
[ 0  0  0]
[+1 +2 +1]
```

Result: `Edge = |Gx| + |Gy|`

## Design Features

- **Pipelined architecture** for high throughput
- **AXI4-Stream interface** for standard SoC integration
- **Dual-clock support** for clock domain crossing
- **Parametrizable image dimensions** via generics
- **Saturation arithmetic** prevents overflow
- **Minimal latency** through optimized adder trees

## Generics

- `rows`: Image height (default: 480)
- `columns`: Image width (default: 640)
- `pixels`: Total pixels (rows × columns, default: 307200)

## Integration Notes

This IP core is designed to integrate with:
- AXI DMA for memory-mapped data transfer
- AXI4-Lite registers for control/status
- Processing System via AXI interconnect

Refer to `sobel_soc.tcl` for complete system integration.
