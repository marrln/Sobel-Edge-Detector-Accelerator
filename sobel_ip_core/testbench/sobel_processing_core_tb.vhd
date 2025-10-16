library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library std;
use std.textio.all;
use WORK.MY_TYPES.ALL;

entity sobel_processing_core_tb is
end entity sobel_processing_core_tb;

architecture behavioral of sobel_processing_core_tb is

    --------------------------------------------------------------------------
    -- Constants
    --------------------------------------------------------------------------
    constant CLK_PERIOD : time := 10 ns;   -- 100 MHz

    constant INPUT_FILE  : string := "lena_512_512_csv.txt";
    constant OUTPUT_FILE : string := "output_hw_lena_512_512_csv.txt";

    constant IMG_WIDTH  : integer := 512;
    constant IMG_HEIGHT : integer := 512;
    constant TOTAL_PIXELS : integer := IMG_WIDTH * IMG_HEIGHT;
    constant OUTPUT_PIXELS : integer := 510 * 510;
    
    constant SEND_TIMEOUT : time := 100 us;
    constant RECEIVE_TIMEOUT : time := 200 us;

    --------------------------------------------------------------------------
    -- Component Declaration
    --------------------------------------------------------------------------
    component sobel_processing_core is
        generic (
            rows    : positive := 512;
            columns : positive := 512;
            pixels  : positive := 512 * 512
        );
        port (
            clk     : in std_logic;
            rst_n   : in std_logic;
            s_data  : in std_logic_vector(pixel_width - 1 downto 0);
            s_valid : in std_logic;
            s_ready : out std_logic;
            s_last  : in std_logic;
            m_data  : out std_logic_vector(pixel_width - 1 downto 0);
            m_valid : out std_logic;
            m_ready : in std_logic;
            m_last  : out std_logic
        );
    end component;

    --------------------------------------------------------------------------
    -- Signals
    --------------------------------------------------------------------------
    signal clk      : std_logic := '0';
    signal rst_n    : std_logic := '0';
    
    -- Input AXI4-Stream signals
    signal s_data   : std_logic_vector(pixel_width - 1 downto 0) := (others => '0');
    signal s_valid  : std_logic := '0';
    signal s_ready  : std_logic;
    signal s_last   : std_logic := '0';
    
    -- Output AXI4-Stream signals
    signal m_data   : std_logic_vector(pixel_width - 1 downto 0);
    signal m_valid  : std_logic;
    signal m_ready  : std_logic := '0';
    signal m_last   : std_logic;
    
    -- Testbench control signals
    signal sim_ended : boolean := false;
    signal pixels_sent : integer := 0;
    signal pixels_received : integer := 0;
    signal start_time : time;
    signal end_time : time;

    file input_f : text;
    file output_f : text;

