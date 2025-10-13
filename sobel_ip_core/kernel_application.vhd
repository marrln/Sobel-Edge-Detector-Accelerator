-- Applies Sobel Gx and Gy kernels to pixel window
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.MY_TYPES.ALL;

entity kernel_application is
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
end entity kernel_application;

architecture Structural of kernel_application is
    component derivative_1d is
        port (
            clk     : in std_logic;
            rst_n   : in std_logic;
            s_valid : in std_logic;
            s_ready : out std_logic;
            s_last  : in std_logic;
            s_data  : in kernel_window;
            m_valid : out std_logic;
            m_ready : in std_logic;
            m_last  : out std_logic;
            m_data  : out kernel_window
        );
    end component derivative_1d;
    
    component smoother_1d is
        port (
            clk     : in std_logic;
            rst_n   : in std_logic;
            s_valid : in std_logic;
            s_ready : out std_logic;
            s_last  : in std_logic;
            s_data  : in kernel_window;
            m_valid : out std_logic;
            m_ready : in std_logic;
            m_last  : out std_logic;
            m_data  : out kernel_window
        );
    end component smoother_1d;
    
    signal deriv_x_sdata  : kernel_window;
    signal deriv_x_mready : std_logic;
    signal deriv_x_mvalid : std_logic;
    signal deriv_x_mlast  : std_logic;
    signal deriv_x_mdata  : kernel_window;
    signal smooth_x_mdata  : kernel_window;
    
    signal deriv_y_sdata  : kernel_window;
    signal deriv_y_mready : std_logic;
    signal deriv_y_mvalid : std_logic;
    signal deriv_y_mlast  : std_logic;
    signal deriv_y_mdata  : kernel_window;
    signal smooth_y_mdata  : kernel_window;
begin
    deriv_x_sdata(0, 0) <= std_logic_vector(resize(signed(s_data(0, 0)), digits + 3));
    deriv_x_sdata(0, 1) <= std_logic_vector(resize(signed(s_data(1, 0)), digits + 3));
    deriv_x_sdata(0, 2) <= std_logic_vector(resize(signed(s_data(2, 0)), digits + 3));
    deriv_x_sdata(1, 0) <= std_logic_vector(resize(signed(s_data(0, 1)), digits + 3));
    deriv_x_sdata(1, 1) <= std_logic_vector(resize(signed(s_data(1, 1)), digits + 3));
    deriv_x_sdata(1, 2) <= std_logic_vector(resize(signed(s_data(2, 1)), digits + 3));
    
    deriv_y_sdata(0, 0) <= std_logic_vector(resize(signed(s_data(0, 0)), digits + 3));
    deriv_y_sdata(0, 1) <= std_logic_vector(resize(signed(s_data(0, 1)), digits + 3));
    deriv_y_sdata(0, 2) <= std_logic_vector(resize(signed(s_data(0, 2)), digits + 3));
    deriv_y_sdata(1, 0) <= std_logic_vector(resize(signed(s_data(1, 0)), digits + 3));
    deriv_y_sdata(1, 1) <= std_logic_vector(resize(signed(s_data(1, 1)), digits + 3));
    deriv_y_sdata(1, 2) <= std_logic_vector(resize(signed(s_data(1, 2)), digits + 3));
    
    m_data(0, 0) <= smooth_x_mdata(0, 0);
    m_data(0, 1) <= smooth_x_mdata(0, 1);
    m_data(0, 2) <= smooth_x_mdata(0, 2);
    m_data(0, 3) <= smooth_x_mdata(1, 0);
    m_data(0, 4) <= smooth_x_mdata(1, 1);
    m_data(0, 5) <= smooth_x_mdata(1, 2);
    m_data(1, 0) <= smooth_y_mdata(0, 0);
    m_data(1, 1) <= smooth_y_mdata(0, 1);
    m_data(1, 2) <= smooth_y_mdata(0, 2);
    m_data(1, 3) <= smooth_y_mdata(1, 0);
    m_data(1, 4) <= smooth_y_mdata(1, 1);
    m_data(1, 5) <= smooth_y_mdata(1, 2);
    
    Deriv_X : derivative_1d port map (
        clk     => clk,
        rst_n   => rst_n,
        s_valid => s_valid,
        s_ready => s_ready,
        s_last  => s_last,
        s_data  => deriv_x_sdata,
        m_valid => deriv_x_mvalid,
        m_ready => deriv_x_mready,
        m_last  => deriv_x_mlast,
        m_data  => deriv_x_mdata
    );
    
    Deriv_Y : derivative_1d port map (
        clk     => clk,
        rst_n   => rst_n,
        s_valid => s_valid,
        s_ready => open,
        s_last  => s_last,
        s_data  => deriv_y_sdata,
        m_valid => deriv_y_mvalid,
        m_ready => deriv_y_mready,
        m_last  => deriv_y_mlast,
        m_data  => deriv_y_mdata
    );
    
    Smooth_X : smoother_1d port map (
        clk     => clk,
        rst_n   => rst_n,
        s_valid => deriv_x_mvalid,
        s_ready => deriv_x_mready,
        s_last  => deriv_x_mlast,
        s_data  => deriv_x_mdata,
        m_valid => m_valid,
        m_ready => m_ready,
        m_last  => m_last,
        m_data  => smooth_x_mdata
    );
    
    Smooth_Y : smoother_1d port map (
        clk     => clk,
        rst_n   => rst_n,
        s_valid => deriv_y_mvalid,
        s_ready => deriv_y_mready,
        s_last  => deriv_y_mlast,
        s_data  => deriv_y_mdata,
        m_valid => open,
        m_ready => m_ready,
        m_last  => open,
        m_data  => smooth_y_mdata
    );
end Structural;
