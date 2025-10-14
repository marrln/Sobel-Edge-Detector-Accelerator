library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;  -- For std_logic_vector I/O

entity sobel_processor_tb is
end sobel_processor_tb;

architecture Behavioral of sobel_processor_tb is
    
    -- Constants
    constant CLK_INT_PERIOD : time := 5 ns;   -- 200 MHz
    constant CLK_EXT_PERIOD : time := 10 ns;  -- 100 MHz
    constant INPUT_FILE  : string := "lena_512_512_raw";
    constant OUTPUT_FILE : string := "output_lena_512_512_raw";
    
    -- Image dimensions
    constant IMG_WIDTH  : integer := 512;
    constant IMG_HEIGHT : integer := 512;
    constant TOTAL_PIXELS : integer := IMG_WIDTH * IMG_HEIGHT;
    
    constant TIMEOUT : time := 150 ms;  -- Simulation timeout
    -- Component declaration
    component sobel_processor is
        generic (
            rows    : positive := IMG_HEIGHT;
            columns : positive := IMG_WIDTH;
            pixels  : positive := TOTAL_PIXELS
        );
        port (
            clk_int          : in std_logic;
            clk_ext          : in std_logic;
            rst_n            : in std_logic;
            en               : in std_logic;
            s_axis_tvalid    : in std_logic;
            s_axis_tready    : out std_logic;
            s_axis_tlast     : in std_logic;
            s_axis_tdata     : in std_logic_vector(7 downto 0);
            m_axis_tvalid    : out std_logic;
            m_axis_tready    : in std_logic;
            m_axis_tlast     : out std_logic;
            m_axis_tdata     : out std_logic_vector(7 downto 0);
            input_pixel_cnt  : out std_logic_vector(31 downto 0);
            output_pixel_cnt : out std_logic_vector(31 downto 0);
            cycle_cnt        : out std_logic_vector(31 downto 0)
        );
    end component;
    
    -- Signals
    signal clk_int          : std_logic := '0';
    signal clk_ext          : std_logic := '0';
    signal rst_n            : std_logic := '0';
    signal en               : std_logic := '0';
    signal s_axis_tvalid    : std_logic := '0';
    signal s_axis_tready    : std_logic := '0';
    signal s_axis_tlast     : std_logic := '0';
    signal s_axis_tdata     : std_logic_vector(7 downto 0) := (others => '0');
    signal m_axis_tvalid    : std_logic := '0';
    signal m_axis_tready    : std_logic := '1'; -- Always ready to receive
    signal m_axis_tlast     : std_logic := '0';
    signal m_axis_tdata     : std_logic_vector(7 downto 0) := (others => '0');
    signal input_pixel_cnt  : std_logic_vector(31 downto 0) := (others => '0');
    signal output_pixel_cnt : std_logic_vector(31 downto 0) := (others => '0');
    signal cycle_cnt        : std_logic_vector(31 downto 0) := (others => '0');
    
    -- Testbench control
    signal sim_ended : boolean := false;
    signal input_done : boolean := false;
    signal output_done : boolean := false;
    signal all_done : boolean := false;
    
