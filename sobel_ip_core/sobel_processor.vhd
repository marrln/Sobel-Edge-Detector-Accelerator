-- Main Sobel processor with dual-clock FIFOs and counters
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use WORK.MY_TYPES.ALL;

entity sobel_processor is
    generic (
        rows    : positive := 480;
        columns : positive := 640;
        pixels  : positive := 307200
    );
    port (
        clk_int          : in std_logic;
        clk_ext          : in std_logic;
        rst_n            : in std_logic;
        en               : in std_logic;
        s_axis_tvalid    : in std_logic;
        s_axis_tready    : out std_logic;
        s_axis_tlast     : in std_logic;
        s_axis_tdata     : in std_logic_vector(digits - 1 downto 0);
        m_axis_tvalid    : out std_logic;
        m_axis_tready    : in std_logic;
        m_axis_tlast     : out std_logic;
        m_axis_tdata     : out std_logic_vector(digits - 1 downto 0);
        input_pixel_cnt  : out std_logic_vector(31 downto 0);
        output_pixel_cnt : out std_logic_vector(31 downto 0);
        cycle_cnt        : out std_logic_vector(31 downto 0)
    );
end entity sobel_processor;

architecture Structural of sobel_processor is
    signal s_valid : std_logic;
    signal s_ready : std_logic;
    signal s_last  : std_logic;
    signal s_data  : std_logic_vector(digits - 1 downto 0);
    
    signal m_valid : std_logic;
    signal m_ready : std_logic;
    signal m_last  : std_logic;
    signal m_data  : std_logic_vector(digits - 1 downto 0);
    
    -- signal fin_data  : std_logic_vector(digits - 1 downto 0);
    -- signal fin_ready : std_logic;
    -- signal fin_valid : std_logic;
    -- signal fin_last  : std_logic;
    
    -- signal fout_data  : std_logic_vector(digits - 1 downto 0);
    -- signal fout_ready : std_logic;
    -- signal fout_valid : std_logic;
    -- signal fout_last  : std_logic;
    
    signal input_pixel_cnt_en  : std_logic;
    signal output_pixel_cnt_en : std_logic;
    signal sobel_rst_n         : std_logic;
begin
    s_valid           <= s_axis_tvalid;
    s_axis_tready     <= s_ready;
    s_last            <= s_axis_tlast;
    s_data            <= s_axis_tdata;
    
    m_axis_tvalid     <= m_valid;
    m_ready           <= m_axis_tready;
    m_axis_tlast      <= m_last;
    m_axis_tdata      <= m_data;
    
    input_pixel_cnt_en  <= s_valid and s_ready;
    output_pixel_cnt_en <= m_valid and m_ready;
    sobel_rst_n         <= rst_n and en;
    
    Input_Pixel_Counter : entity work.pixel_counter
        port map (
            clk => clk_ext, rst_n => sobel_rst_n, s_valid => input_pixel_cnt_en,
            s_last => s_last, m_data => input_pixel_cnt
        );
    
    Sobel_Edge_Filter : entity work.top_level_module
        generic map (rows => rows, columns => columns, pixels => pixels)
        port map (
            clk => clk_int, rst_n => sobel_rst_n, s_valid => s_valid,
            s_ready => s_ready, s_last => s_last, s_data => s_data,
            m_valid => m_valid, m_ready => m_ready, m_last => m_last,
            m_data => m_data
        );
    
    Output_Pixel_Counter : entity work.pixel_counter
        port map (
            clk => clk_ext, rst_n => sobel_rst_n, s_valid => output_pixel_cnt_en,
            s_last => m_last, m_data => output_pixel_cnt
        );
    
    Cycle_Counter : entity work.cycle_counter
        port map (
            clk => clk_ext, rst_n => sobel_rst_n, s_valid => input_pixel_cnt_en,
            s_last => m_last, m_data => cycle_cnt
        );
end Structural;
