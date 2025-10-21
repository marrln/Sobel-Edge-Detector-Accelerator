-- Combined telemetry unit for Sobel accelerator statistics
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sobel_statistics is
    port (
        -- Clock domains
        clk_ext          : in std_logic;
        clk_int          : in std_logic;
        rst_n            : in std_logic;
        
        -- Input interface monitoring (clk_ext domain)
        s_axis_tvalid    : in std_logic;
        s_axis_tready    : in std_logic;
        s_axis_tlast     : in std_logic;
        
        -- Output interface monitoring (clk_ext domain)  
        m_axis_tvalid    : in std_logic;
        m_axis_tready    : in std_logic;
        m_axis_tlast     : in std_logic;
        
        -- Internal processing monitoring (clk_int domain)
        proc_s_valid     : in std_logic;
        proc_s_ready     : in std_logic;
        
        -- Telemetry outputs (synchronized to clk_ext)
        input_pixel_cnt  : out std_logic_vector(31 downto 0);
        output_pixel_cnt : out std_logic_vector(31 downto 0);
        cycle_cnt        : out std_logic_vector(31 downto 0)
    );
end sobel_statistics;

architecture Behavioral of sobel_statistics is
    -- Input counter signals (clk_ext domain)
    signal input_counter  : unsigned(31 downto 0);
    signal input_handshake : std_logic;
    
    -- Output counter signals (clk_ext domain)
    signal output_counter : unsigned(31 downto 0);
    signal output_handshake : std_logic;
    
    -- Cycle counter signals (clk_int domain)
    signal cycle_counter  : unsigned(31 downto 0);
    signal cycle_counter_sync : std_logic_vector(31 downto 0);
    
    -- CDC synchronization signals
    signal cycle_counter_int : std_logic_vector(31 downto 0);
    signal sync_stage1 : std_logic_vector(31 downto 0);
    signal sync_stage2 : std_logic_vector(31 downto 0);

begin
    -- Handshake detection
    input_handshake  <= s_axis_tvalid and s_axis_tready;
    output_handshake <= m_axis_tvalid and m_axis_tready;

    ------------------------------------------------------------------
    -- Input Pixel Counter (clk_ext domain)
    ------------------------------------------------------------------
    process(clk_ext, rst_n)
    begin
        if rst_n = '0' then
            input_counter <= (others => '0');
        elsif rising_edge(clk_ext) then
            if input_handshake = '1' then
                input_counter <= input_counter + 1;
            end if;
        end if;
    end process;
    input_pixel_cnt <= std_logic_vector(input_counter);

    ------------------------------------------------------------------
    -- Output Pixel Counter (clk_ext domain)
    ------------------------------------------------------------------
    process(clk_ext, rst_n)
    begin
        if rst_n = '0' then
            output_counter <= (others => '0');
        elsif rising_edge(clk_ext) then
            if output_handshake = '1' then
                output_counter <= output_counter + 1;
            end if;
        end if;
    end process;
    output_pixel_cnt <= std_logic_vector(output_counter);

    ------------------------------------------------------------------
    -- Cycle Counter (clk_int domain) - counts processing cycles
    ------------------------------------------------------------------
    process(clk_int, rst_n)
    begin
        if rst_n = '0' then
            cycle_counter <= (others => '0');
        elsif rising_edge(clk_int) then
            -- Count cycles when processing is active (backpressure handled)
            if proc_s_valid = '1' or proc_s_ready = '1' then
                cycle_counter <= cycle_counter + 1;
            end if;
        end if;
    end process;
    cycle_counter_int <= std_logic_vector(cycle_counter);

    ------------------------------------------------------------------
    -- Clock Domain Crossing: clk_int ? clk_ext
    ------------------------------------------------------------------
    process(clk_ext, rst_n)
    begin
        if rst_n = '0' then
            sync_stage1 <= (others => '0');
            sync_stage2 <= (others => '0');
            cycle_cnt <= (others => '0');
        elsif rising_edge(clk_ext) then
            -- Two-stage synchronizer for safe CDC
            sync_stage1 <= cycle_counter_int;
            sync_stage2 <= sync_stage1;
            cycle_cnt <= sync_stage2;
        end if;
    end process;

end Behavioral;