begin

    --------------------------------------------------------------------------
    -- DUT Instantiation
    --------------------------------------------------------------------------
    dut : sobel_processing_core
        generic map (
            rows    => IMG_HEIGHT,
            columns => IMG_WIDTH,
            pixels  => TOTAL_PIXELS
        )
        port map (
            clk     => clk,
            rst_n   => rst_n,
            s_data  => s_data,
            s_valid => s_valid,
            s_ready => s_ready,
            s_last  => s_last,
            m_data  => m_data,
            m_valid => m_valid,
            m_ready => m_ready,
            m_last  => m_last
        );

    --------------------------------------------------------------------------
    -- Clock Generation
    --------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD/2 when not sim_ended else '0';

    --------------------------------------------------------------------------
    -- Reset Process
    --------------------------------------------------------------------------
    reset_process : process
    begin
        rst_n <= '0';
        wait for CLK_PERIOD * 5;
        rst_n <= '1';
        wait;
    end process reset_process;

    --------------------------------------------------------------------------
    -- Stimulus Process: Read from file and send to DUT
    --------------------------------------------------------------------------
    stimulus_process : process
        variable file_line  : line;
        variable pixel_val  : integer;
        variable line_count : integer := 0;
        variable timeout_start : time;
    begin
        -- Wait for reset to complete
        wait until rst_n = '1';
        wait until rising_edge(clk);
        
        report "Starting stimulus process at time " & time'image(now);
        start_time <= now;
        
        -- Open input file
        file_open(input_f, INPUT_FILE, read_mode);
        
        -- Send all pixels
        while not endfile(input_f) and line_count < TOTAL_PIXELS loop
            readline(input_f, file_line);
            read(file_line, pixel_val);
            
            -- Simple handshake without procedure
            s_data <= std_logic_vector(to_unsigned(pixel_val, pixel_width));
            s_valid <= '1';
            if line_count = TOTAL_PIXELS - 1 then
                s_last <= '1';
            else
                s_last <= '0';
            end if;
            
            -- Wait for ready with timeout
            timeout_start := now;
            while s_ready = '0' loop
                wait until rising_edge(clk);
                if (now - timeout_start) > SEND_TIMEOUT then
                    report "Send timeout at pixel " & integer'image(line_count) 
                           & " at time " & time'image(now) severity warning;
                    exit;
                end if;
            end loop;
            
            -- Complete transaction
            wait until rising_edge(clk);
            s_valid <= '0';
            s_last <= '0';
            
            pixels_sent <= line_count + 1;
            line_count := line_count + 1;
            
            -- Small delay between pixels to simulate realistic data rate
            wait for CLK_PERIOD;
        end loop;
        
        file_close(input_f);
        
        if line_count = TOTAL_PIXELS then
            report "Successfully sent all " & integer'image(TOTAL_PIXELS) & " input pixels";
        else
            -- report "Sent " & integer'image(line_count) & " out of " & integer'image(TOTAL_PIXELS) & " pixels";
        end if;
        
        wait;
    end process stimulus_process;

    --------------------------------------------------------------------------
    -- Output Process: Receive from DUT and write to file
    --------------------------------------------------------------------------
    output_process : process
        variable file_line  : line;
        variable pixel_val  : integer;
        variable timeout_start : time;
        variable pixel_count : integer := 0;
    begin
        -- Wait for reset to complete
        wait until rst_n = '1';
        wait until rising_edge(clk);
        
        report "Starting output process at time " & time'image(now);
        
        -- Open output file
        file_open(output_f, OUTPUT_FILE, write_mode);
        
        -- Receive all output pixels
        while pixel_count < OUTPUT_PIXELS loop
            -- Simple handshake without procedure
            m_ready <= '1';
            
            -- Wait for valid with timeout
            timeout_start := now;
            while m_valid = '0' loop
                wait until rising_edge(clk);
                if (now - timeout_start) > RECEIVE_TIMEOUT then
                    report "Receive timeout at pixel " & integer'image(pixel_count) 
                           & " at time " & time'image(now) severity warning;
                    m_ready <= '0';
                    exit;
                end if;
            end loop;
            
            -- Capture data
            pixel_val := to_integer(unsigned(m_data));
            
            -- Write to file
            write(file_line, pixel_val);
            writeline(output_f, file_line);
            
            -- Check for last signal
            if m_last = '1' then
                report "Received m_last signal at pixel " & integer'image(pixel_count);
            end if;
            
            -- Complete transaction
            wait until rising_edge(clk);
            m_ready <= '0';
            
            pixels_received <= pixel_count + 1;
            pixel_count := pixel_count + 1;
            
            if pixel_count >= OUTPUT_PIXELS then
                exit;
            end if;
        end loop;
        
        file_close(output_f);
        end_time <= now;
        
        if pixel_count = OUTPUT_PIXELS then
            report "Successfully received all " & integer'image(OUTPUT_PIXELS) & " output pixels";
        else
            report "Received " & integer'image(pixel_count) & " out of " & integer'image(OUTPUT_PIXELS) & " pixels";
        end if;
        
        -- End simulation
        wait for CLK_PERIOD * 10;
        sim_ended <= true;
        wait;
    end process output_process;

    --------------------------------------------------------------------------
    -- Debug Process: Report statistics
    --------------------------------------------------------------------------
    debug_process : process
        variable last_sent_count : integer := 0;
        variable last_received_count : integer := 0;
        variable sent_rate : integer;
        variable received_rate : integer;
    begin
        wait until rst_n = '1';
        wait until rising_edge(clk);
        
        while not sim_ended loop
            -- Calculate rates (pixels per us)
            sent_rate := (pixels_sent - last_sent_count);
            received_rate := (pixels_received - last_received_count);
            
            last_sent_count := pixels_sent;
            last_received_count := pixels_received;
            
            report "Debug - Sent: " & integer'image(pixels_sent) & 
                   "/" & integer'image(TOTAL_PIXELS) & 
                   " (" & integer'image(sent_rate) & " px/us), " &
                   "Received: " & integer'image(pixels_received) & 
                   "/" & integer'image(OUTPUT_PIXELS) & 
                   " (" & integer'image(received_rate) & " px/us), " &
                   "Time: " & time'image(now - start_time);
            
            -- Report every 5000 ns (not too frequently)
            wait for 10000 ns;
        end loop;
        
        -- Final report
        report "Simulation completed:";
        report "  Input pixels sent: " & integer'image(pixels_sent) & "/" & integer'image(TOTAL_PIXELS);
        report "  Output pixels received: " & integer'image(pixels_received) & "/" & integer'image(OUTPUT_PIXELS);
        report "  Total simulation time: " & time'image(end_time - start_time);
        if end_time > start_time then
            report "  Average throughput: " & real'image(real(pixels_received) / (real((end_time - start_time) / 1 us))) & " pixels/us";
        end if;
        
        wait;
    end process debug_process;

end architecture behavioral;