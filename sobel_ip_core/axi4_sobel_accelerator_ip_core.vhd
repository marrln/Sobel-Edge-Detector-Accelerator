-- AXI4 Sobel Accelerator IP Core
-- Top-level entity connecting Sobel accelerator with AXI4-Lite control interface
-- Register Map:
--   0x00: Control register (bit 0: system_enable)
--   0x04: Input pixel counter (read-only)
--   0x08: Output pixel counter (read-only)
--   0x0C: Clock cycle counter (read-only)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.MY_TYPES.ALL;

entity axi4_sobel_accelerator_ip_core is
    generic (
        rows       : positive := image_rows;
        columns    : positive := image_columns;
        pixels     : positive := image_rows * image_columns;
        fifo_depth : positive := fifo_depth
    );
    port (
        -- Main processing clock (200MHz)
        op_aclk        : in std_logic;
        -- AXI4-Lite clock (100MHz)
        s_axi_aclk     : in std_logic;
        -- Active low reset
        aresetn        : in std_logic;

        -- AXI4-Stream Slave Interface (input pixels)
        s_axis_tvalid  : in std_logic;
        s_axis_tdata   : in std_logic_vector(pixel_width - 1 downto 0);
        s_axis_tlast   : in std_logic;
        s_axis_tready  : out std_logic;

        -- AXI4-Stream Master Interface (output pixels)
        m_axis_tready  : in std_logic;
        m_axis_tdata   : out std_logic_vector(pixel_width - 1 downto 0);
        m_axis_tvalid  : out std_logic;
        m_axis_tlast   : out std_logic;

        -- AXI4-Lite Write Address Channel
        s_axi_awaddr   : in std_logic_vector(3 downto 0);
        s_axi_awprot   : in std_logic_vector(2 downto 0);
        s_axi_awvalid  : in std_logic;
        s_axi_awready  : out std_logic;

        -- AXI4-Lite Write Data Channel
        s_axi_wdata    : in std_logic_vector(31 downto 0);
        s_axi_wstrb    : in std_logic_vector(3 downto 0);
        s_axi_wvalid   : in std_logic;
        s_axi_wready   : out std_logic;

        -- AXI4-Lite Write Response Channel
        s_axi_bresp    : out std_logic_vector(1 downto 0);
        s_axi_bvalid   : out std_logic;
        s_axi_bready   : in std_logic;

        -- AXI4-Lite Read Address Channel
        s_axi_araddr   : in std_logic_vector(3 downto 0);
        s_axi_arprot   : in std_logic_vector(2 downto 0);
        s_axi_arvalid  : in std_logic;
        s_axi_arready  : out std_logic;

        -- AXI4-Lite Read Data Channel
        s_axi_rdata    : out std_logic_vector(31 downto 0);
        s_axi_rresp    : out std_logic_vector(1 downto 0);
        s_axi_rvalid   : out std_logic;
        s_axi_rready   : in std_logic
    );
end axi4_sobel_accelerator_ip_core;

architecture structural of axi4_sobel_accelerator_ip_core is

    -- Component declarations
    component sobel_accelerator is
        generic (
            rows       : positive := image_rows;
            columns    : positive := image_columns;
            pixels     : positive := image_rows * image_columns;
            fifo_depth : positive := fifo_depth
        );
        port (
            clk_int          : in std_logic;
            clk_ext          : in std_logic;
            rst_n            : in std_logic;
            en               : in std_logic;
            s_axis_tvalid    : in std_logic;
            s_axis_tready    : out std_logic;
            s_axis_tlast     : in std_logic;
            s_axis_tdata     : in std_logic_vector(pixel_width - 1 downto 0);
            m_axis_tvalid    : out std_logic;
            m_axis_tready    : in std_logic;
            m_axis_tlast     : out std_logic;
            m_axis_tdata     : out std_logic_vector(pixel_width - 1 downto 0);
            input_pixel_cnt  : out std_logic_vector(31 downto 0);
            output_pixel_cnt : out std_logic_vector(31 downto 0);
            cycle_cnt        : out std_logic_vector(31 downto 0)
        );
    end component;

    component axi_lite_interface is
        port (
            s_axi_aclk        : in std_logic;
            s_axi_aresetn     : in std_logic;
            pixel_count_in    : in std_logic_vector(31 downto 0);
            pixel_count_out   : in std_logic_vector(31 downto 0);
            clock_cycles_count : in std_logic_vector(31 downto 0);
            system_enable     : out std_logic;
            s_axi_awaddr      : in std_logic_vector(3 downto 0);
            s_axi_awprot      : in std_logic_vector(2 downto 0);
            s_axi_awvalid     : in std_logic;
            s_axi_awready     : out std_logic;
            s_axi_wdata       : in std_logic_vector(31 downto 0);
            s_axi_wstrb       : in std_logic_vector(3 downto 0);
            s_axi_wvalid      : in std_logic;
            s_axi_wready      : out std_logic;
            s_axi_bresp       : out std_logic_vector(1 downto 0);
            s_axi_bvalid      : out std_logic;
            s_axi_bready      : in std_logic;
            s_axi_araddr      : in std_logic_vector(3 downto 0);
            s_axi_arprot      : in std_logic_vector(2 downto 0);
            s_axi_arvalid     : in std_logic;
            s_axi_arready     : out std_logic;
            s_axi_rdata       : out std_logic_vector(31 downto 0);
            s_axi_rresp       : out std_logic_vector(1 downto 0);
            s_axi_rvalid      : out std_logic;
            s_axi_rready      : in std_logic
        );
    end component;

    -- Internal signals for component interconnection
    signal sig_input_pixel_cnt   : std_logic_vector(31 downto 0);
    signal sig_output_pixel_cnt  : std_logic_vector(31 downto 0);
    signal sig_cycle_cnt         : std_logic_vector(31 downto 0);
    signal sig_system_enable     : std_logic;

