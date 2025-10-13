-- Complete Sobel edge detection pipeline
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.MY_TYPES.ALL;

entity sobel_pipeline is
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
        m_data  : out std_logic_vector(digits - 1 downto 0)
    );
end entity sobel_pipeline;

architecture Structural of sobel_pipeline is
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
            m_data  : out kernel_outputs
        );
    end component kernel_application;
    
    component gradient_adder_tree is
        port (
            clk     : in std_logic;
            rst_n   : in std_logic;
            s_valid : in std_logic;
            s_ready : out std_logic;
            s_last  : in std_logic;
            s_data  : in kernel_outputs;
            m_valid : out std_logic;
            m_ready : in std_logic;
            m_last  : out std_logic;
            m_data  : out gradient_pair
        );
    end component gradient_adder_tree;
    
    component gradient_magnitude is
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
            m_data  : out gradient_pair
        );
    end component gradient_magnitude;
    
    component magnitude_adder is
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
            m_data  : out std_logic_vector(digits - 1 downto 0)
        );
    end component magnitude_adder;
    
    signal kernel_valid : std_logic;
    signal kernel_ready : std_logic;
    signal kernel_last  : std_logic;
    signal kernel_data  : kernel_outputs;
    
    signal gradient_valid : std_logic;
    signal gradient_ready : std_logic;
    signal gradient_last  : std_logic;
    signal gradient_data  : gradient_pair;
    
    signal abs_gradient_valid : std_logic;
    signal abs_gradient_ready : std_logic;
    signal abs_gradient_last  : std_logic;
    signal abs_gradient_data  : gradient_pair;
begin
    Kernel_Conv_Stage : kernel_application port map (
        clk => clk, rst_n => rst_n, s_valid => s_valid, s_ready => s_ready,
        s_last => s_last, s_data => s_data, m_valid => kernel_valid,
        m_ready => kernel_ready, m_last => kernel_last, m_data => kernel_data
    );
    
    Gradient_Sum_Stage : gradient_adder_tree port map (
        clk => clk, rst_n => rst_n, s_valid => kernel_valid, s_ready => kernel_ready,
        s_last => kernel_last, s_data => kernel_data, m_valid => gradient_valid,
        m_ready => gradient_ready, m_last => gradient_last, m_data => gradient_data
    );
    
    Gradient_Abs_Stage : gradient_magnitude port map (
        clk => clk, rst_n => rst_n, s_valid => gradient_valid, s_ready => gradient_ready,
        s_last => gradient_last, s_data => gradient_data, m_valid => abs_gradient_valid,
        m_ready => abs_gradient_ready, m_last => abs_gradient_last, m_data => abs_gradient_data
    );
    
    Magnitude_Combine_Stage : magnitude_adder port map (
        clk => clk, rst_n => rst_n, s_valid => abs_gradient_valid, s_ready => abs_gradient_ready,
        s_last => abs_gradient_last, s_data => abs_gradient_data, m_valid => m_valid,
        m_ready => m_ready, m_last => m_last, m_data => m_data
    );
end Structural;
