library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use WORK.MY_TYPES.ALL;

entity sobel_accelerator_tb is
end sobel_accelerator_tb;

architecture behavioral of sobel_accelerator_tb is

    --------------------------------------------------------------------------
    -- Constants
    --------------------------------------------------------------------------
    constant CLK_INT_PERIOD : time := 5 ns;   -- 200 MHz
    constant CLK_EXT_PERIOD : time := 10 ns;  -- 100 MHz

    constant INPUT_FILE  : string := "C:/temp/sobel_work/lena_512_512_csv.txt";
    constant OUTPUT_FILE : string := "C:/temp/sobel_work/output_hw_lena_512_512_csv.txt";

    constant IMG_WIDTH  : integer := 512;
    constant IMG_HEIGHT : integer := 512;
    constant TOTAL_PIXELS : integer := IMG_WIDTH * IMG_HEIGHT;
    constant OUTPUT_PIXELS : integer := (IMG_WIDTH - 2) * (IMG_HEIGHT - 2);

    -------------------------------------------------------------------------- 
    -- DUT component
    -------------------------------------------------------------------------- 
    component sobel_accelerator is
        generic (
            rows       : positive := image_rows;
            columns    : positive := image_columns;
            pixels     : positive := image_rows * image_columns;
            fifo_depth : positive := fifo_depth
        );
        port (
            clk_int          : in  std_logic;
            clk_ext          : in  std_logic;
            rst_n            : in  std_logic;
            en               : in  std_logic;
            s_axis_tvalid    : in  std_logic;
            s_axis_tready    : out std_logic;
            s_axis_tlast     : in  std_logic;
            s_axis_tdata     : in  std_logic_vector(pixel_width - 1 downto 0);
            m_axis_tvalid    : out std_logic;
            m_axis_tready    : in  std_logic;
            m_axis_tlast     : out std_logic;
            m_axis_tdata     : out std_logic_vector(pixel_width - 1 downto 0);
            input_pixel_cnt  : out std_logic_vector(31 downto 0);
            output_pixel_cnt : out std_logic_vector(31 downto 0);
            cycle_cnt        : out std_logic_vector(31 downto 0)
        );
    end component;    --------------------------------------------------------------------------
    -- Signals
    --------------------------------------------------------------------------
    signal clk_int, clk_ext : std_logic := '0';
    signal rst_n, en        : std_logic := '0';
    signal s_axis_tvalid, s_axis_tready, s_axis_tlast : std_logic := '0';
    signal m_axis_tvalid, m_axis_tready, m_axis_tlast : std_logic := '0';
    signal s_axis_tdata, m_axis_tdata : std_logic_vector(pixel_width - 1 downto 0) := (others => '0');
    signal input_pixel_cnt, output_pixel_cnt, cycle_cnt : std_logic_vector(31 downto 0) := (others => '0');

    signal input_done  : boolean := false;
    signal output_done : boolean := false;
    signal all_done    : boolean := false;

