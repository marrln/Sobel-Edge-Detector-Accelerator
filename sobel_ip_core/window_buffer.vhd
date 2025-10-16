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
    
    -- Buffer size: Need to store 2 complete lines + 3 additional pixels for 3x3 window
    constant BUFFER_SIZE : integer := 2 * columns + 3;
    
    -- Kernel buffer type
    type ram_t is array(0 to BUFFER_SIZE - 1) of std_logic_vector(pixel_width - 1 downto 0);
    type pixel_window_indexes is array(0 to 2, 0 to 2) of integer;
    signal kernel_buffer : ram_t := (others => (others => '0'));
    
    -- Index mapping for 3x3 window positions in the buffer
    -- Mapping positions relative to newest pixel at index 0:
    -- [2*columns+2] [2*columns+1] [2*columns]   -- Top row (oldest)
    -- [columns+2]   [columns+1]   [columns]     -- Middle row  
    -- [2]           [1]           [0]           -- Bottom row (newest)
    
    -- Function to convert 2D window coordinates to buffer indexes
    function get_window_indexes(columns : integer) return pixel_window_indexes is
        variable indexes : pixel_window_indexes;
    begin
        -- Top row (oldest pixels)
        indexes(0, 0) := 2 * columns + 2;  -- Top-left
        indexes(0, 1) := 2 * columns + 1;  -- Top-center  
        indexes(0, 2) := 2 * columns;      -- Top-right
        
        -- Middle row
        indexes(1, 0) := columns + 2;      -- Middle-left
        indexes(1, 1) := columns + 1;      -- Middle-center
        indexes(1, 2) := columns;          -- Middle-right
        
        -- Bottom row (newest pixels)
        indexes(2, 0) := 2;                -- Bottom-left
        indexes(2, 1) := 1;                -- Bottom-center
        indexes(2, 2) := 0;                -- Bottom-right (current pixel)
        
        return indexes;
    end function;
    
    constant window_indexes : pixel_window_indexes := get_window_indexes(columns);
    
    -- Internal signals
    signal internal_valid : std_logic := '0';
    signal internal_last  : std_logic := '0';
    signal pixel_count : integer := 0;
    signal can_output : std_logic := '0';
    
begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then

            internal_valid <= '0';
            internal_last  <= '0';
            kernel_buffer <= (others => (others => '0'));
            m_data <= (others => (others => (others => '0')));
            pixel_count <= 0;
            can_output <= '0';
            
        elsif rising_edge(clk) then

            internal_valid <= '0';
            internal_last  <= '0';

            if s_valid = '1' and m_ready = '1' then -- When both valid data and ready to transfer
                
                for i in 0 to BUFFER_SIZE - 2 loop
                    kernel_buffer(i + 1) <= kernel_buffer(i); -- Shift buffer: move all elements one position forward
                end loop;
                
                kernel_buffer(0) <= s_data; -- Insert new pixel at the beginning (newest position)
                
                if pixel_count < BUFFER_SIZE then
                    pixel_count <= pixel_count + 1;
                end if;
                
                -- Update output only when buffer is full for the first time and every cycle thereafter
                if pixel_count >= BUFFER_SIZE - 1 then -- Output only after buffer full
                    for i in 0 to 2 loop
                        for j in 0 to 2 loop
                            m_data(i, j) <= kernel_buffer(window_indexes(i, j)); -- Map buffer to 3x3 window
                        end loop;
                    end loop;
                    internal_valid <= '1';
                    internal_last  <= s_last;
                end if;
            end if;
        else 
            kernel_buffer <= kernel_buffer; -- Hold state
        end if;
    end process;

    -- Output assignments
    m_valid <= internal_valid;
    m_last  <= internal_last;
    s_ready <= m_ready;  -- Flow control: ready when downstream is ready

end architecture behavioral;