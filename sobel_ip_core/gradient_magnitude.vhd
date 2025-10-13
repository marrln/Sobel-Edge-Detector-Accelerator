-- Computes absolute values of Gx and Gy gradients
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.MY_TYPES.ALL;

entity gradient_magnitude is
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
end entity gradient_magnitude;

architecture Behavioral of gradient_magnitude is
begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            s_ready      <= '0';
            m_valid      <= '0';
            m_last       <= '0';
            m_data(0)    <= (others => '0');
            m_data(1)    <= (others => '0');
        elsif rising_edge(clk) then
            s_ready <= m_ready;
            m_valid <= s_valid;
            m_last  <= s_last;
            if m_ready = '1' then
                if signed(s_data(0)) < 0 then
                    m_data(0) <= std_logic_vector(-signed(s_data(0)));
                else
                    m_data(0) <= s_data(0);
                end if;
                
                if signed(s_data(1)) < 0 then
                    m_data(1) <= std_logic_vector(-signed(s_data(1)));
                else
                    m_data(1) <= s_data(1);
                end if;
            end if;
        end if;
    end process;
end Behavioral;
