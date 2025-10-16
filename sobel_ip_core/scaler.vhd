-- AXI4-Stream compliant scaler with proper handshaking
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
        s_data  : in std_logic_vector(pixel_width - 1 downto 0);
        m_valid : out std_logic;
        m_ready : in std_logic;
        m_last  : out std_logic;
        m_data  : out std_logic_vector(pixel_width - 1 downto 0)
    );
end entity scaler;

architecture behavioral of scaler is
    signal data_reg  : std_logic_vector(pixel_width - 1 downto 0) := (others => '0');
    signal valid_reg : std_logic := '0';
    signal last_reg  : std_logic := '0';
    signal ready_int : std_logic := '0';
begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            valid_reg <= '0';
            last_reg  <= '0';
            data_reg  <= (others => '0');
        elsif rising_edge(clk) then
            -- Register new data when we accept input
            if s_valid = '1' and ready_int = '1' then
                -- NOTE: Uncomment one of the following lines to apply scaling, scaling makes the image darker
                -- data_reg  <= std_logic_vector(shift_right(unsigned(s_data), 2)); -- Divide by 4
                -- data_reg  <= std_logic_vector(shift_right(unsigned(s_data), 1)); -- Divide by 2
                data_reg  <= s_data;  -- No scaling
                last_reg  <= s_last;
                valid_reg <= '1';
            -- Clear valid when output is accepted
            elsif m_ready = '1' and valid_reg = '1' then
                valid_reg <= '0';
            end if;
        end if;
    end process;

    -- AXI-compliant handshake logic
    ready_int <= '1' when (valid_reg = '0') or (m_ready = '1' and valid_reg = '1') else '0';
    
    -- Output assignments
    s_ready <= ready_int;
    m_valid <= valid_reg;
    m_last  <= last_reg;
    m_data  <= data_reg;
end architecture behavioral;