-- AXI4-Stream compliant window buffer with proper handshaking
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
    constant buffer_size : integer := 2 * columns + 3;
    constant kernel_indexes_buf : kernel_indexes_t := (
        2*columns + 2, 2*columns + 1, 2*columns,
        columns + 2,   columns + 1,   columns,
        2,             1,             0
    );
    
    type ram_t is array(buffer_size - 1 downto 0) of std_logic_vector(pixel_width - 1 downto 0);
    
    signal kernel_buffer : ram_t := (others => (others => '0'));
    signal buffer_out    : buffer_array := (others => (others => '0'));
    signal pixel_count   : integer := 0;
    signal window_ready  : std_logic := '0';
    signal valid_reg     : std_logic := '0';
    signal last_reg      : std_logic := '0';
    signal ready_int     : std_logic := '0';
    
    -- Delayed last signals for proper timing
    signal s_last_d1     : std_logic := '0';
    signal s_last_d2     : std_logic := '0';
begin
    -- Direct mapping of buffer outputs to pixel window
    -- This maps to standard 3x3 spatial coordinates:
    -- (0,0)=top-left, (0,1)=top-middle, (0,2)=top-right
    -- (1,0)=middle-left, (1,1)=center, (1,2)=middle-right  
    -- (2,0)=bottom-left, (2,1)=bottom-middle, (2,2)=bottom-right
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
            kernel_buffer <= (others => (others => '0'));
            buffer_out    <= (others => (others => '0'));
            pixel_count   <= 0;
            window_ready  <= '0';
            valid_reg     <= '0';
            last_reg      <= '0';
            s_last_d1     <= '0';
            s_last_d2     <= '0';
            ready_int     <= '0';
        elsif rising_edge(clk) then
            -- Delay last signals to align with window output
            s_last_d1 <= s_last;
            s_last_d2 <= s_last_d1;
            
            -- Update buffer when we accept new input
            if s_valid = '1' and ready_int = '1' then
                -- Shift buffer and insert new data
                for i in 0 to buffer_size - 2 loop
                    kernel_buffer(i+1) <= kernel_buffer(i);
                end loop;
                kernel_buffer(0) <= s_data;
                
                -- Update pixel counter
                if pixel_count < buffer_size then
                    pixel_count <= pixel_count + 1;
                end if;
                
                -- Check if we have enough pixels for a valid window
                if pixel_count >= buffer_size - 1 then
                    window_ready <= '1';
                end if;
                
                -- Update output window from buffer
                for i in 0 to 8 loop
                    buffer_out(i) <= kernel_buffer(kernel_indexes_buf(i));
                end loop;
            end if;
            
            -- Output handshake logic
            if s_valid = '1' and ready_int = '1' and window_ready = '1' then
                valid_reg <= '1';
                last_reg  <= s_last_d2;  -- Use delayed last to align with window
            elsif m_ready = '1' and valid_reg = '1' then
                valid_reg <= '0';
            end if;
            
            -- Backpressure logic: ready when we can accept data AND (not holding valid OR output is being accepted)
            ready_int <= '1' when (valid_reg = '0' or (m_ready = '1' and valid_reg = '1')) else '0';
        end if;
    end process;
    
    -- Output assignments
    s_ready <= ready_int;
    m_valid <= valid_reg;
    m_last  <= last_reg;
    
end architecture behavioral;