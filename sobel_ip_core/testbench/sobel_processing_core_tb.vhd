library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use WORK.MY_TYPES.ALL;

entity sobel_processing_core_tb is
end sobel_processing_core_tb;

architecture behavioral of sobel_processing_core_tb is

    -------------------------------------------------------------------------- 
    -- Constants
    -------------------------------------------------------------------------- 
    constant CLK_PERIOD : time := 10 ns;   -- 100 MHz

    constant INPUT_FILE  : string := "lena_512_512_csv.txt";
    constant OUTPUT_FILE : string := "output_pipeline_lena_512_512_csv.txt";

    constant IMG_WIDTH  : integer := 512;
    constant IMG_HEIGHT : integer := 512;
    constant TOTAL_PIXELS : integer := IMG_WIDTH * IMG_HEIGHT;

    -------------------------------------------------------------------------- 
    -- DUT component
    -------------------------------------------------------------------------- 
    component sobel_processing_core is
        generic (
            rows    : positive := IMG_HEIGHT;
            columns : positive := IMG_WIDTH;
            pixels  : positive := TOTAL_PIXELS
        );
        port (
            clk     : in std_logic;
            rst_n   : in std_logic;
            s_valid : in std_logic;
            s_ready : out std_logic;
            s_last  : in std_logic;
            s_data  : in std_logic_vector(pixel_width - 1 downto 0);
            m_valid : out std_logic;
            m_ready : in std_logic;
            m_last  : out std_logic;
            m_data  : out std_logic_vector(pixel_width - 1 downto 0)
        );
    end component;

    -------------------------------------------------------------------------- 
    -- Signals
    -------------------------------------------------------------------------- 
    signal clk : std_logic := '0';
    signal rst_n : std_logic := '0';
    signal s_valid, s_ready, s_last : std_logic := '0';
    signal m_valid, m_ready, m_last : std_logic := '1';
    signal s_data, m_data : std_logic_vector(pixel_width - 1 downto 0) := (others => '0');

    signal input_done  : boolean := false;
    signal output_done : boolean := false;
    signal all_done    : boolean := false;

    -------------------------------------------------------------------------- 
    -- Procedures
    -------------------------------------------------------------------------- 
    procedure send_pixel(
        signal tdata     : out std_logic_vector(pixel_width - 1 downto 0);
        signal tvalid    : out std_logic;
        signal tlast     : out std_logic;
        signal tready    : in  std_logic;
        variable pixel_val        : in  std_logic_vector(pixel_width - 1 downto 0);
        variable px_index         : in  integer;
        constant IMG_WIDTH        : in  integer
    ) is
        variable wait_cycles : integer := 0;
        constant MAX_WAIT_CYCLES : integer := 200000;
    begin
        -- Wait until ready is asserted before driving valid and data
        wait_cycles := 0;
        while tready /= '1' and wait_cycles < MAX_WAIT_CYCLES loop
            wait until rising_edge(clk);
            wait_cycles := wait_cycles + 1;
            if wait_cycles mod 1000 = 0 then
                report "DEBUG: Waiting for tready before sending pixel " & integer'image(px_index) severity note;
            end if;
        end loop;
        
        if wait_cycles >= MAX_WAIT_CYCLES then
            report "ERROR: Timeout waiting for initial tready for pixel " & integer'image(px_index) severity failure;
            return;
        end if;

        -- Now that tready is '1', drive data and assert valid
        tdata  <= pixel_val;
        if ((px_index + 1) mod IMG_WIDTH) = 0 then
            tlast <= '1';
        else
            tlast <= '0';
        end if;
        tvalid <= '1';

        -- Wait for handshake completion
        wait until rising_edge(clk) and tready = '1';
        
        -- Deassert valid and tlast after successful transfer
        tvalid <= '0';
        tlast  <= '0';
    end procedure;

    procedure receive_pixel(
        signal tdata  : in  std_logic_vector(pixel_width - 1 downto 0);
        signal tvalid : in  std_logic;
        signal tready : out std_logic;
        signal tlast  : in  std_logic;
        variable output_val : out integer
    ) is
        variable wait_cycles : integer := 0;
        constant MAX_WAIT_CYCLES : integer := 200000;
    begin
        -- Assert ready and wait for valid data
        tready <= '1';
        
        wait_cycles := 0;
        while tvalid /= '1' and wait_cycles < MAX_WAIT_CYCLES loop
            wait until rising_edge(clk);
            wait_cycles := wait_cycles + 1;
        end loop;
        
        if wait_cycles >= MAX_WAIT_CYCLES then
            report "ERROR: Timeout waiting for tvalid for output pixel" severity failure;
            tready <= '0';
            return;
        end if;

        -- Capture data on successful handshake
        output_val := to_integer(unsigned(tdata));
        
        -- Wait one cycle then deassert ready
        wait until rising_edge(clk);
        tready <= '0';
    end procedure;
    
