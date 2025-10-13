-- Buffers incoming pixels and outputs 3x3 windows for convolution
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.MY_TYPES.ALL;

entity window_buffer is
    generic (
        rows    : positive := 480;
        columns : positive := 640;
        pixels  : positive := 307200
    );
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
        m_data  : out pixel_window
    );
end entity window_buffer;

architecture Behavioral of window_buffer is
    constant buffer_size : integer := 2 * columns + 3;
    
    constant kernel_indexes_buf : kernel_indexes_t := (
        2*columns + 2, 2*columns + 1, 2*columns,
        columns + 2,   columns + 1,   columns,
        2,             1,             0
    );
    
    type ram_t is array(buffer_size - 1 downto 0) of std_logic_vector(digits - 1 downto 0);
    
    signal kernel_buffer : ram_t := (others => (others => '0'));
    signal buffer_out    : buffer_array := (others => (others => '0'));
begin
    m_data(0, 0) <= buffer_out(0);
    m_data(0, 1) <= buffer_out(1);
    m_data(0, 2) <= buffer_out(2);
    m_data(1, 0) <= buffer_out(3);
    m_data(1, 1) <= buffer_out(4);
    m_data(1, 2) <= buffer_out(5);
    m_data(2, 0) <= buffer_out(6);
    m_data(2, 1) <= buffer_out(7);
    m_data(2, 2) <= buffer_out(8);
    
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            s_ready      <= '0';
            m_valid      <= '0';
            m_last       <= '0';
            buffer_out   <= (others => (others => '0'));
            kernel_buffer <= (others => (others => '0'));
        elsif rising_edge(clk) then
            s_ready <= m_ready;
            m_valid <= s_valid;
            m_last  <= s_last;
            
            if s_valid = '1' and m_ready = '1' then
                for i in 0 to buffer_size - 2 loop
                    kernel_buffer(i+1) <= kernel_buffer(i);
                end loop;
                kernel_buffer(0) <= s_data;
                
                for i in 0 to 8 loop
                    buffer_out(i) <= kernel_buffer(kernel_indexes_buf(i));
                end loop;
            else
                kernel_buffer <= kernel_buffer;
            end if;
        end if;
    end process;
end Behavioral;
