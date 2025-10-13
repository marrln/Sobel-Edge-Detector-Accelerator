-------------------------------------------------------------------------------
--  Hierarchical 3-stage binary adder tree for parallel computation of 
--  horizontal (Gx) and vertical (Gy) gradient sums.
--
--  Each stage performs partial summations of gradient kernel outputs 
--  (Gx, Gy), reducing the total number of operands until the final 
--  Gx and Gy results are produced.
--
--  Architecture:
--  ──────────────────────
--          ┌───────────────────────────────┐
--          │        Stage 2 (Final)        │
--          └──────────────┬────────────────┘
--                         │
--             +-----------+-----------+
--             |                       |
--           Gx_20                   Gy_20
--             |                       |
--     +-------+-------+       +-------+-------+
--     |               |       |               |
--   Gx_10           Gx_11   Gy_10           Gy_11
--     |               |       |               |
--  +--+--+         +--+--+ +--+--+         +--+--+
--  |     |         |     | |     |         |     |
-- Gx_00 Gx_01   Gx_02   Gy_00 Gy_01     Gy_02
--  |     |         |       |     |         |
--  └─────┴─────────┴───────┴─────┴─────────┘
--
--  Data Source:
--      [kernel_outputs] → provides 6 gradient values for Gx and 6 for Gy
--
--  Pipeline Flow:
--      Stage 0  →  Stage 1  →  Stage 2  →  Output
--
--  Backpressure Chain:
--      Stage 0 ← Stage 1 ← Stage 2 ← m_ready (output)
--
--  Summary:
--      • Stage 0 : 6 parallel adders  (3 × Gx, 3 × Gy)
--      • Stage 1 : 4 parallel adders  (2 × Gx, 2 × Gy)
--      • Stage 2 : 2 final adders     (1 × Gx, 1 × Gy)
-------------------------------------------------------------------------------

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
            m_data  : out std_logic_vector((digits + 8) - 1 downto 0)
        );
    end component gradient_adder;
    
    -- Stage 0 signals (6 parallel adders: 3 for Gx, 3 for Gy)
    signal Gx_00_sdata  : gradient_pair;
    signal Gx_00_mvalid : std_logic;
    signal Gx_00_mlast  : std_logic;
    signal Gx_01_sdata  : gradient_pair;
    signal Gx_02_sdata  : gradient_pair;
    signal Gx_00_mready : std_logic;  -- Used for backpressure from stage 1
    signal Gx_01_mready : std_logic;  -- Used for backpressure from stage 1
    signal Gx_02_mready : std_logic;  -- Used for backpressure from stage 1
    
    signal Gy_00_sdata  : gradient_pair;
    signal Gy_01_sdata  : gradient_pair;
    signal Gy_02_sdata  : gradient_pair;
    signal Gy_00_mready : std_logic;  -- Used for backpressure from stage 1
    signal Gy_01_mready : std_logic;  -- Used for backpressure from stage 1
    signal Gy_02_mready : std_logic;  -- Used for backpressure from stage 1
    
    -- Stage 1 signals (4 parallel adders: 2 for Gx, 2 for Gy)
    signal Gx_10_sdata  : gradient_pair;
    signal Gx_10_mvalid : std_logic;
    signal Gx_10_mlast  : std_logic;
    signal Gx_11_sdata  : gradient_pair;
    signal Gx_10_sready : std_logic;  -- Used for backpressure to stage 0
    signal Gx_10_mready : std_logic;  -- Used for backpressure from stage 2
    signal Gx_11_sready : std_logic;  -- Used for backpressure to stage 0
    signal Gx_11_mready : std_logic;  -- Used for backpressure from stage 2
    
    signal Gy_10_sdata  : gradient_pair;
    signal Gy_11_sdata  : gradient_pair;
    signal Gy_10_sready : std_logic;  -- Used for backpressure to stage 0
    signal Gy_10_mready : std_logic;  -- Used for backpressure from stage 2
    signal Gy_11_sready : std_logic;  -- Used for backpressure to stage 0
    signal Gy_11_mready : std_logic;  -- Used for backpressure from stage 2
    
    -- Stage 2 signals (2 final adders: 1 for Gx, 1 for Gy)
    signal Gx_20_sdata  : gradient_pair;
    signal Gy_20_sdata  : gradient_pair;
    signal Gx_20_sready : std_logic;  -- Used for backpressure to stage 1
    signal Gy_20_sready : std_logic;  -- Used for backpressure to stage 1
    
    -- Combined ready signals for first stage
    signal first_stage_ready : std_logic;
    