begin

    -- Clock generation
    clk_int <= not clk_int after CLK_INT_PERIOD/2 when not all_done else '0';
    clk_ext <= not clk_ext after CLK_EXT_PERIOD/2 when not all_done else '0';

    -- DUT instantiation
    uut: sobel_processor
        generic map (
            rows    => IMG_HEIGHT,
            columns => IMG_WIDTH,
            pixels  => TOTAL_PIXELS
        )
        port map (
            clk_int          => clk_int,
            clk_ext          => clk_ext,
            rst_n            => rst_n,
            en               => en,
            s_axis_tvalid    => s_axis_tvalid,
            s_axis_tready    => s_axis_tready,
            s_axis_tlast     => s_axis_tlast,
            s_axis_tdata     => s_axis_tdata,
            m_axis_tvalid    => m_axis_tvalid,
            m_axis_tready    => m_axis_tready,
            m_axis_tlast     => m_axis_tlast,
            m_axis_tdata     => m_axis_tdata,
            input_pixel_cnt  => input_pixel_cnt,
            output_pixel_cnt => output_pixel_cnt,
            cycle_cnt        => cycle_cnt
        );

    -- Main simulation control process
    sim_control_proc: process
    begin
        wait until (input_done and output_done) or (now > TIMEOUT);
        
        if input_done and output_done then
            report "SIMULATION COMPLETED SUCCESSFULLY: Both input and output processes finished";
        else
            report "SIMULATION ENDED: Timeout or incomplete processing" severity warning;
            report "Input done: " & boolean'image(input_done) & ", Output done: " & boolean'image(output_done);
        end if;
        
        report "FINAL STATISTICS:";
        report "  Input pixels processed:  " & integer'image(to_integer(unsigned(input_pixel_cnt)));
        report "  Output pixels generated: " & integer'image(to_integer(unsigned(output_pixel_cnt)));
        report "  Total cycles: " & integer'image(to_integer(unsigned(cycle_cnt)));
        
        if to_integer(unsigned(input_pixel_cnt)) = TOTAL_PIXELS and 
           to_integer(unsigned(output_pixel_cnt)) = TOTAL_PIXELS then
            report "  RESULT: SUCCESS - Input and output counts match expected " & integer'image(TOTAL_PIXELS) & " pixels";
        else
            report "  RESULT: MISMATCH - Pixel counts don't match expected values" severity warning;
        end if;
        
        all_done <= true;
        wait for 100 ns;
        std.env.stop;
        wait;
    end process;

    -- Stimulus process
    stimulus_proc: process
        file input_f : text open read_mode is INPUT_FILE;
        variable input_line : line;
        variable pixel_value : std_logic_vector(7 downto 0);
        variable pixel_index : integer := 0;
        variable row_count : integer := 0;
    begin
        rst_n <= '0';
        en <= '0';
        s_axis_tvalid <= '0';
        s_axis_tlast <= '0';
        s_axis_tdata <= (others => '0');
        m_axis_tready <= '1';
        
        wait for 100 ns;
        rst_n <= '1';
        wait for 50 ns;
        en <= '1';
        
        report "Reading input image file: " & INPUT_FILE;
        
        wait until rising_edge(clk_ext);
        wait for CLK_EXT_PERIOD * 5;
        
        report "Starting to send image data to Sobel processor";
        s_axis_tvalid <= '1';
        pixel_index := 0;
        row_count := 0;
        
        while pixel_index < TOTAL_PIXELS loop
            -- Read pixel directly as std_logic_vector
            readline(input_f, input_line);
            read(input_line, pixel_value);
            s_axis_tdata <= pixel_value;
            
            if (pixel_index + 1) mod IMG_WIDTH = 0 then
                s_axis_tlast <= '1';
                row_count := row_count + 1;
            else
                s_axis_tlast <= '0';
            end if;
            
            wait until rising_edge(clk_ext) and s_axis_tready = '1';
            pixel_index := pixel_index + 1;
            
            if pixel_index mod 16384 = 0 then
                report "Sent " & integer'image(pixel_index) & " pixels (" & 
                       integer'image((pixel_index * 100) / TOTAL_PIXELS) & "%), " &
                       integer'image(row_count) & " rows completed";
            end if;
        end loop;
        
        s_axis_tvalid <= '0';
        s_axis_tlast <= '0';
        input_done <= true;
        report "INPUT PROCESS COMPLETED: " & integer'image(TOTAL_PIXELS) & 
               " pixels, " & integer'image(IMG_HEIGHT) & " rows sent";
        
        wait;
    end process;

    -- Output capture process
    output_proc: process
        file output_f : text open write_mode is OUTPUT_FILE;
        variable output_line : line;
        variable output_count : integer := 0;
        variable row_count : integer := 0;
    begin
        report "Starting to receive processed output";
        report "Expected output pixels (with padding): " & integer'image(TOTAL_PIXELS) & " (same as input)";
        
        while output_count < TOTAL_PIXELS and not all_done loop
            if m_axis_tvalid = '1' and m_axis_tready = '1' then
                -- Write pixel directly as std_logic_vector
                write(output_line, m_axis_tdata);
                writeline(output_f, output_line);
                output_count := output_count + 1;
                
                if m_axis_tlast = '1' then
                    row_count := row_count + 1;
                    report "Received tlast - end of row " & integer'image(row_count) & 
                           " (pixel " & integer'image(output_count) & ")";
                end if;
                
                if output_count mod 16384 = 0 then
                    report "Received " & integer'image(output_count) & " pixels (" & 
                           integer'image((output_count * 100) / TOTAL_PIXELS) & "%)" &
                           ", " & integer'image(row_count) & " rows";
                end if;
                
                if output_count >= TOTAL_PIXELS then
                    report "Received complete output frame: " & integer'image(output_count) & " pixels";
                    exit;
                end if;
            end if;
            wait until rising_edge(clk_ext);
        end loop;
        
        report "Writing " & integer'image(output_count) & " pixels to output file: " & OUTPUT_FILE;
        output_done <= true;
        report "OUTPUT PROCESS COMPLETED: " & integer'image(output_count) & 
               " pixels, " & integer'image(row_count) & " rows written to file";
        
        if output_count = TOTAL_PIXELS then
            report "SUCCESS: Output image size matches input (512x512)";
        else
            report "WARNING: Output image size differs from input. Expected: " & 
                   integer'image(TOTAL_PIXELS) & ", Got: " & integer'image(output_count);
        end if;
        
        wait;
    end process;

    -- Safety timeout monitor
    timeout_proc: process
    begin
        wait for TIMEOUT;
        if not all_done then
            report "SIMULATION TIMEOUT: Forcing end after TIMEOUT const time" severity warning;
            std.env.stop;
        end if;
        wait;
    end process;

end Behavioral;