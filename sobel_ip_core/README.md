# Sobel Edge Detector Accelerator IP Core

Complete VHDL implementation of a Sobel edge detection accelerator with AXI4 interfaces.
The IP core implements a pipelined edge detection algorithm with AXI4-Lite control interface and AXI4-Stream data interfaces for seamless SoC integration.

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

### AXI4 Interface Integration Diagram

```
+---------------------------------------------------------------------------------+
|                            AXI4-Lite Control Interface                          |
|                                                                                 |
|  +-----------------+    +-----------------+    +-----------------+              |
|  |   AXI4-Lite     | -> | axi_lite_       | -> | system_enable   |              |
|  |   Registers     |    | interface       |    | signal          |              |
|  |   (AWADDR,      |    |                 |    |                 |              |
|  |    WDATA, etc.) |    | Register Map:   |    | Controls:       |              |
|  |                 |    | - 0x00: Control |    | - Start/Stop     |             |
|  |                 |    | - 0x04: Status  |    | - Reset          |             |
|  |                 |    | - 0x08: Version |    | - Status Read    |             |
|  +-----------------+    +-----------------+    +-----------------+              |
+---------------------------------------------------------------------------------+
                                         |
                                         v
+---------------------------------------------------------------------------------+
|                          AXI4-Stream Data Interface                             |
|                                                                                 |
|  +--------------------+    +--------------------+    +--------------------+     |
|  | Input AXI-Stream   | -> | Input FIFO         | -> | sobel_processing_  | ->  |
|  | (s_axis_*)         |    | (CDC ext->int)     |    | core               |     |
|  | clk_ext            |    |                    |    | clk_int            |     |
|  +--------------------+    +--------------------+    +--------------------+     |
|                                                                                 |
|  +--------------------+    +--------------------+    +--------------------+     |
|  | sobel_processing_  | -> | Output FIFO        | -> | Output AXI-Stream  |     |
|  | core               |    | (CDC int->ext)     |    | (m_axis_*)         |     |
|  | clk_int            |    |                    |    | clk_ext            |     |
|  +--------------------+    +--------------------+    +--------------------+     |
+---------------------------------------------------------------------------------+
```

**AXI4 Interface Flow:**
```
AXI4-Lite Control Flow:
Host CPU -> AXI4-Lite Registers -> axi_lite_interface -> system_enable -> sobel_accelerator

AXI4-Stream Data Flow:
Input Data -> AXI DMA -> AXI4-Stream (s_axis_*) -> sobel_accelerator -> AXI4-Stream (m_axis_*) -> AXI DMA -> Output Data
```

### Module Hierarchy

```
axi4_sobel_accelerator_ip_core (complete IP core with AXI interfaces)
├── axi_lite_interface (AXI4-Lite register interface)
│   ├── AXI4-Lite protocol handling (AWADDR, AWVALID, WDATA, etc.)
│   ├── Register map implementation (Control, Status, Version)
│   └── system_enable signal generation
└── sobel_accelerator (data processing core)
    ├── Input FIFO (AXI4-Stream clock domain crossing)
    ├── sobel_processing_core (processing pipeline)
    │   ├── scaler (optional preprocessing)
    │   ├── window_buffer (3x3 sliding window)
    │   ├── kernel_application (Gx and Gy convolution)
    │   └── manhattan_norm (compute |Gx| + |Gy|)
    ├── Output FIFO (AXI4-Stream clock domain crossing)
    └── sobel_statistics (telemetry with clock domain crossing)
```

## File Descriptions

### Core Processing Files
- **my_types.vhd**: Centralized type definitions and constants for pixel windows, data arrays, and default configuration values
- **scaler.vhd**: Optional input scaling stage for preprocessing
- **window_buffer.vhd**: Line buffer implementation creating 3x3 pixel sliding windows
- **kernel_application.vhd**: Applies Gx and Gy Sobel convolution kernels to compute gradients
- **manhattan_norm.vhd**: Computes |Gx| + |Gy| with saturation arithmetic
- **sobel_processing_core.vhd**: Main processing pipeline (scaler -> window_buffer -> kernel_application -> manhattan_norm)
- **sobel_statistics.vhd**: Telemetry unit with performance counters and clock domain crossing

