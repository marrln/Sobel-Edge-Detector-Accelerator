-- Computes Manhattan norm (|Gx| + |Gy|) with saturation
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.MY_TYPES.ALL;

entity manhattan_norm is
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
end entity manhattan_norm;

architecture Behavioral of manhattan_norm is
    signal abs_gx : signed(gradient_width - 1 downto 0) := (others => '0');
    signal abs_gy : signed(gradient_width - 1 downto 0) := (others => '0');
    signal sum_temp : signed(gradient_width downto 0)   := (others => '0'); -- Extra bit for carry
begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            s_ready <= '0';
            m_valid <= '0';
            m_last  <= '0';
            m_data  <= (others => '0');
            abs_gx  <= (others => '0');
            abs_gy  <= (others => '0');
            sum_temp <= (others => '0');
        elsif rising_edge(clk) then
            -- AXI handshake signals
            s_ready <= m_ready;
            m_valid <= s_valid;
            m_last  <= s_last;
            
            if m_ready = '1' then
                -- Compute absolute values
                if signed(s_data(0)) < 0 then
                    abs_gx <= -signed(s_data(0));
                else
                    abs_gx <= signed(s_data(0));
                end if;
                
                if signed(s_data(1)) < 0 then
                    abs_gy <= -signed(s_data(1));
                else
                    abs_gy <= signed(s_data(1));
                end if;
                
                -- Compute sum with extra bit for carry
                sum_temp <= resize(abs_gx, gradient_width + 1) + resize(abs_gy, gradient_width + 1);
                
                -- Saturate to 8-bit output
                if sum_temp > 255 then
                    m_data <= std_logic_vector(to_unsigned(255, pixel_width));
                else
                    m_data <= std_logic_vector(resize(sum_temp, pixel_width));
                end if;
            end if;
        end if;
    end process;
end Behavioral;