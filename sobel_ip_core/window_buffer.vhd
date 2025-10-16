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
    -- Assuming pixel_window is 3x3 array (0 to 2, 0 to 2)
    -- Mapping positions relative to newest pixel at index 0:
    -- [2*columns+2] [2*columns+1] [2*columns]   -- Top row (oldest)
    -- [columns+2]   [columns+1]   [columns]     -- Middle row  
    -- [2]          [1]          [0]            -- Bottom row (newest)
    
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
    
begin
    
    -- Connect internal signals to outputs
    m_valid <= internal_valid;
    m_last  <= internal_last;
    s_ready <= m_ready;  -- Flow control: ready when downstream is ready
    
    process(clk, rst_n)
        variable temp_buffer : ram_t;
    begin
        if rst_n = '0' then
            -- Reset all signals and buffer
            internal_valid <= '0';
            internal_last  <= '0';
            kernel_buffer <= (others => (others => '0'));
            m_data <= (others => (others => (others => '0')));
            
        elsif rising_edge(clk) then
            -- Default values
            internal_valid <= '0';
            internal_last  <= '0';
            
            -- When both valid data and ready to transfer
            if s_valid = '1' and m_ready = '1' then
                -- Shift buffer: move all elements one position forward
                for i in BUFFER_SIZE - 1 downto 1 loop
                    kernel_buffer(i) <= kernel_buffer(i - 1);
                end loop;
                
                -- Insert new pixel at the beginning (newest position)
                kernel_buffer(0) <= s_data;
                
                -- Output the 3x3 window
                for i in 0 to 2 loop
                    for j in 0 to 2 loop
                        m_data(i, j) <= kernel_buffer(window_indexes(i, j));
                    end loop;
                end loop;
                
                -- Pass through control signals
                internal_valid <= '1';
                internal_last  <= s_last;
                
            end if;
        end if;
    end process;

end architecture behavioral;