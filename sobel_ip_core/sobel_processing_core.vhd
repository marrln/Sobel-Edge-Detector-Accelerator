-- AXI4-Stream Sobel processing core: scaler -> window buffer -> sobel pipeline
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use WORK.MY_TYPES.ALL;

entity sobel_processing_core is
    generic (
        rows    : positive := 512;
        columns : positive := 512;
        pixels  : positive := rows * columns
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
end entity sobel_processing_core;

architecture structural of sobel_processing_core is
    component scaler is
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

    component window_buffer is
        generic (
            rows    : positive := 512;
            columns : positive := 512;
            pixels  : positive := rows * columns
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
            m_data  : out pixel_window
        );
    end component;

    component sobel_pipeline is
        port (
            clk     : in std_logic;
            rst_n   : in std_logic;
            s_valid : in std_logic;
            s_ready : out std_logic;
            s_last  : in std_logic;
            s_data  : in pixel_window;
            m_valid : out std_logic;
            m_ready : in std_logic;
            m_last  : out std_logic;
            m_data  : out std_logic_vector(pixel_width - 1 downto 0)
        );
    end component;

    signal scaled_data  : std_logic_vector(pixel_width - 1 downto 0);
    signal scaled_ready : std_logic;
    signal scaled_valid : std_logic;
    signal scaled_last  : std_logic;
    
    signal window_data  : pixel_window;
    signal window_ready : std_logic;
    signal window_valid : std_logic;
    signal window_last  : std_logic;
begin
    Div4_Scaler : scaler
        port map (
            clk => clk, rst_n => rst_n, 
            s_valid => s_valid, s_ready => s_ready,
            s_last => s_last, s_data => s_data, 
            m_valid => scaled_valid, m_ready => scaled_ready, 
            m_last => scaled_last, m_data => scaled_data
        );
    
    Window_Producer_Buffer : window_buffer
        generic map (rows => rows, columns => columns, pixels => pixels)
        port map (
            clk => clk, rst_n => rst_n, 
            s_valid => scaled_valid, s_ready => scaled_ready,
            s_last => scaled_last, s_data => scaled_data, 
            m_valid => window_valid, m_ready => window_ready, 
            m_last => window_last, m_data => window_data
        );
    
    Sobel_Pipeline : sobel_pipeline
        port map (
            clk => clk, rst_n => rst_n, 
            s_valid => window_valid, s_ready => window_ready,
            s_last => window_last, s_data => window_data, 
            m_valid => m_valid, m_ready => m_ready, 
            m_last => m_last, m_data => m_data
        );
end architecture structural;