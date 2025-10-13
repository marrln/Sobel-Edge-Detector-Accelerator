-- Second stage Sobel convolution: multiplies by [1, 2, 1]
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.MY_TYPES.ALL;

entity smoother_1d is
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
end entity smoother_1d;

architecture Behavioral of smoother_1d is
begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            s_ready      <= '0';
            m_valid      <= '0';
            m_last       <= '0';
            m_data(0, 0) <= (others => '0');
            m_data(0, 1) <= (others => '0');
            m_data(0, 2) <= (others => '0');
            m_data(1, 0) <= (others => '0');
            m_data(1, 1) <= (others => '0');
            m_data(1, 2) <= (others => '0');
        elsif rising_edge(clk) then
            s_ready <= m_ready;
            m_valid <= s_valid;
            m_last  <= s_last;
            if m_ready = '1' then
                m_data(0, 0) <= s_data(0, 0);
                m_data(0, 1) <= std_logic_vector(shift_left(signed(s_data(0, 1)), 1));
                m_data(0, 2) <= s_data(0, 2);
                m_data(1, 0) <= s_data(1, 0);
                m_data(1, 1) <= std_logic_vector(shift_left(signed(s_data(1, 1)), 1));
                m_data(1, 2) <= s_data(1, 2);
            end if;
        end if;
    end process;
end Behavioral;
