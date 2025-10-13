-- Adds |Gx| + |Gy| and saturates to 8-bit range
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.MY_TYPES.ALL;

entity magnitude_adder is
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
end entity magnitude_adder;

architecture Behavioral of magnitude_adder is
begin
    process(clk, rst_n)
        variable temp : unsigned(2*digits - 1 downto 0);
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
                temp := unsigned(s_data(0)) + unsigned(s_data(1));
                if to_integer(temp) > 255 then
                    m_data <= std_logic_vector(to_unsigned(255, m_data'length));
                else
                    m_data <= std_logic_vector(resize(temp, m_data'length));
                end if;
            end if;
        end if;
    end process;
end Behavioral;