begin

    ------------------------------------------------------------------
    -- Sobel Accelerator Instance
    -- Handles the core image processing with clock domain crossing
    ------------------------------------------------------------------
    sobel_accelerator_inst : sobel_accelerator
        generic map (
            rows       => rows,
            columns    => columns,
            pixels     => pixels,
            fifo_depth => fifo_depth
        )
        port map (
            -- Clock domains: op_aclk (200MHz) for processing, s_axi_aclk (100MHz) for I/O
            clk_int          => op_aclk,           -- Internal processing clock
            clk_ext          => s_axi_aclk,        -- External interface clock
            rst_n            => aresetn,           -- Active low reset
            en               => sig_system_enable, -- Enable from AXI-Lite control register

            -- AXI4-Stream input interface
            s_axis_tvalid    => s_axis_tvalid,
            s_axis_tready    => s_axis_tready,
            s_axis_tlast     => s_axis_tlast,
            s_axis_tdata     => s_axis_tdata,

            -- AXI4-Stream output interface
            m_axis_tvalid    => m_axis_tvalid,
            m_axis_tready    => m_axis_tready,
            m_axis_tlast     => m_axis_tlast,
            m_axis_tdata     => m_axis_tdata,

            -- Telemetry outputs for monitoring
            input_pixel_cnt  => sig_input_pixel_cnt,
            output_pixel_cnt => sig_output_pixel_cnt,
            cycle_cnt        => sig_cycle_cnt
        );

    ------------------------------------------------------------------
    -- AXI4-Lite Interface Instance
    -- Provides software control and monitoring via register interface
    ------------------------------------------------------------------
    axi_lite_interface_inst : axi_lite_interface
        port map (
            -- AXI4-Lite clock and reset
            s_axi_aclk        => s_axi_aclk,
            s_axi_aresetn     => aresetn,

            -- Performance counters from Sobel accelerator
            pixel_count_in    => sig_input_pixel_cnt,
            pixel_count_out   => sig_output_pixel_cnt,
            clock_cycles_count => sig_cycle_cnt,

            -- Control output to enable/disable accelerator
            system_enable     => sig_system_enable,

            -- AXI4-Lite interface ports (passed through to top level)
            s_axi_awaddr      => s_axi_awaddr,
            s_axi_awprot      => s_axi_awprot,
            s_axi_awvalid     => s_axi_awvalid,
            s_axi_awready     => s_axi_awready,
            s_axi_wdata       => s_axi_wdata,
            s_axi_wstrb       => s_axi_wstrb,
            s_axi_wvalid      => s_axi_wvalid,
            s_axi_wready      => s_axi_wready,
            s_axi_bresp       => s_axi_bresp,
            s_axi_bvalid      => s_axi_bvalid,
            s_axi_bready      => s_axi_bready,
            s_axi_araddr      => s_axi_araddr,
            s_axi_arprot      => s_axi_arprot,
            s_axi_arvalid     => s_axi_arvalid,
            s_axi_arready     => s_axi_arready,
            s_axi_rdata       => s_axi_rdata,
            s_axi_rresp       => s_axi_rresp,
            s_axi_rvalid      => s_axi_rvalid,
            s_axi_rready      => s_axi_rready
        );

end structural;