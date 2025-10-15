# Sobel Edge Detector Accelerator IP Core

Clean VHDL implementation of a Sobel edge detection accelerator.
The Sobel accelerator implements a pipelined edge detection algorithm using AXI4-Stream interfaces.

### Data Flow Diagram

```
┌────────────────────┐    ┌────────────────────┐    ┌────────────────────┐    ┌────────────────────┐    ┌────────────────────┐
│ Input AXI-Stream   │ -> │ Input FIFO         │ -> │ sobel_processing_  │ -> │ Output FIFO        │ -> │ Output AXI-Stream  │
│ (s_axis_*)         │    │ (CDC ext->int)     │    │ core               │    │ (CDC int->ext)     │    │ (m_axis_*)         │
│ clk_ext            │    │                    │    │ clk_int            │    │                    │    │ clk_ext            │
└────────────────────┘    └────────────────────┘    └────────────────────┘    └────────────────────┘    └────────────────────┘
         │                           │                           │                           │                           │
         └───────────────────────────┼───────────────────────────┼───────────────────────────┼───────────────────────────┘
                                     │                           │                           │
                                     v                           v                           v
                                sobel_statistics          sobel_statistics          sobel_statistics
                                (input_pixel_cnt)         (cycle_cnt)              (output_pixel_cnt)
```

**Detailed Pipeline Flow:**
```
sobel_processing_core:
s_data/s_valid/s_last -> scaler -> window_buffer -> sobel_pipeline -> m_data/m_valid/m_last

sobel_pipeline:
kernel_application -> gradient_adder_tree -> manhattan_norm
```

### Module Hierarchy

```
sobel_accelerator (top-level with FIFOs and statistics)
├── Input FIFO (AXI4-Stream clock domain crossing)
├── sobel_processing_core (processing pipeline)
│   ├── scaler (optional preprocessing)
│   ├── window_buffer (3x3 sliding window)
│   └── sobel_pipeline
│       ├── kernel_application (Gx and Gy convolution)
│       │   ├── derivative_1d (multiply by [-1, 0, +1])
│       │   └── smoother_1d (multiply by [1, 2, 1])
│       ├── gradient_adder_tree (sum Gx and Gy in adder tree)
│       └── manhattan_norm (compute |Gx| + |Gy|)
├── Output FIFO (AXI4-Stream clock domain crossing)
└── sobel_statistics (telemetry with clock domain crossing)
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
- **manhattan_norm.vhd**: Computes |Gx| + |Gy| with saturation
- **sobel_pipeline.vhd**: Complete Sobel pipeline
- **sobel_processing_core.vhd**: Processing pipeline (scaler -> window_buffer -> sobel_pipeline)
- **sobel_statistics.vhd**: Telemetry unit with counters and clock domain crossing
- **sobel_accelerator.vhd**: Top-level with input/output FIFOs and statistics

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

- `rows`: Image height (default: 512)
- `columns`: Image width (default: 512)
- `pixels`: Total pixels (rows × columns, default: 262144)

## Integration Notes

This accelerator is designed to integrate with:
- AXI DMA for memory-mapped data transfer
- AXI4-Lite registers for control/status
- Processing System via AXI interconnect

Refer to `sobel_soc.tcl` for complete system integration.
