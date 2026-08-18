# SPDX-FileCopyrightText: 2026 Chili.CHIPS*ba
#
# SPDX-License-Identifier: BSD-3-Clause

# =============================================================================
# Shared build configuration for openPCIE
#
# One file, read by every build step, so a choice made here holds everywhere:
#
#   4.build/sw_build/Makefile          the firmware
#   4.build/hw_build.openXC7/Makefile  the opensource bitstream
#   2.rtl/*/RC-*.opensource.tcl        the Vivado project
#
# Override for a single build without editing this file:
#
#   make CSR=legacy                    (either Makefile)
#   set ::use_legacy_csr 1             (before sourcing the Vivado tcl)
# =============================================================================

# ---- CSR back-end -----------------------------------------------------------
# peakrdl -> the register block is generated from 4.build/csr_build/csr.rdl,
#            and the firmware takes its register addresses from the headers
#            generated alongside it
# legacy  -> the hand-written register block inside riscv_pcie_soc.sv, and
#            addresses hard-coded in main.c. Nothing generated is used, so
#            "make -f MakefileCSR" never has to be run.
#
# The two describe the same register map and the firmware image is byte
# identical either way, so this is one choice, not two.
CSR ?= peakrdl
