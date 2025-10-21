-- AXI4-Lite interface for Sobel IP core register access
-- Provides software control and monitoring of the Sobel accelerator
-- Register Map:
--   0x00: Control register (bit 0: system_enable)
--   0x04: Input pixel counter (read-only)
--   0x08: Output pixel counter (read-only)
--   0x0C: Clock cycle counter (read-only)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi4_lite_interface is
  port (
    -- Global signals
    s_axi_aclk       : in  std_logic;
    s_axi_aresetn    : in  std_logic;

    -- Status inputs from accelerator
    pixel_count_in     : in  std_logic_vector(31 downto 0);
    pixel_count_out    : in  std_logic_vector(31 downto 0);
    clock_cycles_count : in  std_logic_vector(31 downto 0);
    -- Control output to accelerator (bit 0 of control register)
    system_enable      : out std_logic;

    -- AXI4-Lite write address channel
    s_axi_awaddr   : in  std_logic_vector(3 downto 0);
    s_axi_awprot   : in  std_logic_vector(2 downto 0);
    s_axi_awvalid  : in  std_logic;
    s_axi_awready  : out std_logic;

    -- AXI4-Lite write data channel
    s_axi_wdata    : in  std_logic_vector(31 downto 0);
    s_axi_wstrb    : in  std_logic_vector(3 downto 0);
    s_axi_wvalid   : in  std_logic;
    s_axi_wready   : out std_logic;

    -- AXI4-Lite write response channel
    s_axi_bresp    : out std_logic_vector(1 downto 0);
    s_axi_bvalid   : out std_logic;
    s_axi_bready   : in  std_logic;

    -- AXI4-Lite read address channel
    s_axi_araddr   : in  std_logic_vector(3 downto 0);
    s_axi_arprot   : in  std_logic_vector(2 downto 0);
    s_axi_arvalid  : in  std_logic;
    s_axi_arready  : out std_logic;

    -- AXI4-Lite read data channel
    s_axi_rdata    : out std_logic_vector(31 downto 0);
    s_axi_rresp    : out std_logic_vector(1 downto 0);
    s_axi_rvalid   : out std_logic;
    s_axi_rready   : in  std_logic
  );
end axi4_lite_interface;

architecture behv of axi4_lite_interface is

  -- Internal AXI handshake/register signals
  signal axi_awaddr  : std_logic_vector(3 downto 0);
  signal axi_awready : std_logic;
  signal axi_wready  : std_logic;
  signal axi_bresp   : std_logic_vector(1 downto 0);
  signal axi_bvalid  : std_logic;
  signal axi_araddr  : std_logic_vector(3 downto 0);
  signal axi_arready : std_logic;
  signal axi_rdata   : std_logic_vector(31 downto 0);
  signal axi_rresp   : std_logic_vector(1 downto 0);
  signal axi_rvalid  : std_logic;

  -- Slave registers (software visible)
  signal slv_reg0 : std_logic_vector(31 downto 0);
  signal slv_reg1 : std_logic_vector(31 downto 0);
  signal slv_reg2 : std_logic_vector(31 downto 0);
  signal slv_reg3 : std_logic_vector(31 downto 0);

  -- Read/Write enable flags
  signal slv_reg_rden : std_logic;
  signal slv_reg_wren : std_logic;

  -- Read data mux
  signal reg_data_out : std_logic_vector(31 downto 0);

  -- Helper signals
  signal byte_index : integer;
  signal aw_en      : std_logic;

