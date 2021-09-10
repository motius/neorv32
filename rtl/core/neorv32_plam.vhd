-- #################################################################################################
-- # << NEORV32 - General Purpose Parallel Input/Output Port (plam) >>                             #
-- # ********************************************************************************************* #
-- # 64-bit general purpose parallel input & output port unit.                                     #
-- # ********************************************************************************************* #
-- # BSD 3-Clause License                                                                          #
-- #                                                                                               #
-- # Copyright (c) 2021, Stephan Nolting. All rights reserved.                                     #
-- #                                                                                               #
-- # Redistribution and use in source and binary forms, with or without modification, are          #
-- # permitted provided that the following conditions are met:                                     #
-- #                                                                                               #
-- # 1. Redistributions of source code must retain the above copyright notice, this list of        #
-- #    conditions and the following disclaimer.                                                   #
-- #                                                                                               #
-- # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
-- #    conditions and the following disclaimer in the documentation and/or other materials        #
-- #    provided with the distribution.                                                            #
-- #                                                                                               #
-- # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
-- #    endorse or promote products derived from this software without specific prior written      #
-- #    permission.                                                                                #
-- #                                                                                               #
-- # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
-- # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
-- # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
-- # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
-- # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
-- # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
-- # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
-- # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
-- # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
-- # ********************************************************************************************* #
-- # The NEORV32 Processor - https://github.com/stnolting/neorv32              (c) Stephan Nolting #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_plam is
  port (
    -- host access --
    clk_i  : in  std_ulogic; -- global clock line
    addr_i : in  std_ulogic_vector(31 downto 0); -- address
    rden_i : in  std_ulogic; -- read enable
    wren_i : in  std_ulogic; -- write enable
    data_i : in  std_ulogic_vector(31 downto 0); -- data in
    data_o : out std_ulogic_vector(31 downto 0); -- data out
    ack_o  : out std_ulogic; -- transfer acknowledge
    -- parallel io --
    plam_o : out std_ulogic_vector(63 downto 0);
    plam_i : in  std_ulogic_vector(63 downto 0)
  );
end neorv32_plam;

architecture neorv32_plam_rtl of neorv32_plam is

  -- IO space: module base address --
  constant hi_abb_c : natural := index_size_f(io_size_c)-1; -- high address boundary bit
  constant lo_abb_c : natural := index_size_f(plam_size_c); -- low address boundary bit

  -- access control --
  signal acc_en : std_ulogic; -- module access enable
  signal addr   : std_ulogic_vector(31 downto 0); -- access address
  signal wren   : std_ulogic; -- word write enable
  signal rden   : std_ulogic; -- read enable

  -- accessible regs --
  signal inp_data : std_ulogic_vector(31 downto 0); -- r/w
  signal out_data : std_ulogic_vector(31 downto 0); -- r/-

begin

  -- Access Control -------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  acc_en <= '1' when (addr_i(hi_abb_c downto lo_abb_c) = plam_base_c(hi_abb_c downto lo_abb_c)) else '0';
  addr   <= plam_base_c(31 downto lo_abb_c) & addr_i(lo_abb_c-1 downto 2) & "00"; -- word aligned
  wren   <= acc_en and wren_i; -- full 32-bit word write enable
  rden   <= acc_en and rden_i; -- the read access is always a full 32-bit word wide; if required, the byte/half-word select/masking is done in the CPU


  -- Read/Write Access ----------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  host_access: process(clk_i)
  begin
    if rising_edge(clk_i) then -- synchronous interface for reads and writes
      -- transfer/access acknowledge --
      ack_o <= rden or wren; -- default: required for the CPU to check the CFS is answering a bus read OR write request; all r/w accesses (to any cfs_reg) will succeed
--    ack_o <= rden; -- use this construct if your CFS is read-only
--    ack_o <= wren; -- use this construct if your CFS is write-only
--    ack_o <= ... -- or define the ACK by yourself (example: some registers are read-only, some others can only be written, ...)

      -- write access --
      if (wren = '1') then -- word-wide write-access only!
        case addr is -- make sure to use the internal "addr" signal for the read/write interface
          when plam_in_addr_c => inp_data <= data_i; -- for example: control register
          when others          => NULL;
        end case;
      end if;

      -- read access --
      data_o <= (others => '0'); -- the output has to be zero if there is no actual read access
      if (rden = '1') then -- the read access is always a full 32-bit word wide; if required, the byte/half-word select/masking is done in the CPU
        case addr is -- make sure to use the internal 'addr' signal for the read/write interface
          when plam_in_addr_c  => data_o <= inp_data;
          when plam_out_addr_c => data_o <= out_data;
          when others          => data_o <= (others => '0'); -- the remaining registers are not implemented and will read as zero
        end case;
      end if;
    end if;
  end process host_access;

  cfs_core: process(inp_data)
  begin
    out_data <= inp_data; -- just invert the written value
  end process cfs_core;

end neorv32_plam_rtl;
