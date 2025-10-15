library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.MY_TYPES.ALL;

entity gradient_adder_tree is
    port (
        clk     : in std_logic;
        rst_n   : in std_logic;
        s_valid : in std_logic;
        s_ready : out std_logic;
        s_last  : in std_logic;
        s_data  : in kernel_outputs;
        m_valid : out std_logic;
        m_ready : in std_logic;
        m_last  : out std_logic;
        m_data  : out gradient_pair
    );
end entity gradient_adder_tree;

architecture Structural of gradient_adder_tree is
    component gradient_adder is
        port (
            clk     : in std_logic;
            rst_n   : in std_logic;
            s_valid : in std_logic;
            s_ready : out std_logic;
            s_last  : in std_logic;
            s_data  : in gradient_pair;
            m_valid : out std_logic;
            m_ready : in std_logic;
            m_last  : out std_logic;
            m_data  : out std_logic_vector(gradient_width - 1 downto 0)
        );
    end component;

    -- Stage 0 signals
    signal Gx_00_sdata, Gx_01_sdata, Gx_02_sdata : gradient_pair := (others => (others => '0'));
    signal Gy_00_sdata, Gy_01_sdata, Gy_02_sdata : gradient_pair := (others => (others => '0'));
    
    signal Gx_00_mdata, Gx_01_mdata, Gx_02_mdata : std_logic_vector(gradient_width - 1 downto 0) := (others => '0');
    signal Gy_00_mdata, Gy_01_mdata, Gy_02_mdata : std_logic_vector(gradient_width - 1 downto 0) := (others => '0');
    
    signal Gx_00_mvalid, Gx_01_mvalid, Gx_02_mvalid : std_logic := '0';
    signal Gy_00_mvalid, Gy_01_mvalid, Gy_02_mvalid : std_logic := '0';
    signal Gx_00_mlast, Gx_01_mlast, Gx_02_mlast : std_logic := '0';
    signal Gy_00_mlast, Gy_01_mlast, Gy_02_mlast : std_logic := '0';

    -- Stage 1 signals  
    signal Gx_10_sdata, Gx_11_sdata : gradient_pair := (others => (others => '0'));
    signal Gy_10_sdata, Gy_11_sdata : gradient_pair := (others => (others => '0'));
    
    signal Gx_10_mdata, Gx_11_mdata : std_logic_vector(gradient_width - 1 downto 0) := (others => '0');
    signal Gy_10_mdata, Gy_11_mdata : std_logic_vector(gradient_width - 1 downto 0) := (others => '0');
    
    signal Gx_10_mvalid, Gx_11_mvalid : std_logic := '0';
    signal Gy_10_mvalid, Gy_11_mvalid : std_logic := '0';
    signal Gx_10_mlast, Gx_11_mlast : std_logic := '0';
    signal Gy_10_mlast, Gy_11_mlast : std_logic := '0';

    -- Stage 2 signals
    signal Gx_20_sdata, Gy_20_sdata : gradient_pair := (others => (others => '0'));
    
    signal Gx_20_mvalid, Gy_20_mvalid : std_logic := '0';
    signal Gx_20_mlast, Gy_20_mlast : std_logic := '0';

    -- Backpressure signals
    signal Gx_00_sready, Gx_01_sready, Gx_02_sready : std_logic := '0';
    signal Gy_00_sready, Gy_01_sready, Gy_02_sready : std_logic := '0';
    signal Gx_10_sready, Gx_11_sready : std_logic := '0';
    signal Gy_10_sready, Gy_11_sready : std_logic := '0';
    signal Gx_20_sready, Gy_20_sready : std_logic := '0';

