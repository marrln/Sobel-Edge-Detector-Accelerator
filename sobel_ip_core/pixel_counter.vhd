-- Counts valid pixels, resets on last signal
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pixel_counter is
    port (
        clk     : in std_logic;
        rst_n   : in std_logic;
        s_valid : in std_logic;
        s_last  : in std_logic;
        m_data  : out std_logic_vector(31 downto 0)
    );
end entity pixel_counter;

-- TODO: TRY TO REDUCE THE NESTING LEVELS
architecture Behavioral of pixel_counter is
begin
    process(clk, rst_n)
        variable count : integer := 0;
    begin
        if rst_n = '0' then
            m_data <= (others => '0');
            count  := 0;
        elsif rising_edge(clk) then
            if s_valid = '1' then
                count  := count + 1;
                m_data <= std_logic_vector(to_unsigned(count, m_data'length));
                if s_last = '1' then
                    count := 0;
                end if;
            end if;
        end if;
    end process;
end Behavioral;
