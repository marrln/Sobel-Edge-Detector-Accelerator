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
    -- Internal registered signals
    signal input_data_reg  : pixel_window := (others => (others => (others => '0')));
    signal input_last_reg  : std_logic := '0';
    signal input_valid_reg : std_logic := '0';
    
    signal output_data_reg : gradient_pair := (others => (others => '0'));
    signal output_last_reg : std_logic := '0';
    signal output_valid_reg : std_logic := '0';
    
begin
    -- Flow control: ready when we can accept new data
    s_ready <= m_ready or not output_valid_reg;

    process(clk, rst_n)
        variable p00, p01, p02 : signed(pixel_width-1 downto 0) := (others => '0');
        variable p10, p11, p12 : signed(pixel_width-1 downto 0) := (others => '0');
        variable p20, p21, p22 : signed(pixel_width-1 downto 0) := (others => '0');
        variable gx_temp, gy_temp : signed(kernel_width-1 downto 0) := (others => '0');
    begin
        if rst_n = '0' then
            -- Reset all registers
            input_data_reg <= (others => (others => (others => '0')));
            input_valid_reg <= '0';
            input_last_reg <= '0';
            output_data_reg <= (others => (others => '0'));
            output_valid_reg <= '0';
            output_last_reg <= '0';
            
        elsif rising_edge(clk) then
            -- Default: maintain output unless updated
            output_valid_reg <= output_valid_reg;
            output_last_reg <= output_last_reg;
            
            -- When downstream is ready and we have valid output, clear output
            if m_ready = '1' and output_valid_reg = '1' then
                output_valid_reg <= '0';
                output_last_reg <= '0';
            end if;
            
            -- Accept new input data when ready
            if s_ready = '1' and s_valid = '1' then
                -- Register input data and control signals
                input_data_reg <= s_data;
                input_valid_reg <= '1';
                input_last_reg <= s_last;
                
                -- Perform Sobel computation
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
                
                -- Sobel Gx kernel: [-1, 0, 1; -2, 0, 2; -1, 0, 1]
                gx_temp := resize(p02 - p00 + 2*(p12 - p10) + p22 - p20, kernel_width);
                
                -- -- Sobel Gy kernel: [-1, -2, -1; 0, 0, 0; 1, 2, 1]
                -- gy_temp := resize(p20 - p00 + 2*(p21 - p01) + p22 - p02, kernel_width);
                -- Sobel Gy kernel: [1, 2, 1; 0, 0, 0; -1, -2, -1] (signs reversed)
                gy_temp := resize(p00 - p20 + 2*(p01 - p21) + p02 - p22, kernel_width);
                
                -- Register output results
                output_data_reg(0) <= std_logic_vector(resize(gx_temp, gradient_width)); -- Gx
                output_data_reg(1) <= std_logic_vector(resize(gy_temp, gradient_width)); -- Gy
                output_valid_reg <= '1';
                output_last_reg <= s_last;
                
            elsif s_ready = '1' then
                -- No valid input, clear input registers
                input_valid_reg <= '0';
                input_last_reg <= '0';
            end if;
        end if;
    end process;
    
    -- Connect outputs
    m_valid <= output_valid_reg;
    m_last  <= output_last_reg;
    m_data  <= output_data_reg;
    
end Behavioral;