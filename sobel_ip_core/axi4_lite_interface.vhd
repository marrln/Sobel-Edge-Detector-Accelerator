-- AXI4-Lite interface for Sobel IP core register access
-- Provides software control and monitoring of the Sobel accelerator
-- Register Map:
--   0x00: Control register (bit 0: system_enable)
--   0x04: Input pixel counter (read-only)
--   0x08: Output pixel counter (read-only)
--   0x0C: Clock cycle counter (read-only)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axi4_lite_interface is
    port (
        -- AXI4-Lite clock and reset
        s_axi_aclk        : in std_logic;  -- 100 MHz AXI clock
        s_axi_aresetn     : in std_logic;  -- Active low reset

        -- Performance counters from Sobel core
        pixel_count_in    : in std_logic_vector(31 downto 0);  -- Input pixel count
        pixel_count_out   : in std_logic_vector(31 downto 0);  -- Output pixel count
        clock_cycles_count : in std_logic_vector(31 downto 0); -- Processing cycles
        system_enable     : out std_logic;                     -- Enable signal to core

        -- AXI4-Lite write address channel
        s_axi_awaddr      : in std_logic_vector(3 downto 0);   -- Write address (4-bit for 16 registers)
        s_axi_awprot      : in std_logic_vector(2 downto 0);   -- Protection type (unused)
        s_axi_awvalid     : in std_logic;                      -- Write address valid
        s_axi_awready     : out std_logic;                     -- Write address ready

        -- AXI4-Lite write data channel
        s_axi_wdata       : in std_logic_vector(31 downto 0);  -- Write data
        s_axi_wstrb       : in std_logic_vector(3 downto 0);   -- Write strobe (byte enables)
        s_axi_wvalid      : in std_logic;                      -- Write data valid
        s_axi_wready      : out std_logic;                     -- Write data ready

        -- AXI4-Lite write response channel
        s_axi_bresp       : out std_logic_vector(1 downto 0);  -- Write response (always OKAY)
        s_axi_bvalid      : out std_logic;                     -- Write response valid
        s_axi_bready      : in std_logic;                      -- Write response ready

        -- AXI4-Lite read address channel
        s_axi_araddr      : in std_logic_vector(3 downto 0);   -- Read address
        s_axi_arprot      : in std_logic_vector(2 downto 0);   -- Protection type (unused)
        s_axi_arvalid     : in std_logic;                      -- Read address valid
        s_axi_arready     : out std_logic;                     -- Read address ready

        -- AXI4-Lite read data channel
        s_axi_rdata       : out std_logic_vector(31 downto 0); -- Read data
        s_axi_rresp       : out std_logic_vector(1 downto 0);  -- Read response (always OKAY)
        s_axi_rvalid      : out std_logic;                     -- Read data valid
        s_axi_rready      : in std_logic                       -- Read data ready
    );
end axi4_lite_interface;

architecture behavioral of axi4_lite_interface is

    -- Internal AXI signals for write address channel
    signal axi_awaddr  : std_logic_vector(3 downto 0);   -- Latched write address
    signal axi_awready : std_logic;                      -- Write address ready state
    signal axi_wready  : std_logic;                      -- Write data ready state
    signal axi_bresp   : std_logic_vector(1 downto 0);  -- Write response (always "00" OKAY)
    signal axi_bvalid  : std_logic;                      -- Write response valid

    -- Internal AXI signals for read address channel
    signal axi_araddr  : std_logic_vector(3 downto 0);   -- Latched read address
    signal axi_arready : std_logic;                      -- Read address ready state
    signal axi_rdata   : std_logic_vector(31 downto 0); -- Read data register
    signal axi_rresp   : std_logic_vector(1 downto 0);  -- Read response (always "00" OKAY)
    signal axi_rvalid  : std_logic;                      -- Read data valid

    -- Slave registers (4 registers total)
    signal slv_reg0    : std_logic_vector(31 downto 0); -- Control register (bit 0: enable)
    signal slv_reg1    : std_logic_vector(31 downto 0); -- Reserved (not used for writes)
    signal slv_reg2    : std_logic_vector(31 downto 0); -- Reserved (not used for writes)
    signal slv_reg3    : std_logic_vector(31 downto 0); -- Reserved (not used for writes)

    -- Control signals
    signal slv_reg_rden : std_logic;                     -- Read enable for registers
    signal slv_reg_wren : std_logic;                     -- Write enable for registers

    -- Data multiplexing
    signal reg_data_out : std_logic_vector(31 downto 0); -- Multiplexed register read data

    -- Utility signals
    signal byte_index   : integer;                       -- Index for byte-wise writes
    signal aw_en        : std_logic;                     -- Write address enable flag

