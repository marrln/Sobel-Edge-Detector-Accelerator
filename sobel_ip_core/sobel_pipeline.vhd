-- Complete Sobel edge detection pipeline with unified Manhattan norm
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
        m_data  : out std_logic_vector(pixel_width - 1 downto 0)
    );
end sobel_pipeline;

architecture structural of sobel_pipeline is
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
    end component manhattan_norm;
    
    signal kernel_valid : std_logic := '0';
    signal kernel_ready : std_logic := '0';
    signal kernel_last  : std_logic := '0';
    signal kernel_data  : kernel_outputs := (others => (others => (others => '0')));
    
    signal gradient_valid : std_logic := '0';
    signal gradient_ready : std_logic := '0';
    signal gradient_last  : std_logic := '0';
    signal gradient_data  : gradient_pair := (others => (others => '0'));
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
    
    Manhattan_Norm_Stage : manhattan_norm port map (
        clk => clk, rst_n => rst_n, s_valid => gradient_valid, s_ready => gradient_ready,
        s_last => gradient_last, s_data => gradient_data, m_valid => m_valid,
        m_ready => m_ready, m_last => m_last, m_data => m_data
    );
end structural;