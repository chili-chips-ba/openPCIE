# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# eduBOS5 3-stage pipeline (EN_WAIT4REGS=1) only: multicycle paths, Vivado.
# Derived from the RTL, for the openPCIE SOC hierarchy (riscv_pcie_soc.sv).
#
# In FETCH_INSTR the core drives pc + 1 to the instruction port; after a jump
# or taken branch, FETCH_TARGET fetches again from pc. The fetched word, and the
# register file read it addresses, are stable from WAIT4REGS through EXECUTE,
# so paths from these two sources get 2 cycles:
#   - the SOC RAM's instruction port (the data port carries the loads, a
#     1-cycle path, so it stays single-cycle)
#   - the register file LUT-RAMs, written in FETCH_INSTR
# Do not use with the 2-stage pipeline: there these paths are 1 cycle.
#
# Proof: assertions in edubos5.sv, for simulation (`define EDUBOS5_MCP_CHECK)
# and formal (`define EDUBOS5_MCP_FORMAL, formal/run-mcp-formal.sh): both
# sources change only on the edge that ends a fetch state and hold 2 clocks
# from the edge into WAIT4REGS, and no register they feed loads at the 1st
# edge after it (go2exec).
#
# Uses post-synthesis names (inferred RAMs): implementation only
# (USED_IN_SYNTHESIS false). A Tcl constraints file, not XDC, for the guard.

# The instruction port is found by connectivity: the RAM port whose address
# pins hang on the SOC's imem_addr. Guard: exactly one port, or the run
# stops -- a different RAM mapping must not move the 2-cycle paths onto the
# data port unnoticed.
set ram_cells [get_cells -hier -filter {NAME =~ u_soc/ram_reg* && IS_PRIMITIVE && REF_NAME =~ RAMB*}]
set imem_port {}
foreach pin [get_pins -leaf -filter {DIRECTION == IN} -of_objects [get_nets {u_soc/imem_addr[*]}]] {
  if { [lsearch -exact $ram_cells [get_cells -of_objects $pin]] >= 0 &&
       [regexp {^ADDR([AB])} [get_property REF_PIN_NAME $pin] -> port] } {
    lappend imem_port $port
  }
}
set imem_port [lsort -unique $imem_port]
if { [llength $ram_cells] == 0 || [llength $imem_port] != 1 } {
  error "edubos5.3STG-ONLY.mcp.tcl: no single RAM port on u_soc/imem_addr\
         ([llength $ram_cells] RAM cells, ports: '$imem_port')"
}
# RAMB18E1/RAMB36E1 clock pins: CLKARDCLK (port A), CLKBWRCLK (port B)
set clk_pin  [expr { $imem_port eq "A" ? "CLKARDCLK" : "CLKBWRCLK" }]
set imem_clk [get_pins -of_objects $ram_cells -filter "REF_PIN_NAME == $clk_pin"]
puts "edubos5.3STG-ONLY.mcp.tcl: instruction port $imem_port, [llength $imem_clk] x $clk_pin"

set rf_ram   [get_cells -hier -filter {NAME =~ u_soc/cpu/u_rf/* && IS_PRIMITIVE && REF_NAME =~ RAMD32*}]

set_multicycle_path -setup 2 -from $imem_clk
set_multicycle_path -hold  1 -from $imem_clk
set_multicycle_path -setup 2 -from $rf_ram
set_multicycle_path -hold  1 -from $rf_ram