begin
    ----------------------------------------------------------------------------
    -- Input mapping from kernel_outputs
    ----------------------------------------------------------------------------
    -- Gx components (Sobel X direction)
    Gx_00_sdata(0) <= s_data(0, 0);
    Gx_00_sdata(1) <= s_data(0, 1);
    
    Gx_01_sdata(0) <= s_data(0, 2);
    Gx_01_sdata(1) <= s_data(0, 3);
    
    Gx_02_sdata(0) <= s_data(0, 4);
    Gx_02_sdata(1) <= s_data(0, 5);

    -- Gy components (Sobel Y direction)  
    Gy_00_sdata(0) <= s_data(1, 0);
    Gy_00_sdata(1) <= s_data(1, 1);
    
    Gy_01_sdata(0) <= s_data(1, 2);
    Gy_01_sdata(1) <= s_data(1, 3);
    
    Gy_02_sdata(0) <= s_data(1, 4);
    Gy_02_sdata(1) <= s_data(1, 5);

    ----------------------------------------------------------------------------
    -- Backpressure Propagation
    ----------------------------------------------------------------------------
    -- Stage 2: Final stage ready signals come directly from downstream
    Gx_20_sready <= m_ready;
    Gy_20_sready <= m_ready;

    -- Stage 1: Ready when ALL stage 2 adders in the same path are ready
    Gx_10_sready <= Gx_20_sready;  -- Gx path
    Gx_11_sready <= Gx_20_sready;  -- Gx path
    Gy_10_sready <= Gy_20_sready;  -- Gy path  
    Gy_11_sready <= Gy_20_sready;  -- Gy path

    -- Stage 0: Ready when ALL stage 1 adders in the same path are ready
    Gx_00_sready <= Gx_10_sready;  -- Gx path
    Gx_01_sready <= Gx_10_sready;  -- Gx path
    Gx_02_sready <= Gx_11_sready;  -- Gx path
    Gy_00_sready <= Gy_10_sready;  -- Gy path
    Gy_01_sready <= Gy_10_sready;  -- Gy path
    Gy_02_sready <= Gy_11_sready;  -- Gy path

    -- Input ready: Only ready when ALL first-stage adders are ready
    s_ready <= Gx_00_sready and Gx_01_sready and Gx_02_sready and 
               Gy_00_sready and Gy_01_sready and Gy_02_sready;

    -- Output valid: Only valid when BOTH final adders have valid data
    m_valid <= Gx_20_mvalid and Gy_20_mvalid;
    
    -- Output last: Use Gx path last signal (both paths are synchronized)
    m_last <= Gx_20_mlast;

    ----------------------------------------------------------------------------
    -- Stage 0: First level of addition (6 parallel adders)
    ----------------------------------------------------------------------------
    Gx_00 : gradient_adder port map (
        clk => clk, rst_n => rst_n, 
        s_valid => s_valid, 
        s_ready => Gx_00_sready,
        s_last => s_last,
        s_data => Gx_00_sdata, 
        m_valid => Gx_00_mvalid,
        m_ready => Gx_00_sready,  -- Connected to stage0 ready
        m_last => Gx_00_mlast,
        m_data => Gx_00_mdata
    );

    Gx_01 : gradient_adder port map (
        clk => clk, rst_n => rst_n,
        s_valid => s_valid, 
        s_ready => Gx_01_sready,
        s_last => s_last, 
        s_data => Gx_01_sdata,
        m_valid => Gx_01_mvalid,
        m_ready => Gx_01_sready,
        m_last => Gx_01_mlast,
        m_data => Gx_01_mdata
    );

    Gx_02 : gradient_adder port map (
        clk => clk, rst_n => rst_n,
        s_valid => s_valid, 
        s_ready => Gx_02_sready,
        s_last => s_last,
        s_data => Gx_02_sdata,
        m_valid => Gx_02_mvalid,
        m_ready => Gx_02_sready,
        m_last => Gx_02_mlast,
        m_data => Gx_02_mdata
    );

    Gy_00 : gradient_adder port map (
        clk => clk, rst_n => rst_n,
        s_valid => s_valid, 
        s_ready => Gy_00_sready,
        s_last => s_last,
        s_data => Gy_00_sdata,
        m_valid => Gy_00_mvalid,
        m_ready => Gy_00_sready,
        m_last => Gy_00_mlast,
        m_data => Gy_00_mdata
    );

    Gy_01 : gradient_adder port map (
        clk => clk, rst_n => rst_n,
        s_valid => s_valid, 
        s_ready => Gy_01_sready,
        s_last => s_last,
        s_data => Gy_01_sdata,
        m_valid => Gy_01_mvalid,
        m_ready => Gy_01_sready,
        m_last => Gy_01_mlast,
        m_data => Gy_01_mdata
    );

    Gy_02 : gradient_adder port map (
        clk => clk, rst_n => rst_n,
        s_valid => s_valid, 
        s_ready => Gy_02_sready,
        s_last => s_last,
        s_data => Gy_02_sdata,
        m_valid => Gy_02_mvalid,
        m_ready => Gy_02_sready,
        m_last => Gy_02_mlast,
        m_data => Gy_02_mdata
    );

    ----------------------------------------------------------------------------
    -- Stage 1: Second level of addition (4 parallel adders)
    ----------------------------------------------------------------------------
    -- Gx path connections
    Gx_10_sdata(0) <= Gx_00_mdata;
    Gx_10_sdata(1) <= Gx_01_mdata;
    
    Gx_11_sdata(0) <= Gx_02_mdata;
    Gx_11_sdata(1) <= (others => '0');  -- Zero padding for Sobel kernel structure

    -- Gy path connections
    Gy_10_sdata(0) <= Gy_00_mdata;
    Gy_10_sdata(1) <= Gy_01_mdata;
    
    Gy_11_sdata(0) <= Gy_02_mdata;
    Gy_11_sdata(1) <= (others => '0');  -- Zero padding for Sobel kernel structure

    -- Stage 1 adders
    Gx_10 : gradient_adder port map (
        clk => clk, rst_n => rst_n,
        s_valid => Gx_00_mvalid,  -- Use valid from stage 0
        s_ready => Gx_10_sready,
        s_last => Gx_00_mlast,
        s_data => Gx_10_sdata,
        m_valid => Gx_10_mvalid,
        m_ready => Gx_10_sready,
        m_last => Gx_10_mlast,
        m_data => Gx_10_mdata
    );

    Gx_11 : gradient_adder port map (
        clk => clk, rst_n => rst_n,
        s_valid => Gx_02_mvalid,  -- Use valid from stage 0
        s_ready => Gx_11_sready,
        s_last => Gx_02_mlast,
        s_data => Gx_11_sdata,
        m_valid => Gx_11_mvalid,
        m_ready => Gx_11_sready,
        m_last => Gx_11_mlast,
        m_data => Gx_11_mdata
    );

    Gy_10 : gradient_adder port map (
        clk => clk, rst_n => rst_n,
        s_valid => Gy_00_mvalid,  -- Use valid from stage 0
        s_ready => Gy_10_sready,
        s_last => Gy_00_mlast,
        s_data => Gy_10_sdata,
        m_valid => Gy_10_mvalid,
        m_ready => Gy_10_sready,
        m_last => Gy_10_mlast,
        m_data => Gy_10_mdata
    );

    Gy_11 : gradient_adder port map (
        clk => clk, rst_n => rst_n,
        s_valid => Gy_02_mvalid,  -- Use valid from stage 0
        s_ready => Gy_11_sready,
        s_last => Gy_02_mlast,
        s_data => Gy_11_sdata,
        m_valid => Gy_11_mvalid,
        m_ready => Gy_11_sready,
        m_last => Gy_11_mlast,
        m_data => Gy_11_mdata
    );

    ----------------------------------------------------------------------------
    -- Stage 2: Final addition (2 parallel adders)
    ----------------------------------------------------------------------------
    Gx_20_sdata(0) <= Gx_10_mdata;
    Gx_20_sdata(1) <= Gx_11_mdata;
    
    Gy_20_sdata(0) <= Gy_10_mdata;
    Gy_20_sdata(1) <= Gy_11_mdata;

    Gx_20 : gradient_adder port map (
        clk => clk, rst_n => rst_n,
        s_valid => Gx_10_mvalid,  -- Use valid from stage 1
        s_ready => Gx_20_sready,
        s_last => Gx_10_mlast,
        s_data => Gx_20_sdata,
        m_valid => Gx_20_mvalid,
        m_ready => Gx_20_sready,
        m_last => Gx_20_mlast,
        m_data => m_data(0)        -- Final Gx output
    );

    Gy_20 : gradient_adder port map (
        clk => clk, rst_n => rst_n,
        s_valid => Gy_11_mvalid,  -- Use valid from stage 1
        s_ready => Gy_20_sready,
        s_last => Gy_11_mlast,
        s_data => Gy_20_sdata,
        m_valid => Gy_20_mvalid,
        m_ready => Gy_20_sready,
        m_last => Gy_20_mlast,
        m_data => m_data(1)        -- Final Gy output
    );

end Structural;