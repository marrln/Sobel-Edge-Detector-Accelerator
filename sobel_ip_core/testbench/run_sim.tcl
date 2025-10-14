# Simulation script for Sobel Processor Testbench
# Vivado 2022.2 compatible
# Usage: vivado -mode batch -source run_sim.tcl

# Create project in a path without special characters
set project_name "sobel_tb"
set project_dir "C:/Temp/sobel_sim"
set work_dir "C:/Temp/sobel_work"

# Remove old directories if they exist
if {[file exists $project_dir]} {
    file delete -force $project_dir
}
if {[file exists $work_dir]} {
    file delete -force $work_dir
}

# Create working directory
file mkdir $work_dir

# --- Paths ---
set script_dir [file dirname [file normalize [info script]]]
set src_dir [file normalize [file join $script_dir ".."]]
set data_dir [file normalize [file join $script_dir "../.." "data"]]

puts "========================================="
puts "Copying source files to temporary location..."
puts "Source: $src_dir"
puts "Destination: $work_dir"
puts "========================================="

# Copy source files to temp directory
set source_files [list \
    "my_types.vhd" \
    "scaler.vhd" \
    "window_buffer.vhd" \
    "smoother_1d.vhd" \
    "derivative_1d.vhd" \
    "kernel_application.vhd" \
    "gradient_adder.vhd" \
    "gradient_adder_tree.vhd" \
    "magnitude_adder.vhd" \
    "gradient_magnitude.vhd" \
    "sobel_pipeline.vhd" \
    "top_level_module.vhd" \
    "pixel_counter.vhd" \
    "cycle_counter.vhd" \
    "sobel_processor.vhd" \
]

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

# --- Copy testbench ---
set tb_src [file join $script_dir "sobel_processor_tb.vhd"]
set tb_dst [file join $work_dir "sobel_processor_tb.vhd"]
file copy -force $tb_src $tb_dst
puts "Copied: sobel_processor_tb.vhd"

# --- Copy input raw image ---
set input_raw [file join $data_dir "raw" "lena_512_512_raw"]
set input_dst [file join $work_dir "lena_512_512_raw"]
file copy -force $input_raw $input_dst
puts "Copied input: lena_512_512_raw"

puts "========================================="
puts "Creating Vivado project..."
puts "========================================="

# Create new project for Zynq-7000 (ZedBoard)
create_project $project_name $project_dir -part xc7z020clg484-1 -force

# Set simulator language
set_property simulator_language VHDL [current_project]
set_property target_language VHDL [current_project]

# Add design source files in dependency order
add_files -norecurse [list \
    [file join $work_dir "my_types.vhd"] \
    [file join $work_dir "scaler.vhd"] \
    [file join $work_dir "window_buffer.vhd"] \
    [file join $work_dir "smoother_1d.vhd"] \
    [file join $work_dir "derivative_1d.vhd"] \
    [file join $work_dir "kernel_application.vhd"] \
    [file join $work_dir "gradient_adder.vhd"] \
    [file join $work_dir "gradient_adder_tree.vhd"] \
    [file join $work_dir "magnitude_adder.vhd"] \
    [file join $work_dir "gradient_magnitude.vhd"] \
    [file join $work_dir "sobel_pipeline.vhd"] \
    [file join $work_dir "top_level_module.vhd"] \
    [file join $work_dir "pixel_counter.vhd"] \
    [file join $work_dir "cycle_counter.vhd"] \
    [file join $work_dir "sobel_processor.vhd"] \
]

# Set as design sources
set_property file_type {VHDL 2008} [get_files *.vhd]

# Add testbench
add_files -fileset sim_1 -norecurse [file join $work_dir "sobel_processor_tb.vhd"]
set_property file_type {VHDL 2008} [get_files sobel_processor_tb.vhd]

# Set testbench as top
set_property top sobel_processor_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Configure simulation settings
set_property -name {xsim.compile.xvhdl.more_options} -value {-2008} -objects [get_filesets sim_1]
set_property -name {xsim.elaborate.xelab.more_options} -value {-debug typical} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {100ms} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]

# Set simulation working directory to where the data files are
set_property -name {xsim.simulate.custom_tcl} -value {} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.xsim.more_options} -value "-wdb wave.wdb" -objects [get_filesets sim_1]

# Copy simulation files to the xsim directory
puts "Setting up simulation environment..."

puts "========================================="
puts "Project created successfully"
puts "Project location: $project_dir"
puts "Working directory: $work_dir"
puts "Target: Zynq-7000 (xc7z020clg484-1)"
puts "Vivado Version: 2022.2"
puts "========================================="

# Launch simulation
puts "Launching simulation..."

# Copy data file to expected simulation directory before launching
set sim_behav_dir [file join $project_dir "${project_name}.sim" "sim_1" "behav" "xsim"]
file mkdir $sim_behav_dir
set data_file [file join $work_dir "lena_512_512_raw"]
set sim_data_file [file join $sim_behav_dir "lena_512_512_raw"]
file copy -force $data_file $sim_data_file
puts "Copied data file to: $sim_behav_dir"

launch_simulation

# Run all
puts "Running simulation..."
run all

puts "========================================="
puts "Simulation complete!"
puts "========================================="

# --- Copy generated output raw image back to outputs folder ---
set sim_output [file join $sim_behav_dir "output_lena_512_512_raw"]
set output_dst "C:/Users/mrlnp/OneDrive - National and Kapodistrian University of Athens/Υπολογιστής/Προηγμένη Σχεδίαση Ψηφιακών Συστημάτων/Sobel-Edge-Detector-Accelerator/data/outputs/output_lena_512_512_raw"

if {[file exists $sim_output]} {
    file copy -force $sim_output $output_dst
    puts "Output raw image copied to outputs folder:"
    puts "$output_dst"
} else {
    puts "Warning: Simulation output not found in $sim_behav_dir"
    puts "Check if simulation ran to completion."
}

puts "========================================="
puts "Check simulation_report.txt for summary"
puts "Working directory: $work_dir"
puts "========================================="
