# Sobel IP Core Testbenches

## Overview
These testbenches validate the Sobel Edge Detector IP Core using raw image files. 

There are two testbenches:
- `sobel_accelerator_tb.vhd` - Tests the full accelerator with CDC and FIFOs
- `sobel_processing_core_tb.vhd` - Tests the processing core pipeline

There are also scripts to run the simulations easily in Vivado 2022.2.
- `run_sim.tcl` - Vivado 2022.2 simulation script

For Windows users:
- `run_sim_accelerator.bat` - Windows batch file for accelerator testbench
- `run_sim_accelerator.bat` - Dedicated accelerator testbench runner

## Test Configuration
- **Vivado Version**: 2022.2
- **Target Device**: Zynq-7000 (xc7z020clg484-1)
- **Input Image**: `lena_512_512_raw` (512x512 pixels, 8-bit grayscale)
- **Internal Clock**: 200 MHz (5 ns period)
- **External Clock**: 100 MHz (10 ns period)
- **Expected Output**: Edge-detected image in raw format

## Running the Simulation

### Using Vivado 2022.2 (Recommended)

**Windows - Easy Method:**
```cmd
cd sobel_ip_core\testbench
run_sim.bat          # Runs accelerator testbench
run_sim_accelerator.bat  # Same as above
run_sim_pipeline.bat     # Runs pipeline testbench
```

**Command Line:**
```bash
cd sobel_ip_core/testbench
vivado -mode batch -source run_sim.tcl                             # Accelerator
vivado -mode batch -source run_sim.tcl -tclargs sobel_pipeline_tb  # Pipeline
```

### Manual Compilation
```bash
# Compile sources
vcom -2008 ../my_types.vhd
vcom -2008 ../scaler.vhd
vcom -2008 ../window_buffer.vhd
vcom -2008 ../kernel_application.vhd
vcom -2008 ../manhattan_norm.vhd
vcom -2008 ../gradient_adder.vhd
vcom -2008 ../gradient_adder_tree.vhd
vcom -2008 ../sobel_pipeline.vhd
vcom -2008 ../sobel_processing_core.vhd
vcom -2008 ../sobel_statistics.vhd
vcom -2008 ../sobel_accelerator.vhd

# Compile testbench
vcom -2008 sobel_accelerator_tb.vhd  # or sobel_pipeline_tb.vhd

# Simulate
vsim work.sobel_accelerator_tb  # or work.sobel_pipeline_tb
run -all
```

## What the Testbenches Do

Both testbenches perform similar operations:

1. **Reset & Initialization**: Applies reset and enables the DUT
2. **Input Stimulus**: Reads `lena_512_512_raw` and streams pixels via AXI4-Stream
3. **Output Capture**: Receives processed pixels and writes to output file
4. **Performance Monitoring**: Tracks pixel counts and cycles
5. **Report Generation**: Creates simulation reports with statistics

**Accelerator Testbench** (`sobel_accelerator_tb`):
- Tests full accelerator with dual-clock FIFOs and CDC
- Uses external clock (100 MHz) for I/O, internal (200 MHz) for processing
- Includes telemetry outputs

**Pipeline Testbench** (`sobel_pipeline_tb`):
- Tests processing core only (scaler → window_buffer → sobel_pipeline)
- Single clock domain
- Simpler for debugging pipeline logic

## AXI4-Stream Protocol
The testbench validates:
- Handshake protocol (`tvalid`, `tready`)
- Last signal (`tlast`) assertion on final pixel
- Proper data transfer timing

## Performance Counters
The accelerator testbench monitors telemetry outputs from `sobel_accelerator`:
- `input_pixel_cnt` - Total input pixels processed
- `output_pixel_cnt` - Total output pixels generated  
- `cycle_cnt` - Total processing cycles (internal clock domain)

For AXI4-Lite access in hardware (if implemented):
- Base address depends on Vivado IP integrator assignment
- Registers: enable (0x00), cycle_cnt (0x04), input_cnt (0x08), output_cnt (0x0C)

## Expected Results
- **Throughput**: ~1 Sample/cycle at 200 MHz
- **Total Pixels**: 262144 (512x512)
- **TLAST**: Asserted on pixel 262144

## Output Files
- `output_lena_512_512_raw` - Processed image (raw format)
- `simulation_report.txt` - Performance statistics

## Verification Steps
After simulation:

1. Check console output for PASS/FAIL status
2. Review `simulation_report.txt`
3. Compare output image with software reference:
   ```bash
   # Compare with sobel_software output
   diff output_lena_512_512_raw ../../sobel_software/output_lena.raw
   ```
4. Verify performance counters match actual pixel counts
5. Check cycle count meets throughput requirements

## Troubleshooting

### File Not Found Errors
- Ensure `lena_512_512_raw` exists in `../../data/raw/`
- Check relative path from testbench directory

### Compilation Errors
- Verify VHDL-2008 support is enabled
- Check all source files are compiled in correct order

### Simulation Hangs
- Check AXI4-Stream handshake signals
- Verify clock generation
- Ensure `sim_done` flag is set

## Modifications for Other Images

To test with different images, modify constants in the testbench files:

```vhdl
-- In sobel_accelerator_tb.vhd or sobel_pipeline_tb.vhd
-- For house_256_256
constant IMG_WIDTH  : integer := 256;
constant IMG_HEIGHT : integer := 256;
constant TOTAL_PIXELS : integer := 65536;
constant INPUT_FILE  : string := "house_256_256_raw";
```

## Performance Goals
- **Target**: 200 MSamples/sec at 200 MHz
- **Cycles/Pixel**: ~1 (deep pipeline)
- **Latency**: Initial pipeline fill + processing time