begin

    -------------------------------------------------------------------------- 
    -- Clock generation
    -------------------------------------------------------------------------- 
    clk_proc: process
    begin
        while not all_done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        clk <= '0'; wait;
    end process;

    -------------------------------------------------------------------------- 
    -- DUT instantiation
    -------------------------------------------------------------------------- 
    uut: sobel_processing_core
        generic map (
            rows    => IMG_HEIGHT,
            columns => IMG_WIDTH,
            pixels  => TOTAL_PIXELS
        )
        port map (
            clk     => clk,
            rst_n   => rst_n,
            s_valid => s_valid,
            s_ready => s_ready,
            s_last  => s_last,
            s_data  => s_data,
            m_valid => m_valid,
            m_ready => m_ready,
            m_last  => m_last,
            m_data  => m_data
        );

    -------------------------------------------------------------------------- 
    -- Reset
    -------------------------------------------------------------------------- 
    reset_proc: process
    begin
        rst_n <= '0';
        wait for 200 ns;
        rst_n <= '1';
        wait for 200 ns;
        report "Reset released";
        wait;
    end process;
    
    -------------------------------------------------------------------------- 
    -- Input stimulus
    -------------------------------------------------------------------------- 
    stimulus_proc: process
        file input_f : text open read_mode is INPUT_FILE;
        variable L : line;
        variable pix : integer;
        variable pixel_val : std_logic_vector(pixel_width - 1 downto 0);
        variable px_count : integer := 0;
    begin
        s_valid <= '0';
        s_last <= '0';
        s_data <= (others => '0');
        
        -- Wait for reset
        wait until rst_n = '1';
        wait for 500 ns;
        wait until rising_edge(clk);

        report "Starting image transmission...";

        while not endfile(input_f) and px_count < TOTAL_PIXELS loop
            readline(input_f, L);
            read(L, pix);
            pixel_val := std_logic_vector(to_unsigned(pix, pixel_width));

            send_pixel(s_data, s_valid, s_last, s_ready, pixel_val, px_count, IMG_WIDTH);

            px_count := px_count + 1;
            if px_count mod 100000 = 0 then
                report "Sent pixel " & integer'image(px_count) & " = " & integer'image(pix) & 
                       ", ready=" & std_logic'image(s_ready);
            end if;
        end loop;

        file_close(input_f);
        report "INPUT COMPLETE: " & integer'image(px_count) & " pixels sent.";
        input_done <= true;
        wait;
    end process;

    output_proc: process
        file output_f : text open write_mode is OUTPUT_FILE;
        variable L : line;
        variable out_count : integer := 0;
        variable output_val : integer;
        constant TOTAL_OUTPUT_PIXELS : integer := (IMG_WIDTH - 2) * (IMG_HEIGHT - 2);
    begin
        wait until rst_n = '1';
        wait for 100 us;  -- Wait for pipeline to start producing outputs
        wait until rising_edge(clk);
        
        report "Starting output capture...";
        loop
            receive_pixel(m_data, m_valid, m_ready, m_last, output_val);
            write(L, output_val);
            writeline(output_f, L);
            out_count := out_count + 1;
            
            if out_count mod 100000 = 0 then
                report "Received pixel " & integer'image(out_count) & " = " & integer'image(output_val);
            end if;
        end loop;

        file_close(output_f);
        report "OUTPUT COMPLETE: " & integer'image(out_count) & " pixels written.";
        output_done <= true;
        wait;
    end process;

    -------------------------------------------------------------------------- 
    -- Simulation control
    -------------------------------------------------------------------------- 
    sim_control_proc: process
    begin
        wait until (input_done and output_done);
        report "SIMULATION COMPLETED";
        all_done <= true;
        wait for 200 ns;
        std.env.stop;
        wait;
    end process;

end architecture behavioral;