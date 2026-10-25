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
#   - the SOC RAM's port B: eduBOS5's instruction port (port A carries the data
#     loads, a 1-cycle path, so it stays single-cycle)
#   - the register file LUT-RAMs, written in FETCH_INSTR
# Do not use with the 2-stage pipeline: there these paths are 1 cycle.
#
# Proof: assertions in edubos5.sv, for simulation (`define EDUBOS5_MCP_CHECK)
# and formal (`define EDUBOS5_MCP_FORMAL, formal/run-mcp-formal.sh): both
# sources change only on the edge that ends a fetch state and hold 2 clocks
# from the edge into WAIT4REGS, and no register they feed loads at the 1st
# edge after it (go2exec).
#
# Uses post-synthesis names (inferred RAMs): read it after synth_design, or
# mark it implementation-only (USED_IN_SYNTHESIS false).

set imem_clk [get_pins -of_objects [get_cells -hier -filter {NAME =~ u_soc/ram_reg*}] \
                       -filter {REF_PIN_NAME == CLKBWRCLK}]
set rf_ram   [get_cells -hier -filter {NAME =~ u_soc/cpu/u_rf/* && IS_PRIMITIVE && REF_NAME =~ RAMD32*}]

set_multicycle_path -setup 2 -from $imem_clk
set_multicycle_path -hold  1 -from $imem_clk
set_multicycle_path -setup 2 -from $rf_ram
set_multicycle_path -hold  1 -from $rf_ram
