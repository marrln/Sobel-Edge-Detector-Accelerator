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
        rows    : positive := image_rows;
        columns : positive := image_columns;
        pixels  : positive := image_rows * image_columns
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
    -- Memory for storing pixels in a shifting window
    -- Size accommodates two full lines plus extra pixels for 3x3 window formation
    constant MEM_SIZE : integer := 2 * columns + 3;
    type pixel_buffer_type is array(MEM_SIZE - 1 downto 0) of std_logic_vector(pixel_width - 1 downto 0);
    signal pixel_buffer : pixel_buffer_type := (others => (others => '0'));
    
    -- Buffer control signals
    signal buf_valid : std_logic := '0';
    signal buf_last  : std_logic := '0';
    signal pixel_counter : integer range 0 to pixels-1 := 0;
    signal column_counter : integer range 0 to columns-1 := 0;
    signal row_counter : integer range 0 to rows-1 := 0;
    
    -- Internal ready signal
    signal internal_ready : std_logic;
    
    -- RAM synthesis attribute to ensure Block RAM inference
    attribute ram_style : string;
    attribute ram_style of pixel_buffer : signal is "block";
    
begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            pixel_buffer <= (others => (others => '0'));
            buf_valid <= '0';
            buf_last <= '0';
            pixel_counter <= 0;
            column_counter <= 0;
            row_counter <= 0;
            
        elsif rising_edge(clk) then
            buf_valid <= '0';
            buf_last <= '0';
            
            -- Process new pixel when valid and ready
            if s_valid = '1' and internal_ready = '1' then
                -- Shift existing pixels in memory to make space for new pixel
                for i in 0 to MEM_SIZE - 2 loop
                    pixel_buffer(i + 1) <= pixel_buffer(i);
                end loop;
                
                -- Add new pixel to memory
                pixel_buffer(0) <= s_data;
                
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
                
                -- Generate output window when we have enough data (after 2 full rows + current row has 3 pixels)
                if row_counter >= 2 and column_counter >= 2 then
                    -- Form the 3x3 window from memory positions
                    -- Top row (two rows ago): positions relative to current column
                    m_data(0, 0) <= pixel_buffer(2*columns + 2); -- Top left (column-1, row-2)
                    m_data(0, 1) <= pixel_buffer(2*columns + 1); -- Top center (column, row-2)  
                    m_data(0, 2) <= pixel_buffer(2*columns);     -- Top right (column+1, row-2)
                    
                    -- Middle row (one row ago): positions relative to current column
                    m_data(1, 0) <= pixel_buffer(columns + 2);   -- Middle left (column-1, row-1)
                    m_data(1, 1) <= pixel_buffer(columns + 1);   -- Center pixel (column, row-1)
                    m_data(1, 2) <= pixel_buffer(columns);       -- Middle right (column+1, row-1)
                    
                    -- Bottom row (current row): most recent pixels
                    m_data(2, 0) <= pixel_buffer(2);             -- Bottom left (column-1, row)
                    m_data(2, 1) <= pixel_buffer(1);             -- Bottom center (column, row)
                    m_data(2, 2) <= pixel_buffer(0);             -- Bottom right (column+1, row) - current pixel
                    
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