begin
    clk_int_proc: process
    begin
        while not all_done loop
            clk_int <= '0'; wait for CLK_INT_PERIOD/2;
            clk_int <= '1'; wait for CLK_INT_PERIOD/2;
        end loop;
        clk_int <= '0'; wait;
    end process;

    clk_ext_proc: process
    begin
        while not all_done loop
            clk_ext <= '0'; wait for CLK_EXT_PERIOD/2;
            clk_ext <= '1'; wait for CLK_EXT_PERIOD/2;
        end loop;
        clk_ext <= '0'; wait;
    end process;

    -------------------------------------------------------------------------- 
    -- DUT instantiation
    -------------------------------------------------------------------------- 
    uut: sobel_accelerator
        generic map (
            rows       => IMG_HEIGHT,
            columns    => IMG_WIDTH,
            pixels     => TOTAL_PIXELS,
            fifo_depth => fifo_depth
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
        );    --------------------------------------------------------------------------
    -- Reset and enable
    --------------------------------------------------------------------------
    reset_enable_proc: process
    begin
        rst_n <= '0'; 
        en <= '0';
        wait for 200 ns;
        rst_n <= '1';
        wait for 200 ns;
        en <= '1';
        wait for 200 ns;
        report "Reset released and DUT enabled";
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
        s_axis_tvalid <= '0';
        s_axis_tlast <= '0';
        s_axis_tdata <= (others => '0');
        
        -- Wait for reset and enable to be stable
        wait until rst_n = '1' and en = '1';
        wait for 500 ns;  -- Additional wait for DUT to initialize
        wait until rising_edge(clk_ext);

        report "Starting image transmission...";

        while not endfile(input_f) and px_count < TOTAL_PIXELS loop
            readline(input_f, L);
            read(L, pix);
            pixel_val := std_logic_vector(to_unsigned(pix, pixel_width));

            s_axis_tdata <= pixel_val;
            s_axis_tvalid <= '1';
            if s_axis_tready = '1' then
                px_count := px_count + 1;
                if px_count <= 10 or px_count mod 10000 = 0 then
                    report "Sent pixel " & integer'image(px_count) & " = " & integer'image(pix) & 
                            ", tready=" & std_logic'image(s_axis_tready);
                end if;
            end if;
            wait until rising_edge(clk_ext);
        end loop;

        s_axis_tvalid <= '0';
        file_close(input_f);
        report "INPUT COMPLETE: " & integer'image(px_count) & " pixels sent.";
        input_done <= true;
        wait;
    end process;

    --------------------------------------------------------------------------
    -- Output capture
    --------------------------------------------------------------------------
    output_proc: process
        file output_f : text open write_mode is OUTPUT_FILE;
        variable L : line;
        variable out_count : integer := 0;
        variable pixel_val : std_logic_vector(pixel_width - 1 downto 0);
    begin
        m_axis_tready <= '1';  -- Always ready to receive

        -- Wait for reset and enable to be stable
        wait until rst_n = '1' and en = '1';
        wait for 500 ns;  -- Additional wait for DUT to initialize
        wait until rising_edge(clk_ext);

        report "Waiting for output...";

        while out_count < OUTPUT_PIXELS loop
            if m_axis_tvalid = '1' then
                pixel_val := m_axis_tdata;
                write(L, to_integer(unsigned(pixel_val)));
                writeline(output_f, L);
                out_count := out_count + 1;
                if out_count <= 10 or out_count mod 10000 = 0 then
                    report "Received pixel " & integer'image(out_count) & " = " & integer'image(to_integer(unsigned(pixel_val))) & 
                            ", tvalid=" & std_logic'image(m_axis_tvalid);
                end if;
            end if;
            wait until rising_edge(clk_ext);
        end loop;

        file_close(output_f);
        report "OUTPUT COMPLETE: " & integer'image(out_count) & " pixels received.";
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
        report "  Input pixels processed:  " & integer'image(to_integer(unsigned(input_pixel_cnt)));
        report "  Output pixels generated: " & integer'image(to_integer(unsigned(output_pixel_cnt)));
        report "  Total cycles: " & integer'image(to_integer(unsigned(cycle_cnt)));
        all_done <= true;
        wait for 200 ns;
        std.env.stop;
        wait;
    end process;

    --------------------------------------------------------------------------
    -- Debug monitor
    --------------------------------------------------------------------------
    debug_monitor: process
        variable input_handshakes : integer := 0;
        variable output_handshakes : integer := 0;
        variable last_report_time : time := 0 ns;
        variable local_output_val : integer;
    begin
        while not all_done loop
            wait until rising_edge(clk_ext);

            -- Input handshake
            if s_axis_tvalid = '1' and s_axis_tready = '1' then
                input_handshakes := input_handshakes + 1;
                -- report "INPUT HANDSHAKE " & integer'image(input_handshakes) &
                --        ": Value=" & integer'image(to_integer(unsigned(s_axis_tdata))) &
                --        ", TLAST=" & std_logic'image(s_axis_tlast);
            end if;

            -- Output handshake
            if m_axis_tvalid = '1' and m_axis_tready = '1' then
                output_handshakes := output_handshakes + 1;
                local_output_val := to_integer(unsigned(m_axis_tdata));
                -- report "OUTPUT HANDSHAKE " & integer'image(output_handshakes) &
                --        ": Value=" & integer'image(local_output_val) &
                --        ", TLAST=" & std_logic'image(m_axis_tlast);
            end if;

            -- periodic probe, every 100 us
            -- if now - last_report_time >= 100 us then
            --     report "PROBE: s_valid=" & std_logic'image(s_axis_tvalid) &
            --         ", s_ready=" & std_logic'image(s_axis_tready) &
            --         ", m_valid=" & std_logic'image(m_axis_tvalid) &
            --         ", m_ready=" & std_logic'image(m_axis_tready);
            --     last_report_time := now;
            -- end if;

        end loop;

        report "DEBUG MONITOR FINISHED: " & 
               integer'image(input_handshakes) & " input handshakes, " &
               integer'image(output_handshakes) & " output handshakes";
        wait;
    end process;
end behavioral;