begin

  -- Output assignments (connect internal signals to top-level ports)
  S_AXI_AWREADY <= axi_awready;
  S_AXI_WREADY  <= axi_wready;
  S_AXI_BRESP   <= axi_bresp;
  S_AXI_BVALID  <= axi_bvalid;
  S_AXI_ARREADY <= axi_arready;
  S_AXI_RDATA   <= axi_rdata;
  S_AXI_RRESP   <= axi_rresp;
  S_AXI_RVALID  <= axi_rvalid;

  -- AWREADY/aw_en generation: accept write address only when both
  -- address and data are valid and previous write not in progress.
  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_awready <= '0';
        aw_en       <= '1';
      else
        if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
          axi_awready <= '1';
          aw_en       <= '0';
        elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
          -- Write response accepted by master: re-enable AW
          aw_en       <= '1';
          axi_awready <= '0';
        else
          axi_awready <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Latch write address when AWVALID/WVALID asserted and aw_en set
  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_awaddr <= (others => '0');
      else
        if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
          axi_awaddr <= S_AXI_AWADDR;
        end if;
      end if;
    end if;
  end process;

  -- WREADY generation: similar gating to AWREADY
  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_wready <= '0';
      else
        if (axi_wready = '0' and S_AXI_WVALID = '1' and S_AXI_AWVALID = '1' and aw_en = '1') then
          axi_wready <= '1';
        else
          axi_wready <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Generate write enable for slave registers
  slv_reg_wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID;

  -- Write logic: update selected slave register bytes according to WSTRB
  process (S_AXI_ACLK)
    variable loc_addr : std_logic_vector(1 downto 0);
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        slv_reg0 <= (others => '0');
        slv_reg1 <= (others => '0');
        slv_reg2 <= (others => '0');
        slv_reg3 <= (others => '0');
      else
        loc_addr := axi_awaddr(3 downto 2);
        if (slv_reg_wren = '1') then
          case loc_addr is
            when b"00" =>
              for byte_index in 0 to 3 loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  slv_reg0(byte_index*8 + 7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8 + 7 downto byte_index*8);
                end if;
              end loop;
            when b"01" =>
              for byte_index in 0 to 3 loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  slv_reg1(byte_index*8 + 7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8 + 7 downto byte_index*8);
                end if;
              end loop;
            when b"10" =>
              for byte_index in 0 to 3 loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  slv_reg2(byte_index*8 + 7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8 + 7 downto byte_index*8);
                end if;
              end loop;
            when b"11" =>
              for byte_index in 0 to 3 loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  slv_reg3(byte_index*8 + 7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8 + 7 downto byte_index*8);
                end if;
              end loop;
            when others =>
              -- no-op (retain current values)
              slv_reg0 <= slv_reg0;
              slv_reg1 <= slv_reg1;
              slv_reg2 <= slv_reg2;
              slv_reg3 <= slv_reg3;
          end case;
        end if;
      end if;
    end if;
  end process;

  -- Write response generation (B channel)
  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_bvalid <= '0';
        axi_bresp  <= "00"; -- OKAY
      else
        if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1' and axi_bvalid = '0') then
          axi_bvalid <= '1';
          axi_bresp  <= "00"; -- OKAY
        elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
          axi_bvalid <= '0';
        end if;
      end if;
    end if;
  end process;

  -- ARREADY and capture read address
  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_arready <= '0';
        axi_araddr  <= (others => '1');
      else
        if (axi_arready = '0' and S_AXI_ARVALID = '1') then
          axi_arready <= '1';
          axi_araddr  <= S_AXI_ARADDR;
        else
          axi_arready <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Read data valid (R channel)
  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_rvalid <= '0';
        axi_rresp  <= "00"; -- OKAY
      else
        if (axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0') then
          axi_rvalid <= '1';
          axi_rresp  <= "00"; -- OKAY
        elsif (axi_rvalid = '1' and S_AXI_RREADY = '1') then
          axi_rvalid <= '0';
        end if;
      end if;
    end if;
  end process;

  slv_reg_rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid);

  -- Read data mux: choose which register/status to return on read
  process (slv_reg0, slv_reg1, slv_reg2, slv_reg3, axi_araddr, S_AXI_ARESETN, slv_reg_rden)
    variable loc_addr : std_logic_vector(1 downto 0);
  begin
    loc_addr := axi_araddr(3 downto 2);
    case loc_addr is
      when b"00" =>
        reg_data_out <= slv_reg0;           -- Control / RW register
      when b"01" =>
        reg_data_out <= pixel_count_in;     -- Input pixel counter (RO)
      when b"10" =>
        reg_data_out <= pixel_count_out;    -- Output pixel counter (RO)
      when b"11" =>
        reg_data_out <= clock_cycles_count; -- Clock cycle counter (RO)
      when others =>
        reg_data_out <= (others => '0');
    end case;
  end process;

  -- Drive RDATA when a read is requested
  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_rdata <= (others => '0');
      else
        if (slv_reg_rden = '1') then
          axi_rdata <= reg_data_out;
        end if;
      end if;
    end if;
  end process;

  -- Expose control bit to accelerator
  system_enable <= slv_reg0(0);

end behv;