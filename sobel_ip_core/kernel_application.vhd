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
        m_data  : out gradient_pair
    );
end entity kernel_application;

architecture Behavioral of kernel_application is
    signal s_ready_int : std_logic := '0';
    signal m_valid_int : std_logic := '0';
    signal m_last_int  : std_logic := '0';
    
begin
    process(clk, rst_n)
        variable p00, p01, p02 : signed(pixel_width-1 downto 0) := (others => '0');
        variable p10, p11, p12 : signed(pixel_width-1 downto 0) := (others => '0');
        variable p20, p21, p22 : signed(pixel_width-1 downto 0) := (others => '0');
        variable gx_temp, gy_temp : signed(kernel_width-1 downto 0) := (others => '0');
    begin
        if rst_n = '0' then
            s_ready_int <= '0';
            m_valid_int <= '0';
            m_last_int  <= '0';
            -- Reset all output data
            for i in 0 to 1 loop
                m_data(i) <= (others => '0');
            end loop;
            
        elsif rising_edge(clk) then
            -- Handshake signals
            s_ready_int <= m_ready;
            m_valid_int <= s_valid;
            m_last_int  <= s_last;
            
            -- Process data when ready and valid
            if m_ready = '1' and s_valid = '1' then
                -- Convert pixel data to signed
                p00 := signed(s_data(0, 0));
                p01 := signed(s_data(0, 1));
                p02 := signed(s_data(0, 2));
                p10 := signed(s_data(1, 0));
                p11 := signed(s_data(1, 1));
                p12 := signed(s_data(1, 2));
                p20 := signed(s_data(2, 0));
                p21 := signed(s_data(2, 1));
                p22 := signed(s_data(2, 2));
                
                -- -- Direct Gx calculation using Sobel kernel: [-1, 0, 1; -2, 0, 2; -1, 0, 1]
                -- -- Gx = (p02 - p00) + 2*(p12 - p10) + (p22 - p20) -> Optimized: (p02 - p00 + p22 - p20) + 2*(p12 - p10)
                -- gx_temp := resize(p02 - p00 + p22 - p20, kernel_width) + shift_left(resize(p12 - p10, kernel_width), 1);
                
                -- -- Direct Gy calculation using Sobel kernel: [-1, -2, -1; 0, 0, 0; 1, 2, 1]
                -- -- Gy = (p20 - p00) + 2*(p21 - p01) + (p22 - p02) -> Optimized: (p20 - p00 + p22 - p02) + 2*(p21 - p01)
                -- gy_temp := resize(p20 - p00 + p22 - p02, kernel_width) + shift_left(resize(p21 - p01, kernel_width), 1);
                
                -- CORRECTED: Standard Sobel kernels (not flipped)
                -- Gx = [-1, 0, 1; -2, 0, 2; -1, 0, 1]
                -- Gy = [-1, -2, -1; 0, 0, 0; 1, 2, 1]
                gx_temp := resize(p02 - p00 + 2*(p12 - p10) + p22 - p20, kernel_width);
                gy_temp := resize(p20 - p00 + 2*(p21 - p01) + p22 - p02, kernel_width);

                -- Store final Gx and Gy results in output array
                m_data(0) <= std_logic_vector(resize(gx_temp, gradient_width)); -- Gx result in first position
                m_data(1) <= std_logic_vector(resize(gy_temp, gradient_width)); -- Gy result in second position  
                
            elsif m_ready = '1' then -- Clear outputs when ready but no valid input
                for i in 0 to 1 loop
                    m_data(i) <= (others => '0');
                end loop;
            end if;
        end if;
    end process;
    
    -- Connect internal signals to outputs
    s_ready <= s_ready_int;
    m_valid <= m_valid_int;
    m_last  <= m_last_int;
    
end Behavioral;