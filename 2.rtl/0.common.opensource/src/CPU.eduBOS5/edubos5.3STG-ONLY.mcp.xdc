# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# eduBOS5 3-stage pipeline (EN_WAIT4REGS=1) only: multicycle paths, Vivado.
# Derived from the RTL, for the openPCIE SOC hierarchy (riscv_pcie_soc.sv).
#
# In FETCH_INSTR the core drives next_pc to the instruction port. The fetched
# word, and the register file read it addresses, are stable through WAIT4REGS
# and EXECUTE; whatever uses them is captured at the end of EXECUTE or later.
# So paths from these two sources have 2 cycles:
#   - the SOC RAM's port B: eduBOS5's instruction port (port A carries the data
#     loads, a 1-cycle path, so it stays single-cycle)
#   - the register file LUT-RAMs, written in FETCH_INSTR
# Do not use with the 2-stage pipeline: there these paths are 1 cycle.
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
