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

    -- Stage 1: Input registration and pixel extraction
    signal stage1_valid, stage1_last : std_logic;
    signal p00_s1, p01_s1, p02_s1 : signed(gradient_width-1 downto 0);
    signal p10_s1, p12_s1 : signed(gradient_width-1 downto 0);
    signal p20_s1, p21_s1, p22_s1 : signed(gradient_width-1 downto 0);
    
    -- Stage 2: Partial sums computation
    signal stage2_valid, stage2_last : std_logic;
    signal gx_part1_s2, gx_part2_s2, gx_part3_s2 : signed(gradient_width-1 downto 0);
    signal gy_part1_s2, gy_part2_s2 : signed(gradient_width-1 downto 0);
    
    -- Stage 3: Final combination and output
    signal output_valid : std_logic;
    signal output_last  : std_logic;
    signal output_data  : gradient_pair;
    
    signal ready_int : std_logic;
    
begin
    -- Ready when any pipeline stage has space
    ready_int <= not stage1_valid or not stage2_valid or (not output_valid and m_ready);
    s_ready <= ready_int;

    -- Pipeline Stage 1: Input registration and pixel extraction
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            stage1_valid <= '0';
            stage1_last <= '0';
            p00_s1 <= (others => '0'); p01_s1 <= (others => '0'); p02_s1 <= (others => '0');
            p10_s1 <= (others => '0'); p12_s1 <= (others => '0');
            p20_s1 <= (others => '0'); p21_s1 <= (others => '0'); p22_s1 <= (others => '0');
            
        elsif rising_edge(clk) then
            if ready_int = '1' then
                stage1_valid <= s_valid;
                stage1_last <= s_last;
                
                if s_valid = '1' then
                    -- Extract and convert pixels directly to gradient_width
                    p00_s1 <= resize(signed('0' & s_data(0, 0)), gradient_width);
                    p01_s1 <= resize(signed('0' & s_data(0, 1)), gradient_width);
                    p02_s1 <= resize(signed('0' & s_data(0, 2)), gradient_width);
                    p10_s1 <= resize(signed('0' & s_data(1, 0)), gradient_width);
                    p12_s1 <= resize(signed('0' & s_data(1, 2)), gradient_width);
                    p20_s1 <= resize(signed('0' & s_data(2, 0)), gradient_width);
                    p21_s1 <= resize(signed('0' & s_data(2, 1)), gradient_width);
                    p22_s1 <= resize(signed('0' & s_data(2, 2)), gradient_width);
                end if;
            end if;
        end if;
    end process;

    -- Pipeline Stage 2: Partial sums computation
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            stage2_valid <= '0';
            stage2_last <= '0';
            gx_part1_s2 <= (others => '0'); gx_part2_s2 <= (others => '0'); gx_part3_s2 <= (others => '0');
            gy_part1_s2 <= (others => '0'); gy_part2_s2 <= (others => '0');
            
        elsif rising_edge(clk) then
            if ready_int = '1' then
                stage2_valid <= stage1_valid;
                stage2_last <= stage1_last;
                
                if stage1_valid = '1' then
                    -- Compute all partial sums using gradient_width
                    gx_part1_s2 <= resize(p02_s1 - p00_s1, gradient_width);
                    gx_part2_s2 <= resize(shift_left(p12_s1 - p10_s1, 1), gradient_width);
                    gx_part3_s2 <= resize(p22_s1 - p20_s1, gradient_width);
                    
                    gy_part1_s2 <= resize(p00_s1 + shift_left(p01_s1, 1) + p02_s1, gradient_width);
                    gy_part2_s2 <= resize(p20_s1 + shift_left(p21_s1, 1) + p22_s1, gradient_width);
                end if;
            end if;
        end if;
    end process;

    -- Pipeline Stage 3: Final combination and output registration
    process(clk, rst_n)
        variable gx, gy : signed(gradient_width-1 downto 0);
    begin
        if rst_n = '0' then
            output_valid <= '0';
            output_last <= '0';
            output_data <= (others => (others => '0'));
            
        elsif rising_edge(clk) then
            -- Clear output when accepted by downstream
            if m_ready = '1' and output_valid = '1' then
                output_valid <= '0';
                output_last <= '0';
            end if;
            
            -- Process Stage 2 data when available
            if (m_ready = '1' or output_valid = '0') and stage2_valid = '1' then
                output_valid <= '1';
                output_last <= stage2_last;
                
                -- Final combination only (very short logic)
                gx := gx_part1_s2 + gx_part2_s2 + gx_part3_s2;
                gy := gy_part1_s2 - gy_part2_s2;
                
                output_data(0) <= std_logic_vector(gx);
                output_data(1) <= std_logic_vector(gy);
            end if;
        end if;
    end process;
    
    -- Output assignments
    m_valid <= output_valid;
    m_last  <= output_last;
    m_data  <= output_data;
    
end Behavioral;