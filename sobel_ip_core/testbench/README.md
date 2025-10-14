# Sobel IP Core Testbench

## Overview
This testbench validates the Sobel Edge Detector IP Core using raw image files.

## Files
- `sobel_processor_tb.vhd` - Main testbench file
- `run_sim.tcl` - Vivado 2022.2 simulation script
- `run_sim.bat` - Windows batch file for easy execution
- `run_modelsim.tcl` - ModelSim/QuestaSim simulation script

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
run_sim.bat
```

**Command Line:**
```bash
cd sobel_ip_core/testbench
vivado -mode batch -source run_sim.tcl
```

**Vivado GUI:**
```tcl
# In Vivado Tcl Console
cd [path_to_project]/sobel_ip_core/testbench
source run_sim.tcl
```

### Using ModelSim/QuestaSim
```bash
cd sobel_ip_core/testbench
vsim -do run_modelsim.tcl
```

### Manual Compilation
```bash
# Compile sources
vcom -2008 ../my_types.vhd
vcom -2008 ../scaler.vhd
vcom -2008 ../window_buffer.vhd
vcom -2008 ../smoother_1d.vhd
vcom -2008 ../derivative_1d.vhd
vcom -2008 ../kernel_application.vhd
vcom -2008 ../gradient_adder.vhd
vcom -2008 ../gradient_adder_tree.vhd
vcom -2008 ../magnitude_adder.vhd
vcom -2008 ../gradient_magnitude.vhd
vcom -2008 ../sobel_pipeline.vhd
vcom -2008 ../top_level_module.vhd
vcom -2008 ../pixel_counter.vhd
vcom -2008 ../cycle_counter.vhd
vcom -2008 ../sobel_processor.vhd

# Compile testbench
vcom -2008 sobel_processor_tb.vhd

# Simulate
vsim work.sobel_processor_tb
run -all
```

## What the Testbench Does

1. **Reset & Initialization**: Applies reset and enables the processor
2. **Input Stimulus**: Reads `lena_512_512_raw` and streams pixels via AXI4-Stream
3. **Output Capture**: Receives processed pixels and writes to `output_lena_512_512_raw`
4. **Performance Monitoring**: Tracks:
   - Input pixel count
   - Output pixel count
   - Cycle count
   - Processing time
5. **Report Generation**: Creates `simulation_report.txt` with statistics

## AXI4-Stream Protocol
The testbench validates:
- Handshake protocol (`tvalid`, `tready`)
- Last signal (`tlast`) assertion on final pixel
- Proper data transfer timing

## Performance Counters
The testbench monitors internal counters (accessible via AXI4-Lite):
- `0x43c10000` - Enable register
- `0x43c10004` - Cycle counter
- `0x43c10008` - Input pixel counter
- `0x43c1000c` - Output pixel counter

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

To test with different images, modify constants in `sobel_processor_tb.vhd`:

```vhdl
-- For house_256_256
constant ROWS    : positive := 256;
constant COLUMNS : positive := 256;
constant PIXELS  : positive := 65536;
constant INPUT_FILE  : string := "../../data/raw/house_256_256_raw";
```

## Performance Goals
- **Target**: 200 MSamples/sec at 200 MHz
- **Cycles/Pixel**: ~1 (deep pipeline)
- **Latency**: Initial pipeline fill + processing time
