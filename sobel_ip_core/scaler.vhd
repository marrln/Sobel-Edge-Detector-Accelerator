-- AXI4-Stream compliant scaler with proper handshaking
-- This scaler reduces the pixel value by half (simple right shift).
-- Note: This will affect the image brightness, it will be darker.
-- Simply passing the input to output without scaling is acceptable.
-- By uncommenting the relevant line in the process below you can enable scaling. 
-- Not using scaling will cause some data to overflow later in the pipeline,
-- causing the edges to be sharper and appear more similar to the software version.

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
begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            valid_reg <= '0';
            last_reg  <= '0';
            data_reg  <= (others => '0');
        elsif rising_edge(clk) then
            -- Clear valid when output is accepted
            if m_ready = '1' then
                valid_reg <= '0';
                last_reg <= '0';
            end if;
            
            -- Register new data when we accept input
            if s_valid = '1' and (valid_reg = '0' or m_ready = '1') then
                data_reg  <= s_data;  -- No scaling
                -- data_reg  <= std_logic_vector(shift_right(unsigned(s_data), 1)); -- Divide by 2
                -- data_reg  <= std_logic_vector(shift_right(unsigned(s_data), 2)); -- Divide by 4
                last_reg  <= s_last;
                valid_reg <= '1';
            end if;
        end if;
    end process;

    -- Output assignments
    s_ready <= '1' when (valid_reg = '0') or (m_ready = '1') else '0';
    m_valid <= valid_reg;
    m_last  <= last_reg;
    m_data  <= data_reg;
end architecture behavioral;