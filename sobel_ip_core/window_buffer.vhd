-- This module implements a three-line buffer that assembles a 3x3 pixel window
-- for every output pixel produced from a streaming image input. Internally the 
-- design keeps three line buffers (line0, line1, line2), each able to store one 
-- full row of pixels. New incoming pixels are written into the current column
-- position of line0 and the older lines are shifted down. 
-- When enough pixels have been received to fill at least two full rows plus the
-- current row, a 3x3 window centered at the current pixel is output.
-- For pixels near the edge of the frame, wrap-around addressing is used
-- to read pixels from the right side of the line buffers.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.MY_TYPES.ALL;

entity window_buffer is
    generic (
        rows    : positive := 512;
        columns : positive := 512;
        pixels  : positive := rows * columns
    );
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
        m_data  : out pixel_window
    );
end entity window_buffer;

architecture behavioral of window_buffer is
    -- Line buffers for three rows
    type line_buffer_type is array (0 to columns-1) of std_logic_vector(pixel_width-1 downto 0);
    signal line0, line1, line2 : line_buffer_type := (others => (others => '0'));
    
    -- Buffer control signals
    signal buf_valid : std_logic := '0';
    signal buf_last  : std_logic := '0';
    signal pixel_counter : integer range 0 to pixels-1 := 0;
    signal column_counter : integer range 0 to columns-1 := 0;
    signal row_counter : integer range 0 to rows-1 := 0;
    
    -- Internal ready signal
    signal internal_ready : std_logic;
    
begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            line0 <= (others => (others => '0'));
            line1 <= (others => (others => '0'));
            line2 <= (others => (others => '0'));
            buf_valid <= '0';
            buf_last <= '0';
            pixel_counter <= 0;
            column_counter <= 0;
            row_counter <= 0;
            
        elsif rising_edge(clk) then
            buf_valid <= '0';
            buf_last <= '0';
            
            -- Shift data through line buffers when new pixel arrives
            if s_valid = '1' and internal_ready = '1' then
                -- Shift lines: line2 <- line1 <- line0 <- new data
                line2 <= line1;
                line1 <= line0;
                
                -- Store new pixel in current position
                line0(column_counter) <= s_data;
                
                -- Update counters
                pixel_counter <= pixel_counter + 1;
                
                if column_counter = columns - 1 then
                    column_counter <= 0;
                    if row_counter = rows - 1 then
                        row_counter <= 0;
                    else
                        row_counter <= row_counter + 1;
                    end if;
                else
                    column_counter <= column_counter + 1;
                end if;
                
                -- Generate output window when we have enough data (after 2 full rows + 3 pixels)
                if row_counter >= 2 and column_counter >= 2 then
                    -- Form the 3x3 window
                    for i in 0 to 2 loop
                        for j in 0 to 2 loop
                            case i is
                                when 0 => 
                                    m_data(i, j) <= line2((column_counter - 2 + j) mod columns);
                                when 1 =>
                                    m_data(i, j) <= line1((column_counter - 2 + j) mod columns);
                                when 2 =>
                                    m_data(i, j) <= line0((column_counter - 2 + j) mod columns);
                                when others =>
                                    null;
                            end case;
                        end loop;
                    end loop;
                    
                    buf_valid <= '1';
                    
                    -- Generate m_last for output stream
                    if row_counter = rows - 1 and column_counter = columns - 1 then
                        buf_last <= '1';
                    end if;
                end if;
                
                -- Handle input last signal
                if s_last = '1' then
                    pixel_counter <= 0;
                    column_counter <= 0;
                    row_counter <= 0;
                end if;
            end if;
        end if;
    end process;
    
    -- Ready when we can accept data (simple flow control)
    internal_ready <= '1' when m_ready = '1' or buf_valid = '0' else '0';
    
    -- Output assignments
    s_ready <= internal_ready;
    m_valid <= buf_valid;
    m_last <= buf_last;
    
end architecture behavioral;