-- Passes data through with optional scaling
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.MY_TYPES.ALL;

entity scaler is
    port (
        clk     : in std_logic;
        rst_n   : in std_logic;
        s_valid : in std_logic;
        s_ready : out std_logic;
        s_last  : in std_logic;
        s_data  : in std_logic_vector(digits - 1 downto 0);
        m_valid : out std_logic;
        m_ready : in std_logic;
        m_last  : out std_logic;
        m_data  : out std_logic_vector(digits - 1 downto 0)
    );
end entity scaler;

architecture Behavioral of scaler is
begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            m_data  <= (others => '0');
            s_ready <= '0';
            m_valid <= '0';
            m_last  <= '0';
        elsif rising_edge(clk) then
            s_ready <= m_ready;
            m_valid <= s_valid;
            m_last  <= s_last;
            if m_ready = '1' then
                m_data <= std_logic_vector(shift_right(unsigned(s_data), 2));
                -- m_data <= s_data
                -- m_data <= std_logic_vector(shift_right(signed(s_data), 2));
            end if;
        end if;
    end process;
end Behavioral;