begin
    -- Connect internal signals to AXI outputs
    s_axi_awready <= axi_awready;
    s_axi_wready  <= axi_wready;
    s_axi_bresp   <= axi_bresp;
    s_axi_bvalid  <= axi_bvalid;
    s_axi_arready <= axi_arready;
    s_axi_rdata   <= axi_rdata;
    s_axi_rresp   <= axi_rresp;
    s_axi_rvalid  <= axi_rvalid;

    ------------------------------------------------------------------
    -- Write Address Channel State Machine
    -- Implements AXI4-Lite write address handshake protocol
    ------------------------------------------------------------------
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                -- Reset state: not ready, enable write address capture
                axi_awready <= '0';
                aw_en <= '1';
            else
                if (axi_awready = '0' and s_axi_awvalid = '1' and s_axi_wvalid = '1' and aw_en = '1') then
                    -- Both address and data are valid, accept the transaction
                    axi_awready <= '1';
                    aw_en <= '0';  -- Disable further address captures until response complete
                elsif (s_axi_bready = '1' and axi_bvalid = '1') then
                    -- Response acknowledged, ready for next transaction
                    aw_en <= '1';
                    axi_awready <= '0';
                else
                    -- Default: not ready
                    axi_awready <= '0';
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- Write Address Latching
    -- Captures the write address when transaction starts
    ------------------------------------------------------------------
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_awaddr <= (others => '0');
            else
                if (axi_awready = '0' and s_axi_awvalid = '1' and s_axi_wvalid = '1' and aw_en = '1') then
                    -- Latch the address at the start of transaction
                    axi_awaddr <= s_axi_awaddr;
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- Write Data Channel State Machine
    -- Implements AXI4-Lite write data handshake protocol
    ------------------------------------------------------------------
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_wready <= '0';
            else
                if (axi_wready = '0' and s_axi_wvalid = '1' and s_axi_awvalid = '1' and aw_en = '1') then
                    -- Accept write data when both address and data are valid
                    axi_wready <= '1';
                else
                    -- Default: not ready
                    axi_wready <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Write enable signal: high when both address and data handshakes complete
    slv_reg_wren <= axi_wready and s_axi_wvalid and axi_awready and s_axi_awvalid;

    ------------------------------------------------------------------
    -- Register Write Logic
    -- Handles byte-wise writes to slave registers using write strobes
    ------------------------------------------------------------------
    process (s_axi_aclk)
        variable loc_addr : std_logic_vector(1 downto 0);  -- Register address (bits 3:2 of full address)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                -- Reset all registers to zero
                slv_reg0 <= (others => '0');
                slv_reg1 <= (others => '0');
                slv_reg2 <= (others => '0');
                slv_reg3 <= (others => '0');
            else
                loc_addr := axi_awaddr(3 downto 2);  -- Extract register address
                if (slv_reg_wren = '1') then
                    -- Perform byte-wise write based on write strobes

                    case loc_addr is

                        when b"00" =>  -- Control register (0x00)
                            for byte_index in 0 to 3 loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    -- Write individual bytes based on strobe
                                    slv_reg0(byte_index*8+7 downto byte_index*8) <= s_axi_wdata(byte_index*8+7 downto byte_index*8);
                                end if;
                            end loop;

                        when b"01" =>  -- Reserved register (0x04) - writes ignored
                            for byte_index in 0 to 3 loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg1(byte_index*8+7 downto byte_index*8) <= s_axi_wdata(byte_index*8+7 downto byte_index*8);
                                end if;
                            end loop;

                        when b"10" =>  -- Reserved register (0x08) - writes ignored
                            for byte_index in 0 to 3 loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg2(byte_index*8+7 downto byte_index*8) <= s_axi_wdata(byte_index*8+7 downto byte_index*8);
                                end if;
                            end loop;

                        when b"11" =>  -- Reserved register (0x0C) - writes ignored
                            for byte_index in 0 to 3 loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg3(byte_index*8+7 downto byte_index*8) <= s_axi_wdata(byte_index*8+7 downto byte_index*8);
                                end if;
                            end loop;

                        when others =>  -- Invalid address - no operation
                            slv_reg0 <= slv_reg0;
                            slv_reg1 <= slv_reg1;
                            slv_reg2 <= slv_reg2;
                            slv_reg3 <= slv_reg3;

                    end case;
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- Write Response Channel
    -- Generates write response after successful write transaction
    ------------------------------------------------------------------
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_bvalid <= '0';
                axi_bresp  <= "00";  -- OKAY response
            else
                if (axi_awready = '1' and s_axi_awvalid = '1' and axi_wready = '1' and s_axi_wvalid = '1' and axi_bvalid = '0') then
                    -- Write transaction complete, send response
                    axi_bvalid <= '1';
                    axi_bresp  <= "00";  -- OKAY response
                elsif (s_axi_bready = '1' and axi_bvalid = '1') then
                    -- Response acknowledged by master
                    axi_bvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- Read Address Channel
    -- Handles read address capture and handshake
    ------------------------------------------------------------------
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_arready <= '0';
                axi_araddr  <= (others => '1');  -- Invalid address
            else
                if (axi_arready = '0' and s_axi_arvalid = '1') then
                    -- Accept read address
                    axi_arready <= '1';
                    axi_araddr  <= s_axi_araddr;
                else
                    -- Default: not ready
                    axi_arready <= '0';
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- Read Data Channel
    -- Generates read response and data
    ------------------------------------------------------------------
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_rvalid <= '0';
                axi_rresp  <= "00";  -- OKAY response
            else
                if (axi_arready = '1' and s_axi_arvalid = '1' and axi_rvalid = '0') then
                    -- Read transaction accepted, prepare response
                    axi_rvalid <= '1';
                    axi_rresp  <= "00";  -- OKAY response
                elsif (axi_rvalid = '1' and s_axi_rready = '1') then
                    -- Data accepted by master
                    axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Read enable signal: high when address handshake complete and no pending read response
    slv_reg_rden <= axi_arready and s_axi_arvalid and (not axi_rvalid);

    ------------------------------------------------------------------
    -- Register Read Multiplexer
    -- Selects which register data to return based on read address
    ------------------------------------------------------------------
    process (slv_reg0, slv_reg1, slv_reg2, slv_reg3, axi_araddr, s_axi_aresetn, slv_reg_rden, pixel_count_in, pixel_count_out, clock_cycles_count)
        variable loc_addr : std_logic_vector(1 downto 0);
    begin
        loc_addr := axi_araddr(3 downto 2);  -- Extract register address
        case loc_addr is
            when b"00" =>  -- Control register
                reg_data_out <= slv_reg0;
            when b"01" =>  -- Input pixel counter
                reg_data_out <= pixel_count_in;
            when b"10" =>  -- Output pixel counter
                reg_data_out <= pixel_count_out;
            when b"11" =>  -- Clock cycle counter
                reg_data_out <= clock_cycles_count;
            when others =>  -- Invalid address
                reg_data_out <= (others => '0');
        end case;
    end process;

    ------------------------------------------------------------------
    -- Read Data Register
    -- Latches the multiplexed read data for AXI response
    ------------------------------------------------------------------
    process (s_axi_aclk)
    begin
        if (rising_edge(s_axi_aclk)) then
            if (s_axi_aresetn = '0') then
                axi_rdata <= (others => '0');
            else
                if (slv_reg_rden = '1') then
                    -- Latch the selected register data
                    axi_rdata <= reg_data_out;
                end if;
            end if;
        end if;
    end process;

    -- Control output: system enable from bit 0 of control register
    system_enable <= slv_reg0(0);

end behavioral;