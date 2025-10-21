-- AXI4-Stream Sobel processing core: scaler -> window buffer -> kernel application -> manhattan norm
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.MY_TYPES.ALL;

entity sobel_processing_core is
    generic (
        rows    : positive := image_rows;
        columns : positive := image_columns;
        pixels  : positive := image_rows * image_columns
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
            rows    : positive := image_rows;
            columns : positive := image_columns;
            pixels  : positive := image_rows * image_columns
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

    component kernel_application is
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
            m_data  : out gradient_pair
        );
    end component;

    component manhattan_norm is
        port (
            clk     : in std_logic;
            rst_n   : in std_logic;
            s_valid : in std_logic;
            s_ready : out std_logic;
            s_last  : in std_logic;
            s_data  : in gradient_pair;
            m_valid : out std_logic;
            m_ready : in std_logic;
            m_last  : out std_logic;
            m_data  : out std_logic_vector(pixel_width - 1 downto 0)
        );
    end component;

    -- Inter-stage signals between pipeline components
    signal scaled_data  : std_logic_vector(pixel_width - 1 downto 0);
    signal scaled_ready : std_logic;
    signal scaled_valid : std_logic;
    signal scaled_last  : std_logic;
    
    signal window_data  : pixel_window;
    signal kernel_ready : std_logic;
    signal kernel_valid : std_logic;
    signal kernel_last  : std_logic;
    
    signal kernel_data  : gradient_pair;
    signal norm_ready   : std_logic;
    signal norm_valid   : std_logic;
    signal norm_last    : std_logic;
    
begin
    div4_scaler : scaler
        port map (
            clk => clk, rst_n => rst_n, 
            s_valid => s_valid, s_ready => s_ready,
            s_last => s_last, s_data => s_data, 
            m_valid => scaled_valid, m_ready => scaled_ready, 
            m_last => scaled_last, m_data => scaled_data
        );
    
    window_producer_buffer : window_buffer
        generic map (rows => rows, columns => columns, pixels => pixels)
        port map (
            clk => clk, rst_n => rst_n, 
            s_valid => scaled_valid, s_ready => scaled_ready,
            s_last => scaled_last, s_data => scaled_data, 
            m_valid => kernel_valid, m_ready => kernel_ready, 
            m_last => kernel_last, m_data => window_data
        );
    
    kernel_convolution : kernel_application
        port map (
            clk => clk, rst_n => rst_n, 
            s_valid => kernel_valid, s_ready => kernel_ready,
            s_last => kernel_last, s_data => window_data, 
            m_valid => norm_valid, m_ready => norm_ready, 
            m_last => norm_last, m_data => kernel_data
        );
    
    magnitude_calculation : manhattan_norm
        port map (
            clk => clk, rst_n => rst_n, 
            s_valid => norm_valid, s_ready => norm_ready,
            s_last => norm_last, s_data => kernel_data, 
            m_valid => m_valid, m_ready => m_ready, 
            m_last => m_last, m_data => m_data
        );
end structural;