begin
    ----------------------------------------------------------------------------
    -- Input Data Mapping with Sign Extension
    -- Maps 6 Gx values and 6 Gy values from kernel_application to stage 0 adders
    ----------------------------------------------------------------------------
    -- Gx path (horizontal gradient)
    Gx_00_sdata(0) <= std_logic_vector(resize(signed(s_data(0, 0)), digits + 8));
    Gx_00_sdata(1) <= std_logic_vector(resize(signed(s_data(0, 1)), digits + 8));
    Gx_01_sdata(0) <= std_logic_vector(resize(signed(s_data(0, 2)), digits + 8));
    Gx_01_sdata(1) <= std_logic_vector(resize(signed(s_data(0, 3)), digits + 8));
    Gx_02_sdata(0) <= std_logic_vector(resize(signed(s_data(0, 4)), digits + 8));
    Gx_02_sdata(1) <= std_logic_vector(resize(signed(s_data(0, 5)), digits + 8));
    
    -- Gy path (vertical gradient)
    Gy_00_sdata(0) <= std_logic_vector(resize(signed(s_data(1, 0)), digits + 8));
    Gy_00_sdata(1) <= std_logic_vector(resize(signed(s_data(1, 1)), digits + 8));
    Gy_01_sdata(0) <= std_logic_vector(resize(signed(s_data(1, 2)), digits + 8));
    Gy_01_sdata(1) <= std_logic_vector(resize(signed(s_data(1, 3)), digits + 8));
    Gy_02_sdata(0) <= std_logic_vector(resize(signed(s_data(1, 4)), digits + 8));
    Gy_02_sdata(1) <= std_logic_vector(resize(signed(s_data(1, 5)), digits + 8));
    
    ----------------------------------------------------------------------------
    -- Backpressure Propagation (Staged Ready Signal Chain)
    -- Stage 0 ← Stage 1 ← Stage 2 ← m_ready
    ----------------------------------------------------------------------------
    -- Combined ready signal for all first-stage adders
    first_stage_ready <= Gx_00_mready and Gx_01_mready and Gx_02_mready and 
                         Gy_00_mready and Gy_01_mready and Gy_02_mready;
    s_ready <= first_stage_ready;
    
    -- Stage 0 to Stage 1 backpressure
    Gx_00_mready <= Gx_10_sready;
    Gx_01_mready <= Gx_10_sready;
    Gx_02_mready <= Gx_11_sready;
    Gy_00_mready <= Gy_10_sready;
    Gy_01_mready <= Gy_10_sready;
    Gy_02_mready <= Gy_11_sready;
    
    -- Zero padding for unbalanced inputs in stage 1
    Gx_11_sdata(1) <= (others => '0');
    Gy_11_sdata(1) <= (others => '0');
    
    -- Stage 1 to Stage 2 backpressure
    Gx_10_mready <= Gx_20_sready;
    Gx_11_mready <= Gx_20_sready;
    Gy_10_mready <= Gy_20_sready;
    Gy_11_mready <= Gy_20_sready;
    
    ----------------------------------------------------------------------------
    -- Stage 0: 6 Parallel Adders (Level 0 of tree)
    -- Sum pairs of values: 3 adders for Gx, 3 adders for Gy
    ----------------------------------------------------------------------------
    -- Primary control path for stage 0 (outputs s_ready, m_valid, m_last)
    Gx_00 : gradient_adder port map (
        clk => clk, rst_n => rst_n, s_valid => s_valid, s_ready => open,
        s_last => s_last, s_data => Gx_00_sdata, m_valid => Gx_00_mvalid,
        m_ready => Gx_00_mready, m_last => Gx_00_mlast, m_data => Gx_10_sdata(0)
    );
    
    -- Parallel adders (control signals unused - synchronized with Gx_00)
    Gx_01 : gradient_adder port map (
        clk => clk, rst_n => rst_n, s_valid => s_valid, s_ready => open,
        s_last => s_last, s_data => Gx_01_sdata, m_valid => open,
        m_ready => Gx_01_mready, m_last => open, m_data => Gx_10_sdata(1)
    );
    
    Gx_02 : gradient_adder port map (
        clk => clk, rst_n => rst_n, s_valid => s_valid, s_ready => open,
        s_last => s_last, s_data => Gx_02_sdata, m_valid => open,
        m_ready => Gx_02_mready, m_last => open, m_data => Gx_11_sdata(0)
    );
    
    Gy_00 : gradient_adder port map (
        clk => clk, rst_n => rst_n, s_valid => s_valid, s_ready => open,
        s_last => s_last, s_data => Gy_00_sdata, m_valid => open,
        m_ready => Gy_00_mready, m_last => open, m_data => Gy_10_sdata(0)
    );
    
    Gy_01 : gradient_adder port map (
        clk => clk, rst_n => rst_n, s_valid => s_valid, s_ready => open,
        s_last => s_last, s_data => Gy_01_sdata, m_valid => open,
        m_ready => Gy_01_mready, m_last => open, m_data => Gy_10_sdata(1)
    );
    
    Gy_02 : gradient_adder port map (
        clk => clk, rst_n => rst_n, s_valid => s_valid, s_ready => open,
        s_last => s_last, s_data => Gy_02_sdata, m_valid => open,
        m_ready => Gy_02_mready, m_last => open, m_data => Gy_11_sdata(0)
    );
    
    ----------------------------------------------------------------------------
    -- Stage 1: 4 Parallel Adders (Level 1 of tree)
    -- Further reduce: 2 adders for Gx, 2 adders for Gy
    ----------------------------------------------------------------------------
    -- Primary control path for stage 1
    Gx_10 : gradient_adder port map (
        clk => clk, rst_n => rst_n, s_valid => Gx_00_mvalid, s_ready => Gx_10_sready,
        s_last => Gx_00_mlast, s_data => Gx_10_sdata, m_valid => Gx_10_mvalid,
        m_ready => Gx_10_mready, m_last => Gx_10_mlast, m_data => Gx_20_sdata(0)
    );
    
    -- Parallel adders (control signals unused - synchronized with Gx_10)
    Gx_11 : gradient_adder port map (
        clk => clk, rst_n => rst_n, s_valid => Gx_00_mvalid, s_ready => Gx_11_sready,
        s_last => Gx_00_mlast, s_data => Gx_11_sdata, m_valid => open,
        m_ready => Gx_11_mready, m_last => open, m_data => Gx_20_sdata(1)
    );
    
    Gy_10 : gradient_adder port map (
        clk => clk, rst_n => rst_n, s_valid => Gx_00_mvalid, s_ready => Gy_10_sready,
        s_last => Gx_00_mlast, s_data => Gy_10_sdata, m_valid => open,
        m_ready => Gy_10_mready, m_last => open, m_data => Gy_20_sdata(0)
    );
    
    Gy_11 : gradient_adder port map (
        clk => clk, rst_n => rst_n, s_valid => Gx_00_mvalid, s_ready => Gy_11_sready,
        s_last => Gx_00_mlast, s_data => Gy_11_sdata, m_valid => open,
        m_ready => Gy_11_mready, m_last => open, m_data => Gy_20_sdata(1)
    );
    
    ----------------------------------------------------------------------------
    -- Stage 2: 2 Final Adders (Level 2 of tree - final reduction)
    -- Produces final Gx and Gy sums
    ----------------------------------------------------------------------------
    -- Final Gx sum (outputs to m_data(0) and provides m_valid, m_last)
    Gx_20 : gradient_adder port map (
        clk => clk, rst_n => rst_n, s_valid => Gx_10_mvalid, s_ready => Gx_20_sready,
        s_last => Gx_10_mlast, s_data => Gx_20_sdata, m_valid => m_valid,
        m_ready => m_ready, m_last => m_last, m_data => m_data(0)
    );
    
    -- Final Gy sum (outputs to m_data(1), control signals unused)
    Gy_20 : gradient_adder port map (
        clk => clk, rst_n => rst_n, s_valid => Gx_10_mvalid, s_ready => Gy_20_sready,
        s_last => Gx_10_mlast, s_data => Gy_20_sdata, m_valid => open,
        m_ready => m_ready, m_last => open, m_data => m_data(1)
    );
end Structural;
