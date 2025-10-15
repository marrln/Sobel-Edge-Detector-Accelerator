-- AXI4-Stream Sobel Accelerator with CDC and Telemetry
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.MY_TYPES.ALL;

entity sobel_accelerator is
    generic (
        rows       : positive := 512;
        columns    : positive := 512;
        pixels     : positive := rows * columns;
        fifo_depth : positive := 512
    );
    port (
        -- Clock and Reset
        clk_int       : in std_logic;  -- Internal processing clock
        clk_ext       : in std_logic;  -- External interface clock  
        rst_n         : in std_logic;  -- Active low reset
        en            : in std_logic;  -- Enable signal
        
        -- AXI4-Stream Input Interface
        s_axis_tvalid : in std_logic;
        s_axis_tready : out std_logic;
        s_axis_tlast  : in std_logic;
        s_axis_tdata  : in std_logic_vector(pixel_width - 1 downto 0);
        
        -- AXI4-Stream Output Interface
        m_axis_tvalid : out std_logic;
        m_axis_tready : in std_logic;
        m_axis_tlast  : out std_logic;
        m_axis_tdata  : out std_logic_vector(pixel_width - 1 downto 0);
        
        -- Telemetry Outputs (synchronized to clk_ext)
        input_pixel_cnt  : out std_logic_vector(31 downto 0);
        output_pixel_cnt : out std_logic_vector(31 downto 0);
        cycle_cnt        : out std_logic_vector(31 downto 0)
    );
end sobel_accelerator;

architecture structural of sobel_accelerator is
    
    signal sobel_rst_n : std_logic := '0';

    -- Input FIFO interface signals
    signal s_valid_to_filter    : std_logic := '0';
    signal s_ready_from_filter  : std_logic := '0';
    signal s_data_to_filter     : std_logic_vector(pixel_width - 1 downto 0) := (others => '0');
    signal s_last_to_filter     : std_logic := '0';

    -- Sobel processing core interface signals
    signal m_valid_from_filter  : std_logic := '0';
    signal m_ready_to_filter    : std_logic := '0';
    signal m_data_from_filter   : std_logic_vector(pixel_width - 1 downto 0) := (others => '0');
    signal m_last_from_filter   : std_logic := '0';

    component fifo is
        port (
            s_axis_aclk    : in  std_logic;
            s_axis_aresetn : in  std_logic;
            s_axis_tvalid  : in  std_logic;
            s_axis_tready  : out std_logic;
            s_axis_tdata   : in  std_logic_vector(7 downto 0);
            s_axis_tlast   : in  std_logic;
            m_axis_aclk    : in  std_logic;
            m_axis_tvalid  : out std_logic;
            m_axis_tready  : in  std_logic;
            m_axis_tdata   : out std_logic_vector(7 downto 0);
            m_axis_tlast   : out std_logic
        );
    end component;

    component sobel_processing_core is
        generic (
            rows    : positive := 512;
            columns : positive := 512;
            pixels  : positive := rows * columns
        );
        port (
            clk     : in std_logic;
            rst_n   : in std_logic;
            s_data  : in std_logic_vector(pixel_width - 1 downto 0);
            s_valid : in std_logic;
            s_ready : out std_logic;
            s_last  : in std_logic;
            m_data  : out std_logic_vector(pixel_width - 1 downto 0);
            m_valid : out std_logic;
            m_ready : in std_logic;
            m_last  : out std_logic
        );
    end component;

    component sobel_statistics is
        port (
            -- Clock domains
            clk_ext          : in std_logic;
            clk_int          : in std_logic;
            rst_n            : in std_logic;
            
            -- Input interface monitoring (clk_ext domain)
            s_axis_tvalid    : in std_logic;
            s_axis_tready    : in std_logic;
            s_axis_tlast     : in std_logic;
            
            -- Output interface monitoring (clk_ext domain)  
            m_axis_tvalid    : in std_logic;
            m_axis_tready    : in std_logic;
            m_axis_tlast     : in std_logic;
            
            -- Internal processing monitoring (clk_int domain)
            proc_s_valid     : in std_logic;
            proc_s_ready     : in std_logic;
            
            -- Telemetry outputs (synchronized to clk_ext)
            input_pixel_cnt  : out std_logic_vector(31 downto 0);
            output_pixel_cnt : out std_logic_vector(31 downto 0);
            cycle_cnt        : out std_logic_vector(31 downto 0)
        );
    end component;

begin
    sobel_rst_n <= rst_n and en;

    ------------------------------------------------------------------
    -- Input FIFO (External ? Internal clock domain crossing)
    ------------------------------------------------------------------
    Input_FIFO : fifo
        port map (
            s_axis_aclk    => clk_ext,
            s_axis_aresetn => sobel_rst_n,
            s_axis_tvalid  => s_axis_tvalid,
            s_axis_tready  => s_axis_tready,
            s_axis_tdata   => s_axis_tdata,
            s_axis_tlast   => s_axis_tlast,
            m_axis_aclk    => clk_int,
            m_axis_tvalid  => s_valid_to_filter,
            m_axis_tready  => s_ready_from_filter,
            m_axis_tdata   => s_data_to_filter,
            m_axis_tlast   => s_last_to_filter
        );

    ------------------------------------------------------------------
    -- Sobel Processing Core
    ------------------------------------------------------------------
    Sobel_Edge_Filter : sobel_processing_core
        generic map (
            rows    => rows,
            columns => columns,
            pixels  => pixels
        )
        port map (
            clk     => clk_int,
            rst_n   => sobel_rst_n,
            s_valid => s_valid_to_filter,
            s_ready => s_ready_from_filter,
            s_last  => s_last_to_filter,
            s_data  => s_data_to_filter,
            m_valid => m_valid_from_filter,
            m_ready => m_ready_to_filter,
            m_last  => m_last_from_filter,
            m_data  => m_data_from_filter
        );

    ------------------------------------------------------------------
    -- Output FIFO (Internal ? External clock domain crossing)
    ------------------------------------------------------------------
    Output_FIFO : fifo
        port map (
            s_axis_aclk    => clk_int,
            s_axis_aresetn => sobel_rst_n,
            s_axis_tvalid  => m_valid_from_filter,
            s_axis_tready  => m_ready_to_filter,
            s_axis_tdata   => m_data_from_filter,
            s_axis_tlast   => m_last_from_filter,
            m_axis_aclk    => clk_ext,
            m_axis_tvalid  => m_axis_tvalid,
            m_axis_tready  => m_axis_tready,
            m_axis_tdata   => m_axis_tdata,
            m_axis_tlast   => m_axis_tlast
        );

    ------------------------------------------------------------------
    -- Statistics Unit 
    ------------------------------------------------------------------
    Telemetry_Unit : sobel_statistics
        port map (
            clk_ext          => clk_ext,
            clk_int          => clk_int,
            rst_n            => sobel_rst_n,
            s_axis_tvalid    => s_axis_tvalid,
            s_axis_tready    => s_axis_tready,
            s_axis_tlast     => s_axis_tlast,
            m_axis_tvalid    => m_axis_tvalid,
            m_axis_tready    => m_axis_tready,
            m_axis_tlast     => m_axis_tlast,
            proc_s_valid     => s_valid_to_filter,
            proc_s_ready     => s_ready_from_filter,
            input_pixel_cnt  => input_pixel_cnt,
            output_pixel_cnt => output_pixel_cnt,
            cycle_cnt        => cycle_cnt
        );

end structural;