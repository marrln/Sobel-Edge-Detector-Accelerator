-- Cycle counter with enable control
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cycle_counter is
    port (
        clk     : in std_logic;
        rst_n   : in std_logic;
        s_valid : in std_logic;
        s_last  : in std_logic;
        m_data  : out std_logic_vector(31 downto 0)
    );
end entity cycle_counter;

architecture Behavioral of cycle_counter is
begin
    process(clk, rst_n)
        variable enable : std_logic := '0';
        variable count  : unsigned(31 downto 0) := (others => '0');
    begin
        if rst_n = '0' then
            enable := '0';
            m_data <= (others => '0');
            count  := (others => '0');
        elsif rising_edge(clk) then
            if enable = '1' then
                count  := count + 1;
                m_data <= std_logic_vector(count);
                if s_last = '1' then
                    enable := '0';
                end if;
            else
                if s_valid = '1' then
                    enable := '1';
                    count  := to_unsigned(1, count'length);
                end if;
                m_data <= std_logic_vector(count);
            end if;
        end if;
    end process;
end Behavioral;
