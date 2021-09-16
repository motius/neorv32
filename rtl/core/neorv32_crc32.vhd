----------------------------------------------------------------------------------
-- Company: Motius Gmbh
-- Engineer: Kevin Bello
-- 
-- Create Date: 11.09.2021 08:24:33
-- Design Name: Cyclic Redundancy Check (CRC32)
-- Module Name: neorv32_crc32 
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_crc32 is
  port (
    -- host access --
    clk_i  : in std_ulogic; -- global clock line
    rstn_i : in std_ulogic; -- global reset line, low-active, use as async
    addr_i : in std_ulogic_vector(31 downto 0); -- address
    rden_i : in std_ulogic; -- read enable
    wren_i : in std_ulogic; -- word write enable
    data_i : in std_ulogic_vector(31 downto 0); -- data in
    data_o : out std_ulogic_vector(31 downto 0); -- data out
    ack_o  : out std_ulogic; -- transfer acknowledge
    -- CRC32 IO  --
    crc32_in_i  : in std_ulogic_vector(31 downto 0); -- crc32 inputs
    crc32_out_o : out std_ulogic_vector(31 downto 0) -- crc32 outputs
  );
end neorv32_crc32;

architecture neorv32_crc32_rtl of neorv32_crc32 is

  -- IO space: module base address (DO NOT MODIFY!) --
  constant hi_abb_c : natural := index_size_f(io_size_c) - 1; -- high address boundary bit
  constant lo_abb_c : natural := index_size_f(crc32_size_c); -- low address boundary bit

  -- access control --
  signal acc_en : std_ulogic; -- module access enable
  signal addr   : std_ulogic_vector(31 downto 0); -- access address
  signal wren   : std_ulogic; -- word write enable
  signal rden   : std_ulogic; -- read enable

  -- default CRC32 interface registers --
  type crc32_regs_t is array (0 to 1) of std_ulogic_vector(31 downto 0); -- just implement 4 registers for this example
  signal crc32_reg_wr : crc32_regs_t; -- interface registers for WRITE accesses
  signal crc32_reg_rd : crc32_regs_t; -- interface registers for READ accesses

