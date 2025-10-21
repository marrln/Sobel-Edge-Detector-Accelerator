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

    signal output_valid : std_logic;
    signal output_last  : std_logic;
    signal output_data  : gradient_pair;
    
    -- Ready when downstream can accept data or we don't have valid data
    signal ready_int : std_logic;

begin
    -- Ready when downstream can accept data or we don't have valid data
    ready_int <= not output_valid or m_ready;
    s_ready <= ready_int;

    process(clk, rst_n)
        -- Use wider signed variables for intermediate calculations
        variable p00, p01, p02 : signed(gradient_width-1 downto 0);
        variable p10, p11, p12 : signed(gradient_width-1 downto 0);
        variable p20, p21, p22 : signed(gradient_width-1 downto 0);

        -- Variables for gradient computation with sufficient width
        variable gx, gy : signed(gradient_width-1 downto 0);

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
                -- Extract pixels and convert to signed with proper width
                p00 := signed(resize(unsigned(s_data(0, 0)), gradient_width));
                p01 := signed(resize(unsigned(s_data(0, 1)), gradient_width));
                p02 := signed(resize(unsigned(s_data(0, 2)), gradient_width));
                p10 := signed(resize(unsigned(s_data(1, 0)), gradient_width));
                p11 := signed(resize(unsigned(s_data(1, 1)), gradient_width));
                p12 := signed(resize(unsigned(s_data(1, 2)), gradient_width));
                p20 := signed(resize(unsigned(s_data(2, 0)), gradient_width));
                p21 := signed(resize(unsigned(s_data(2, 1)), gradient_width));
                p22 := signed(resize(unsigned(s_data(2, 2)), gradient_width));

                -- Compute gradients using Sobel operator
                gx := resize(p02 - p00, gradient_width) + 
                      resize(shift_left(p12 - p10, 1), gradient_width) +  -- 2*(p12-p10)
                      resize(p22 - p20, gradient_width);
                
                gy := resize(p00 + shift_left(p01, 1) + p02, gradient_width) -  -- p00 + 2*p01 + p02
                      resize(p20 + shift_left(p21, 1) + p22, gradient_width);   -- p20 + 2*p21 + p22
                
                -- Register outputs - resize to gradient_width
                output_data(0) <= std_logic_vector(gx);
                output_data(1) <= std_logic_vector(gy);

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