-- Accepts a 3x3 `pixel_window` and unpacks nine pixel samples into local 
-- signed variables and applies two 3x3 Sobel kernels to compute horizontal
-- (Gx) and vertical (Gy) gradients.
-- Gradient arithmetic is performed with signed arithmetic and resized into
-- the configured `gradient_width` for output.

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
    signal output_valid : std_logic := '0';
    signal output_last  : std_logic := '0';
    signal output_data  : gradient_pair := (others => (others => '0'));
    
    -- Ready when downstream can accept data or we don't have valid data
    signal ready_int : std_logic;
begin
    -- Flow control: ready when output buffer is empty or downstream is ready
    ready_int <= not output_valid or m_ready;
    s_ready <= ready_int;

    process(clk, rst_n)
        variable p00, p01, p02 : signed(pixel_width-1 downto 0);
        variable p10, p11, p12 : signed(pixel_width-1 downto 0);
        variable p20, p21, p22 : signed(pixel_width-1 downto 0);
        variable gx, gy : signed(kernel_width-1 downto 0);
    begin
        if rst_n = '0' then
            output_valid <= '0';
            output_last  <= '0';
            output_data  <= (others => (others => '0'));
            
        elsif rising_edge(clk) then
            -- Clear output when accepted by downstream
            if m_ready = '1' and output_valid = '1' then
                output_valid <= '0';
                output_last  <= '0';
            end if;
            
            -- Accept new input when ready and valid
            if ready_int = '1' and s_valid = '1' then
                -- Extract pixels from window
                p00 := signed(s_data(0, 0));
                p01 := signed(s_data(0, 1));
                p02 := signed(s_data(0, 2));
                p10 := signed(s_data(1, 0));
                p11 := signed(s_data(1, 1));
                p12 := signed(s_data(1, 2));
                p20 := signed(s_data(2, 0));
                p21 := signed(s_data(2, 1));
                p22 := signed(s_data(2, 2));
                
                -- Sobel Gx: [-1, 0, 1; -2, 0, 2; -1, 0, 1]
                gx := resize(p02 - p00 + 2*(p12 - p10) + p22 - p20, kernel_width);
                
                -- Sobel Gy: [1, 2, 1; 0, 0, 0; -1, -2, -1] 
                gy := resize(p00 - p20 + 2*(p01 - p21) + p02 - p22, kernel_width);
                
                -- Register outputs
                output_data(0) <= std_logic_vector(resize(gx, gradient_width));
                output_data(1) <= std_logic_vector(resize(gy, gradient_width));
                output_valid <= '1';
                output_last  <= s_last;
            end if;
        end if;
    end process;
    
    -- Output assignments
    m_valid <= output_valid;
    m_last  <= output_last;
    m_data  <= output_data;
    
end Behavioral;