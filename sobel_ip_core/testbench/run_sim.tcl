# Simulation script for Sobel Processor Testbench
# Vivado 2022.2 compatible
# Usage: vivado -mode batch -source run_sim.tcl

set tb_name "sobel_accelerator_tb"
if {[llength $::argv] > 0} {
    set tb_name [lindex $::argv 0]
}

# Create project in a simple path
set project_name "sobel_tb"
set project_dir "C:/temp/sobel_sim"
set work_dir "C:/temp/sobel_work"

# Remove old directories if they exist
catch {file delete -force $project_dir}
catch {file delete -force $work_dir}

# Create working directory
file mkdir $work_dir

# --- Paths ---
set script_dir [file dirname [file normalize [info script]]]
set src_dir [file normalize [file join $script_dir ".."]]
set data_dir [file normalize [file join $script_dir "../.." "data"]]

puts "========================================="
puts "Setting up project..."
puts "========================================="

# All source files 
set source_files [list \
    "kernel_application.vhd" \
    "manhattan_norm.vhd" \
    "my_types.vhd" \
    "scaler.vhd" \
    "sobel_accelerator.vhd" \
    "sobel_processing_core.vhd" \
    "sobel_statistics.vhd" \
    "window_buffer.vhd" \
]

# FIFO IP core
set fifo_ip [file join $src_dir "fifo" "fifo.xci"]

# Copy all source files to temp directory
foreach src_file $source_files {
    set src_path [file join $src_dir $src_file]
    set dst_path [file join $work_dir $src_file]
    if {[file exists $src_path]} {
        file copy -force $src_path $dst_path
        puts "Copied: $src_file"
    } else {
        puts "WARNING: Missing source file: $src_path"
    }
}

# Copy testbench
set tb_src [file join $script_dir "$tb_name.vhd"]
set tb_dst [file join $work_dir "$tb_name.vhd"]
file copy -force $tb_src $tb_dst
puts "Copied: $tb_name.vhd"

# Copy input CSV image
set input_csv [file join $data_dir "csv" "lena_512_512_csv.txt"]
set input_dst [file join $work_dir "lena_512_512_csv.txt"]
if {[file exists $input_csv]} {
    file copy -force $input_csv $input_dst
    puts "Copied input: lena_512_512_csv.txt"
} else {
    puts "WARNING: Input CSV file not found: $input_csv"
}

puts "========================================="
puts "Creating Vivado project..."
puts "========================================="

# Create project
create_project $project_name $project_dir -part xc7z020clg484-1 -force

# Set language properties
set_property simulator_language VHDL [current_project]
set_property target_language VHDL [current_project]

# Create FIFO IP
create_ip -name axis_data_fifo -vendor xilinx.com -library ip -version 2.0 -module_name fifo
set_property -dict [list \
  CONFIG.TDATA_NUM_BYTES {1} \
  CONFIG.TID_WIDTH {0} \
  CONFIG.TDEST_WIDTH {0} \
  CONFIG.TUSER_WIDTH {0} \
  CONFIG.FIFO_DEPTH {512} \
  CONFIG.FIFO_MODE {1} \
  CONFIG.IS_ACLK_ASYNC {1} \
  CONFIG.ACLKEN_CONV_MODE {0} \
  CONFIG.HAS_TREADY {1} \
  CONFIG.HAS_TSTRB {0} \
  CONFIG.HAS_TKEEP {0} \
  CONFIG.HAS_TLAST {1} \
  CONFIG.SYNCHRONIZATION_STAGES {3} \
  CONFIG.HAS_WR_DATA_COUNT {0} \
  CONFIG.HAS_RD_DATA_COUNT {0} \
  CONFIG.HAS_AEMPTY {0} \
  CONFIG.HAS_PROG_EMPTY {0} \
  CONFIG.PROG_EMPTY_THRESH {5} \
  CONFIG.HAS_AFULL {0} \
  CONFIG.HAS_PROG_FULL {0} \
  CONFIG.PROG_FULL_THRESH {11} \
  CONFIG.ENABLE_ECC {0} \
  CONFIG.HAS_ECC_ERR_INJECT {0} \
  CONFIG.FIFO_MEMORY_TYPE {block} \
  CONFIG.Component_Name {fifo} \
] [get_ips fifo]
puts "Created FIFO IP: fifo"
# Generate IP targets for simulation
generate_target simulation [get_ips fifo]
puts "Generated FIFO IP simulation files"
# Add IP files to sources
add_files [get_files -of_objects [get_ips fifo]]
puts "Added FIFO IP files to sources"

# Add all source files at once
set files_to_add [list]
foreach src_file $source_files {
    lappend files_to_add [file join $work_dir $src_file]
}
add_files -norecurse $files_to_add

# Set VHDL 2008 for all files
set_property file_type {VHDL 2008} [get_files *.vhd]

# Add testbench to simulation fileset
add_files -fileset sim_1 -norecurse [file join $work_dir "$tb_name.vhd"]
set_property file_type {VHDL 2008} [get_files $tb_name.vhd]

# Set testbench as top
set_property top $tb_name [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Configure simulation
set_property -name {xsim.simulate.runtime} -value {100ms} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]

puts "========================================="
puts "Project created successfully"
puts "Project location: $project_dir"
puts "Working directory: $work_dir"
puts "========================================="

# Launch simulation
puts "Launching simulation..."

# Copy data file to simulation directory
set sim_behav_dir [file join $project_dir "${project_name}.sim" "sim_1" "behav" "xsim"]
file mkdir $sim_behav_dir
set data_file [file join $work_dir "lena_512_512_csv.txt"]
set sim_data_file [file join $sim_behav_dir "lena_512_512_csv.txt"]
file copy -force $data_file $sim_data_file

launch_simulation

# Run simulation
puts "Running simulation..."
run all

puts "========================================="
puts "Simulation complete!"
puts "Working directory: $work_dir"
puts "========================================="