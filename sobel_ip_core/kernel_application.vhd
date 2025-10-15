-- Unified Sobel kernel application
-- Applies Sobel Gx and Gy kernels to pixel window in a single entity

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.MY_TYPES.ALL;

entity kernel_application is
    port (
        clk     : in std_logic;
        rst_n   : in std_logic;
        s_valid : in std_logic;
        s_ready : out std_logic;
        s_last  : in std_logic;
        s_data  : in pixel_window;
        m_valid : out std_logic;
        m_ready : in std_logic;
        m_last  : out std_logic;
        m_data  : out kernel_outputs
    );
end entity kernel_application;

architecture Behavioral of kernel_application is
    signal s_ready_int : std_logic := '0';
    signal m_valid_int : std_logic := '0';
    signal m_last_int  : std_logic := '0';
begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            s_ready_int <= '0';
            m_valid_int <= '0';
            m_last_int  <= '0';
            -- Reset all output data
            for i in 0 to 1 loop
                for j in 0 to 5 loop
                    m_data(i, j) <= (others => '0');
                end loop;
            end loop;
        elsif rising_edge(clk) then
            -- Handshake signals
            s_ready_int <= m_ready;
            m_valid_int <= s_valid;
            m_last_int  <= s_last;
            
            -- Process data when ready
            if m_ready = '1' then
                -- X direction processing (Gx kernel)
                -- First stage: derivative [-1, 0, +1] in X direction
                m_data(0, 0) <= std_logic_vector(resize(signed(s_data(0, 0)), kernel_width));  -- +1*col0
                m_data(0, 1) <= std_logic_vector(resize(signed(s_data(1, 0)), kernel_width));  -- +2*col1 (will be shifted)
                m_data(0, 2) <= std_logic_vector(resize(signed(s_data(2, 0)), kernel_width));  -- +1*col2
                m_data(0, 3) <= std_logic_vector(-resize(signed(s_data(0, 1)), kernel_width)); -- -1*col0
                m_data(0, 4) <= std_logic_vector(-resize(signed(s_data(1, 1)), kernel_width)); -- -2*col1 (will be shifted)
                m_data(0, 5) <= std_logic_vector(-resize(signed(s_data(2, 1)), kernel_width)); -- -1*col2
                
                -- Second stage: smoother [1, 2, 1] in Y direction
                -- Apply smoothing by shifting middle elements
                m_data(0, 1) <= std_logic_vector(shift_left(resize(signed(s_data(1, 0)), kernel_width), 1));
                m_data(0, 4) <= std_logic_vector(-shift_left(resize(signed(s_data(1, 1)), kernel_width), 1));
                
                -- Y direction processing (Gy kernel)  
                -- First stage: derivative [-1, 0, +1] in Y direction
                m_data(1, 0) <= std_logic_vector(resize(signed(s_data(0, 0)), kernel_width));  -- +1*row0
                m_data(1, 1) <= std_logic_vector(resize(signed(s_data(0, 1)), kernel_width));  -- +2*row1 (will be shifted)
                m_data(1, 2) <= std_logic_vector(resize(signed(s_data(0, 2)), kernel_width));  -- +1*row2
                m_data(1, 3) <= std_logic_vector(-resize(signed(s_data(1, 0)), kernel_width)); -- -1*row0
                m_data(1, 4) <= std_logic_vector(-resize(signed(s_data(1, 1)), kernel_width)); -- -2*row1 (will be shifted)
                m_data(1, 5) <= std_logic_vector(-resize(signed(s_data(1, 2)), kernel_width)); -- -1*row2
                
                -- Second stage: smoother [1, 2, 1] in X direction
                -- Apply smoothing by shifting middle elements
                m_data(1, 1) <= std_logic_vector(shift_left(resize(signed(s_data(0, 1)), kernel_width), 1));
                m_data(1, 4) <= std_logic_vector(-shift_left(resize(signed(s_data(1, 1)), kernel_width), 1));
            end if;
        end if;
    end process;
    
    -- Connect internal signals to outputs
    s_ready <= s_ready_int;
    m_valid <= m_valid_int;
    m_last  <= m_last_int;
    
end Behavioral;