begin

  -- Access Control -------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  -- These assignments are required to check if the CRC32 is accessed at all.
  -- DO NOT MODIFY this unless you really know what you are doing.
  acc_en      <= '1' when (addr_i(hi_abb_c downto lo_abb_c) = crc32_base_c(hi_abb_c downto lo_abb_c)) else '0';
  addr        <= crc32_base_c(31 downto lo_abb_c) & addr_i(lo_abb_c - 1 downto 2) & "00"; -- word aligned
  wren        <= acc_en and wren_i; -- full 32-bit word write enable
  rden        <= acc_en and rden_i; -- the read access is always a full 32-bit word wide; if required, the byte/half-word select/masking is done in the CPU
  crc32_out_o <= crc32_reg_rd(0);

  -- Read/Write Access ----------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  -- Here we are reading/writing from/to the interface registers of the module. Please note that the peripheral/IO
  -- modules of the NEORV32 can only be written in full word mode (32-bit). Any other write access (half-word or byte)
  -- will trigger a store bus access fault exception.
  --
  -- The CRC32 provides up to 32 memory-mapped 32-bit interface register. For instance, these could be used to provide
  -- a <control register> for global control of the unit, a <data register> for reading/writing from/to a data FIFO, a <command register>
  -- for issuing commands and a <status register> for status information.
  --
  -- Following the interface protocol, each read or write access has to be acknowledged in the following cycle using the ack_o signal (or even later
  -- if the module needs additional time; the maximum latency until an unacknowledged access will trigger a bus exception is defined via the package's
  -- global "bus_timeout_c" constant). If no ACK is generated, the bus access will time out and cause a store bus access fault exception.

  -- Host access: Read and write access to the interface registers + bus transfer acknowledge.
  -- This example only implements four physical r/w register (the four lowest CF register). The remaining addresses of the CRC32 are not
  -- associated with any writable or readable register - an access to those is simply ignored but still acknowledged.

  host_access : process (clk_i)
  begin
    if rising_edge(clk_i) then -- synchronous interface for reads and writes
      -- transfer/access acknowledge --
      ack_o <= rden or wren; -- default: required for the CPU to check the CRC32 is answering a bus read OR write request; all r/w accesses (to any CRC32_reg) will succeed
      --    ack_o <= rden; -- use this construct if your CRC32 is read-only
      --    ack_o <= wren; -- use this construct if your CRC32 is write-only
      --    ack_o <= ... -- or define the ACK by yourself (example: some registers are read-only, some others can only be written, ...)

      -- write access --
      if (wren = '1') then -- word-wide write-access only!
        case addr is -- make sure to use the internal "addr" signal for the read/write interface
          when crc32_in_addr_c  => crc32_reg_wr(0)  <= data_i; -- for example: control register
          when crc32_out_addr_c => crc32_reg_wr(1) <= data_i; -- for example: data in/out fifo
          when others           => null;
        end case;
      end if;

      -- read access --
      data_o <= (others => '0'); -- the output has to be zero if there is no actual read access
      if (rden = '1') then -- the read access is always a full 32-bit word wide; if required, the byte/half-word select/masking is done in the CPU
        case addr is -- make sure to use the internal 'addr' signal for the read/write interface
          when crc32_in_addr_c  => data_o  <= crc32_reg_rd(0);
          when crc32_out_addr_c => data_o <= crc32_reg_rd(1);
          when others => data_o           <= (others => '0'); -- the remaining registers are not implemented and will read as zero
        end case;
      end if;
    end if;
  end process host_access;
  -- CRC32 Function Core ----------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  -- This is where the actual functionality can be implemented.
  -- In this example we are just implementing four r/w registers that invert any value written to them.
  -- crc32_reg_wr(0)(7 downto 0) -- 8-bit data
  -- crc32_reg_wr(1)             -- intemediate Result
  -- crc32_reg_rd(1)             -- final Result

  cr32_core : process (crc32_reg_wr(0))
  begin

    crc32_reg_rd(1)(0)  <= (crc32_reg_wr(1)(2) xor crc32_reg_wr(1)(8) xor crc32_reg_wr(0)(2));
    crc32_reg_rd(1)(1)  <= (crc32_reg_wr(1)(0) xor crc32_reg_wr(1)(3) xor crc32_reg_wr(1)(9) xor crc32_reg_wr(0)(0) xor crc32_reg_wr(0)(3));
    crc32_reg_rd(1)(2)  <= (crc32_reg_wr(1)(0) xor crc32_reg_wr(1)(1) xor crc32_reg_wr(1)(4) xor crc32_reg_wr(1)(10) xor crc32_reg_wr(0)(0) xor crc32_reg_wr(0)(1) xor crc32_reg_wr(0)(4));
    crc32_reg_rd(1)(3)  <= (crc32_reg_wr(1)(1) xor crc32_reg_wr(1)(2) xor crc32_reg_wr(1)(5) xor crc32_reg_wr(1)(11) xor crc32_reg_wr(0)(1) xor crc32_reg_wr(0)(2) xor crc32_reg_wr(0)(5));
    crc32_reg_rd(1)(4)  <= (crc32_reg_wr(1)(0) xor crc32_reg_wr(1)(2) xor crc32_reg_wr(1)(3) xor crc32_reg_wr(1)(6) xor crc32_reg_wr(1)(12) xor crc32_reg_wr(0)(0) xor crc32_reg_wr(0)(2) xor crc32_reg_wr(0)(3) xor crc32_reg_wr(0)(6));
    crc32_reg_rd(1)(5)  <= (crc32_reg_wr(1)(1) xor crc32_reg_wr(1)(3) xor crc32_reg_wr(1)(4) xor crc32_reg_wr(1)(7) xor crc32_reg_wr(1)(13) xor crc32_reg_wr(0)(1) xor crc32_reg_wr(0)(3) xor crc32_reg_wr(0)(4) xor crc32_reg_wr(0)(7));
    crc32_reg_rd(1)(6)  <= (crc32_reg_wr(1)(4) xor crc32_reg_wr(1)(5) xor crc32_reg_wr(1)(14) xor crc32_reg_wr(0)(4) xor crc32_reg_wr(0)(5));
    crc32_reg_rd(1)(7)  <= (crc32_reg_wr(1)(0) xor crc32_reg_wr(1)(5) xor crc32_reg_wr(1)(6) xor crc32_reg_wr(1)(15) xor crc32_reg_wr(0)(0) xor crc32_reg_wr(0)(5) xor crc32_reg_wr(0)(6));
    crc32_reg_rd(1)(8)  <= (crc32_reg_wr(1)(1) xor crc32_reg_wr(1)(6) xor crc32_reg_wr(1)(7) xor crc32_reg_wr(1)(16) xor crc32_reg_wr(0)(1) xor crc32_reg_wr(0)(6) xor crc32_reg_wr(0)(7));
    crc32_reg_rd(1)(9)  <= (crc32_reg_wr(1)(7) xor crc32_reg_wr(1)(17) xor crc32_reg_wr(0)(7));
    crc32_reg_rd(1)(10) <= (crc32_reg_wr(1)(2) xor crc32_reg_wr(1)(18) xor crc32_reg_wr(0)(2));
    crc32_reg_rd(1)(11) <= (crc32_reg_wr(1)(3) xor crc32_reg_wr(1)(19) xor crc32_reg_wr(0)(3));
    crc32_reg_rd(1)(12) <= (crc32_reg_wr(1)(0) xor crc32_reg_wr(1)(4) xor crc32_reg_wr(1)(20) xor crc32_reg_wr(0)(0) xor crc32_reg_wr(0)(4));
    crc32_reg_rd(1)(13) <= (crc32_reg_wr(1)(0) xor crc32_reg_wr(1)(1) xor crc32_reg_wr(1)(5) xor crc32_reg_wr(1)(21) xor crc32_reg_wr(0)(0) xor crc32_reg_wr(0)(1) xor crc32_reg_wr(0)(5));
    crc32_reg_rd(1)(14) <= (crc32_reg_wr(1)(1) xor crc32_reg_wr(1)(2) xor crc32_reg_wr(1)(6) xor crc32_reg_wr(1)(22) xor crc32_reg_wr(0)(1) xor crc32_reg_wr(0)(2) xor crc32_reg_wr(0)(6));
    crc32_reg_rd(1)(15) <= (crc32_reg_wr(1)(2) xor crc32_reg_wr(1)(3) xor crc32_reg_wr(1)(7) xor crc32_reg_wr(1)(23) xor crc32_reg_wr(0)(2) xor crc32_reg_wr(0)(3) xor crc32_reg_wr(0)(7));
    crc32_reg_rd(1)(16) <= (crc32_reg_wr(1)(0) xor crc32_reg_wr(1)(2) xor crc32_reg_wr(1)(3) xor crc32_reg_wr(1)(4) xor crc32_reg_wr(1)(24) xor crc32_reg_wr(0)(0) xor crc32_reg_wr(0)(2) xor crc32_reg_wr(0)(3) xor crc32_reg_wr(0)(4));
    crc32_reg_rd(1)(17) <= (crc32_reg_wr(1)(0) xor crc32_reg_wr(1)(1) xor crc32_reg_wr(1)(3) xor crc32_reg_wr(1)(4) xor crc32_reg_wr(1)(5) xor crc32_reg_wr(1)(25) xor crc32_reg_wr(0)(0) xor crc32_reg_wr(0)(1) xor crc32_reg_wr(0)(3) xor crc32_reg_wr(0)(4) xor crc32_reg_wr(0)(5));
    crc32_reg_rd(1)(18) <= (crc32_reg_wr(1)(0) xor crc32_reg_wr(1)(1) xor crc32_reg_wr(1)(2) xor crc32_reg_wr(1)(4) xor crc32_reg_wr(1)(5) xor crc32_reg_wr(1)(6) xor crc32_reg_wr(1)(26) xor crc32_reg_wr(0)(0) xor crc32_reg_wr(0)(1) xor crc32_reg_wr(0)(2) xor crc32_reg_wr(0)(4) xor crc32_reg_wr(0)(5) xor crc32_reg_wr(0)(6));
    crc32_reg_rd(1)(19) <= (crc32_reg_wr(1)(1) xor crc32_reg_wr(1)(2) xor crc32_reg_wr(1)(3) xor crc32_reg_wr(1)(5) xor crc32_reg_wr(1)(6) xor crc32_reg_wr(1)(7) xor crc32_reg_wr(1)(27) xor crc32_reg_wr(0)(1) xor crc32_reg_wr(0)(2) xor crc32_reg_wr(0)(3) xor crc32_reg_wr(0)(5) xor crc32_reg_wr(0)(6) xor crc32_reg_wr(0)(7));
    crc32_reg_rd(1)(20) <= (crc32_reg_wr(1)(3) xor crc32_reg_wr(1)(4) xor crc32_reg_wr(1)(6) xor crc32_reg_wr(1)(7) xor crc32_reg_wr(1)(28) xor crc32_reg_wr(0)(3) xor crc32_reg_wr(0)(4) xor crc32_reg_wr(0)(6) xor crc32_reg_wr(0)(7));
    crc32_reg_rd(1)(21) <= (crc32_reg_wr(1)(2) xor crc32_reg_wr(1)(4) xor crc32_reg_wr(1)(5) xor crc32_reg_wr(1)(7) xor crc32_reg_wr(1)(29) xor crc32_reg_wr(0)(2) xor crc32_reg_wr(0)(4) xor crc32_reg_wr(0)(5) xor crc32_reg_wr(0)(7));
    crc32_reg_rd(1)(22) <= (crc32_reg_wr(1)(2) xor crc32_reg_wr(1)(3) xor crc32_reg_wr(1)(5) xor crc32_reg_wr(1)(6) xor crc32_reg_wr(1)(30) xor crc32_reg_wr(0)(2) xor crc32_reg_wr(0)(3) xor crc32_reg_wr(0)(5) xor crc32_reg_wr(0)(6));
    crc32_reg_rd(1)(23) <= (crc32_reg_wr(1)(3) xor crc32_reg_wr(1)(4) xor crc32_reg_wr(1)(6) xor crc32_reg_wr(1)(7) xor crc32_reg_wr(1)(31) xor crc32_reg_wr(0)(3) xor crc32_reg_wr(0)(4) xor crc32_reg_wr(0)(6) xor crc32_reg_wr(0)(7));
    crc32_reg_rd(1)(24) <= (crc32_reg_wr(1)(0) xor crc32_reg_wr(1)(2) xor crc32_reg_wr(1)(4) xor crc32_reg_wr(1)(5) xor crc32_reg_wr(1)(7) xor crc32_reg_wr(0)(0) xor crc32_reg_wr(0)(2) xor crc32_reg_wr(0)(4) xor crc32_reg_wr(0)(5) xor crc32_reg_wr(0)(7));
    crc32_reg_rd(1)(25) <= (crc32_reg_wr(1)(0) xor crc32_reg_wr(1)(1) xor crc32_reg_wr(1)(2) xor crc32_reg_wr(1)(3) xor crc32_reg_wr(1)(5) xor crc32_reg_wr(1)(6) xor crc32_reg_wr(0)(0) xor crc32_reg_wr(0)(1) xor crc32_reg_wr(0)(2) xor crc32_reg_wr(0)(3) xor crc32_reg_wr(0)(5) xor crc32_reg_wr(0)(6));
    crc32_reg_rd(1)(26) <= (crc32_reg_wr(1)(0) xor crc32_reg_wr(1)(1) xor crc32_reg_wr(1)(2) xor crc32_reg_wr(1)(3) xor crc32_reg_wr(1)(4) xor crc32_reg_wr(1)(6) xor crc32_reg_wr(1)(7) xor crc32_reg_wr(0)(0) xor crc32_reg_wr(0)(1) xor crc32_reg_wr(0)(2) xor crc32_reg_wr(0)(3) xor crc32_reg_wr(0)(4) xor crc32_reg_wr(0)(6) xor crc32_reg_wr(0)(7));
    crc32_reg_rd(1)(27) <= (crc32_reg_wr(1)(1) xor crc32_reg_wr(1)(3) xor crc32_reg_wr(1)(4) xor crc32_reg_wr(1)(5) xor crc32_reg_wr(1)(7) xor crc32_reg_wr(0)(1) xor crc32_reg_wr(0)(3) xor crc32_reg_wr(0)(4) xor crc32_reg_wr(0)(5) xor crc32_reg_wr(0)(7));
    crc32_reg_rd(1)(28) <= (crc32_reg_wr(1)(0) xor crc32_reg_wr(1)(4) xor crc32_reg_wr(1)(5) xor crc32_reg_wr(1)(6) xor crc32_reg_wr(0)(0) xor crc32_reg_wr(0)(4) xor crc32_reg_wr(0)(5) xor crc32_reg_wr(0)(6));
    crc32_reg_rd(1)(29) <= (crc32_reg_wr(1)(0) xor crc32_reg_wr(1)(1) xor crc32_reg_wr(1)(5) xor crc32_reg_wr(1)(6) xor crc32_reg_wr(1)(7) xor crc32_reg_wr(0)(0) xor crc32_reg_wr(0)(1) xor crc32_reg_wr(0)(5) xor crc32_reg_wr(0)(6) xor crc32_reg_wr(0)(7));
    crc32_reg_rd(1)(30) <= (crc32_reg_wr(1)(0) xor crc32_reg_wr(1)(1) xor crc32_reg_wr(1)(6) xor crc32_reg_wr(1)(7) xor crc32_reg_wr(0)(0) xor crc32_reg_wr(0)(1) xor crc32_reg_wr(0)(6) xor crc32_reg_wr(0)(7));
    crc32_reg_rd(1)(31) <= (crc32_reg_wr(1)(1) xor crc32_reg_wr(1)(7) xor crc32_reg_wr(0)(1) xor crc32_reg_wr(0)(7));

  end process cr32_core;
end neorv32_crc32_rtl;