### AXI Interface Files
- **axi_lite_interface.vhd**: AXI4-Lite register interface for control and status
  - Implements AXI4-Lite protocol (AWADDR, AWVALID, WDATA, WVALID, BRESP, etc.)
  - Register map: Control (0x00), Status (0x04), Version (0x08)
  - Generates system_enable signal for the accelerator
- **axi4_sobel_accelerator_ip_core.vhd**: Complete IP core integrating AXI4-Lite control with AXI4-Stream data processing

### Top-Level Components
- **sobel_accelerator.vhd**: Data processing core with input/output FIFOs, statistics, and dual-clock support
- **axi4_sobel_accelerator_ip_core.vhd**: Complete system-on-chip IP core with both control and data interfaces

## Interface Specifications

### AXI4-Lite Control Interface
The AXI4-Lite interface provides register-based control and status monitoring:

**Write Registers (Host → IP Core):**
- `AWADDR[31:0]`: Register address
- `AWVALID`: Address write valid
- `WDATA[31:0]`: Write data
- `WVALID`: Write data valid
- `BREADY`: Response ready

**Read Registers (IP Core → Host):**
- `ARADDR[31:0]`: Register address
- `ARVALID`: Address read valid
- `RREADY`: Read data ready

**Response Signals:**
- `AWREADY`: Address write ready
- `WREADY`: Write data ready
- `BRESP[1:0]`: Write response (00=OKAY, 10=SLVERR)
- `ARREADY`: Address read ready
- `RDATA[31:0]`: Read data
- `RRESP[1:0]`: Read response (00=OKAY, 10=SLVERR)

**Register Map:**
- `0x00 - Control Register`: 
  - Bit 0: system_enable (1=enable processing, 0=disable)
  - Bits 31:1: Reserved
- `0x04 - Status Register`:
  - Bit 0: processing_active (1=accelerator running, 0=idle)
  - Bits 31:1: Reserved
- `0x08 - Version Register`:
  - Version information (read-only)

### AXI4-Stream Data Interface
- `s_axis_tdata[7:0]`: Input pixel data (8-bit grayscale)
- `s_axis_tvalid`: Input data valid signal
- `s_axis_tready`: Backpressure from IP to source
- `s_axis_tlast`: Frame end marker
- `m_axis_tdata[7:0]`: Output edge-detected pixel
- `m_axis_tvalid`: Output data valid signal
- `m_axis_tready`: Backpressure from sink to IP
- `m_axis_tlast`: Frame end marker

### Control Signals
- `s_axi_aclk`: AXI4-Lite clock (typically same as clk_ext)
- `s_axi_aresetn`: AXI4-Lite active-low reset
- `clk_int`: Internal processing clock
- `clk_ext`: External interface clock
- `rst_n`: Active-low reset
- `en`: Enable signal for processing (from AXI4-Lite control)

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

## AXI Interface Protocols

### AXI4-Lite Protocol
AXI4-Lite is a simplified, register-based protocol for low-throughput control and status interfaces:

**Write Transaction:**
1. Master asserts `AWVALID` with address on `AWADDR`
2. Slave asserts `AWREADY` when ready
3. Master asserts `WVALID` with data on `WDATA`
4. Slave asserts `WREADY` when ready
5. Slave asserts `BVALID` with response on `BRESP`
6. Master asserts `BREADY` when ready

**Read Transaction:**
1. Master asserts `ARVALID` with address on `ARADDR`
2. Slave asserts `ARREADY` when ready
3. Slave asserts `RVALID` with data on `RDATA` and response on `RRESP`
4. Master asserts `RREADY` when ready

### AXI4-Stream Protocol
AXI4-Stream is a high-throughput, streaming protocol for bulk data transfer:

**Data Transaction:**
1. Master asserts `TVALID` with data on `TDATA`
2. Slave asserts `TREADY` when ready to accept data
3. Transfer occurs when both `TVALID` and `TREADY` are asserted
4. `TLAST` indicates end of frame/packet
5. Optional `TUSER`, `TDEST`, `TID` for routing/metadata

### Clock Domain Crossing
The IP core uses dual-clock FIFOs to safely cross clock domains:
- **Input FIFO**: clk_ext → clk_int (external interface to internal processing)
- **Output FIFO**: clk_int → clk_ext (internal processing to external interface)
- **Statistics**: Crosses clk_int → clk_ext for telemetry counters

## Design Features

- **Complete AXI4 Interface**: AXI4-Lite for control + AXI4-Stream for data
- **Pipelined architecture** for high throughput
- **AXI4-Stream interface** for standard SoC integration
- **AXI4-Lite registers** for control and status monitoring
- **Dual-clock support** for clock domain crossing
- **Parametrizable image dimensions** via generics
- **Saturation arithmetic** prevents overflow
- **Minimal latency** through optimized adder trees
- **Centralized configuration** using my_types.vhd constants
- **Register-based control** with system_enable signal
- **Performance monitoring** with input/output/cycle counters

## Generics

### axi4_sobel_accelerator_ip_core Generics
- `rows`: Image height (default: image_rows from my_types)
- `columns`: Image width (default: image_columns from my_types)
- `pixels`: Total pixels (rows × columns, default: image_rows × image_columns)
- `fifo_depth`: FIFO buffer depth for clock domain crossing (default: fifo_depth from my_types)

### sobel_accelerator Generics
- `rows`: Image height (default: image_rows)
- `columns`: Image width (default: image_columns)
- `pixels`: Total pixels (rows × columns, default: image_rows × image_columns)
- `fifo_depth`: FIFO buffer depth (default: fifo_depth)

### sobel_processing_core Generics
- `rows`: Image height (default: image_rows)
- `columns`: Image width (default: image_columns)
- `pixels`: Total pixels (rows × columns, default: image_rows × image_columns)

### Centralized Constants (my_types.vhd)
- `image_rows`: Default image height (512)
- `image_columns`: Default image width (512)
- `fifo_depth`: Default FIFO depth (512)
- `pixel_width`: Pixel data width (8 bits)

## Integration Notes

This accelerator is designed to integrate with:

### AXI4-Lite Control Interface
- **Host CPU**: Controls accelerator via memory-mapped registers
- **Register Access**: Standard AXI4-Lite protocol for control/status
- **Control Flow**: CPU writes to Control register (0x00) to start/stop processing

### AXI4-Stream Data Interface
- **AXI DMA**: Handles bulk data transfer between memory and accelerator
- **Stream Processing**: Continuous data flow for high-throughput processing
- **Clock Domain Crossing**: Dual-clock FIFOs handle clk_ext ↔ clk_int transitions

### System Integration
- **AXI Interconnect**: Routes AXI4-Lite and AXI4-Stream traffic
- **Processing System**: ARM CPU controls accelerator via AXI4-Lite
- **Memory Subsystem**: DDR memory provides input/output buffers

### Usage Flow
1. **Initialization**: CPU configures accelerator parameters via AXI4-Lite
2. **Data Transfer**: AXI DMA streams input image data via AXI4-Stream
3. **Processing**: Accelerator processes data with internal pipelining
4. **Output**: Processed edge-detected image streamed back via AXI4-Stream
5. **Status Monitoring**: CPU reads status registers and performance counters

### Clocking Requirements
- `s_axi_aclk`: AXI4-Lite interface clock (typically 100-200 MHz)
- `clk_ext`: AXI4-Stream interface clock (matches s_axi_aclk)
- `clk_int`: Internal processing clock (can be faster for pipelining)

Refer to `sobel_soc.tcl` for complete system integration and `axi4_sobel_accelerator_ip_core.vhd` for the complete IP core implementation.
