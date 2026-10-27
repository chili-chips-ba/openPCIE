# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause

# =============================================================================
# openXC7 build flow for the opensource RC
#
# Run FROM THIS FOLDER, on Linux or WSL:
#   source ../set-env.sh      (tcsh: source ../set-env.csh) -- finds the tools
#   make                      RC-direct, x4   (default)
#   make LANES=1              RC-direct, x1
#   make GEN=2                Gen2 (default: Gen1 at x4, Gen2 at x1)
#   make VARIANT=switched     RC-switched (x1 only)
#
# Bitstreams go to build_artifacts/, side by side, named for what they are:
# top.x4g1.direct.bit, top.x4g2.direct.bit, top.x1g2.direct.bit,
# top.x1g2.switched.bit. Everything else a build makes goes to its own
# build_artifacts/work/<build>/ (not in git), so builds never pick up each
# other's stale output.
# Each build also makes the firmware of its VARIANT, into its work folder, so a
# bitstream always carries the matching firmware.
#
# Flow, FRONTEND=slang (default, no sv2v):
#        .sv --yosys read_slang--> .json --nextpnr (himbaechel)--> .fasm
#            --fasm2frames--> .frames --xc7frames2bit--> .bit
# FRONTEND=sv2v:
#        .sv --sv2v--> .v --yosys--> .json --nextpnr (himbaechel)--> .fasm
#            --fasm2frames--> .frames --xc7frames2bit--> .bit
# ASSEMBLER=fpga-as replaces the last two steps with  --fpga-as--> .bit
# (not the default: it writes RXCDR_CFG wrong, #41).
#
# No recipe pipes a tool into tee: make's /bin/sh (dash on Ubuntu) has no
# set -o pipefail, so the exit status of tee would hide a tool crash. Tools
# write their logs directly, and their exit status is checked (see P&R).
#
# With FRONTEND=sv2v the SystemVerilog goes through sv2v in two steps:
#   1) batch conversion of ALL .sv together (so sv2v can resolve dependencies)
#   2) splitting all_converted.v into individual modules
# =============================================================================

# ---- openXC7 toolchain and front end ----------------------------------------
# openXC7 v1.0.0, as built by toolchain-sources-builder.sh
# (github.com/openXC7/toolchain-installer): Yosys with read_slang, the
# himbaechel engine behind a nextpnr-xilinx shim, prjxray, fpga-as. Source
# ../set-env.sh first; it sets NEXTPNR_XILINX_DIR and PRJXRAY_DB_DIR from the
# openXC7 prefix. The pre-v1.0.0 flow (nextpnr-xilinx 45a986b, Yosys 0.38) that
# built the board-tested bitstreams in build_artifacts/pre-v1.0.0/ is gone;
# commit 54c5409 is the last one that has it.
# FRONTEND=slang (default): Yosys's own SystemVerilog front end (read_slang), no
#   sv2v. Defines SYN_YOSYS_BUG for the RTL.
# FRONTEND=sv2v: SystemVerilog through sv2v first.
FRONTEND ?= slang
ifeq ($(filter slang sv2v,$(FRONTEND)),)
    $(error FRONTEND must be "sv2v" or "slang", got "$(FRONTEND)")
endif

OPENXC7_ROOT   ?= $(or $(NEXTPNR_XILINX_DIR),/opt/openxc7)
PRJXRAY_DB_DIR ?= $(OPENXC7_ROOT)/share/nextpnr/prjxray-db
XILINX_GEN      = $(OPENXC7_ROOT)/share/nextpnr/himbaechel/uarch/xilinx/gen/xilinx_gen.py

# ---- Tool binaries ----------------------------------------------------------
# Every tool is called through a variable. ../set-env.sh finds them and sets
# the environment; anything left unset falls back to the bare name on PATH.
# Single ones can be overridden on the command line as well, e.g.
#   make YOSYS=/opt/oss-cad-suite/bin/yosys
# OPENXC7_PYTHON runs the chipdb generators. It is the openXC7 venv's python3,
# which carries their packages -- not the PYTHON that MakefileCSR uses.
SV2V               ?= sv2v
YOSYS              ?= yosys
YOSYS_CONFIG       ?= yosys-config
NEXTPNR_XILINX     ?= nextpnr-xilinx
NEXTPNR_HIMBAECHEL ?= nextpnr-himbaechel
BBASM              ?= bbasm
FPGA_AS            ?= fpga-as
FASM2FRAMES        ?= $(firstword $(wildcard $(OPENXC7_ROOT)/venv/bin/fasm2frames) fasm2frames)
XC7FRAMES2BIT      ?= xc7frames2bit
OPENXC7_PYTHON     ?= python3

# FASM -> bitstream. ASSEMBLER=prjxray: fasm2frames + xc7frames2bit (default).
# ASSEMBLER=fpga-as: the v1.0.0 one-step assembler. Neither can compress the
# bitstream (lromor/fpga-assembler#59), so every one is 9.73 MB.
# FIXME: fpga-as v1.0.0 writes the 83-bit GTPE2_CHANNEL RXCDR_CFG wrong (keeps
# bits 0-23 only), on every lane. Fixed in lromor/fpga-assembler 282ef7c2, not
# in the v1.0.0 pin (hansfbaier/fpga-assembler cf0e3f08). Make fpga-as the
# default again once the toolchain ships the fix.
ASSEMBLER          ?= prjxray

# NEXTPNR_XILINX is the openXC7 shim that translates the nextpnr-xilinx flags
# for the himbaechel engine; it runs the engine named here
export NEXTPNR_HIMBAECHEL_BIN := $(NEXTPNR_HIMBAECHEL)

DB_DIR = $(PRJXRAY_DB_DIR)

# ---- Meta -------------------------------------------------------------------
# Acorn CLE-215P carries xc7a200tfbg484-3 (same as the Vivado build)
PART = xc7a200tfbg484-3

# ---- Variant ----------------------------------------------------------------
# direct   -> one endpoint on the far end of the link
# switched -> ASM1184e switch with up to 4 endpoints behind it.
# Both build the very same RTL, 2.rtl/0.common.opensource (top RC_opensource);
# they differ only in the GT lanes (XDC_FILE) and in the firmware.
VARIANT ?= direct

# ---- Link width -------------------------------------------------------------
# LANES=4 (default for direct) or 1; passed to link_pkg.sv as PCIE_LANES. x4
# runs only on the direct link: the switch ports are x1.
LANES ?= $(if $(filter switched,$(VARIANT)),1,4)

# ---- Link speed -------------------------------------------------------------
# GEN=1 or 2; passed to link_pkg.sv as PCIE_GEN. Default: Gen1 at x4 (x4 Gen2
# closes timing in Vivado only), Gen2 at x1. Width and speed set the user clock
# (pcie_pkg.sv USER_CLK_FREQ, the MMCM's CLKOUT2): 62.5 MHz at x1, 125 MHz at
# x4 Gen1, 250 MHz at x4 Gen2. nextpnr derives its period from the MMCM, so the
# XDC has none; USER_CLK_NS is for the info line only.
GEN_DEF = $(if $(filter 4,$(LANES)),1,2)
GEN    ?= $(GEN_DEF)
ifeq ($(filter 1 2,$(GEN)),)
    $(error GEN must be 1 or 2, got "$(GEN)")
endif
USER_CLK_NS = $(if $(filter 1,$(LANES)),16.000,$(if $(filter 1,$(GEN)),8.000,4.000))

# The bitstream's name says what it is for: lanes, Gen and variant, as in
# top.x4g1.direct.bit, top.x4g2.direct.bit, top.x1g2.direct.bit and
# top.x1g2.switched.bit. A non-default CPU (CPU=picorv32, edubos5_3stg)
# builds in its own work folder, named for it
LINK    = x$(LANES)g$(GEN)
BITFILE = top.$(LINK).$(VARIANT).bit
ifeq ($(filter 1 4,$(LANES)),)
    $(error LANES must be 1 or 4, got "$(LANES)")
endif

# ---- CPU --------------------------------------------------------------------
# edubos5 (src/CPU.eduBOS5, 2-stage), edubos5_3stg or picorv32; see
# riscv_pcie_soc.sv. Default: edubos5_3stg at x4 Gen2 (250 MHz user clock),
# else edubos5
CPU_DEF = $(if $(and $(filter 4,$(LANES)),$(filter 2,$(GEN))),edubos5_3stg,edubos5)
CPU    ?= $(CPU_DEF)
ifeq ($(filter picorv32 edubos5 edubos5_3stg,$(CPU)),)
    $(error CPU must be picorv32, edubos5 or edubos5_3stg, got "$(CPU)")
endif
CPU_SFX = $(if $(filter-out $(CPU_DEF),$(CPU)),.$(CPU))

TOP        = RC_opensource
COMMON_DIR = ../../2.rtl/0.common.opensource

ifeq ($(VARIANT),switched)
    ifneq ($(LANES),1)
        $(error RC-switched is x1 only -- the switch ports are x1)
    endif
    RTL_DIR   = ../../2.rtl/3.Bonus--RC-switched.opensource
    RTL_XDC   = $(RTL_DIR)/xdc/RC-switched.x1g2.AcornCLE-215P.xdc
    XDC_FILE  = openxc7.switched.xdc
else ifeq ($(VARIANT),direct)
    RTL_DIR   = ../../2.rtl/2.RC-direct.opensource
    RTL_XDC   = $(RTL_DIR)/xdc/RC-direct.$(if $(filter 4,$(LANES)),x4g1g2,x1g2).AcornCLE-215P.xdc
    XDC_FILE  = openxc7.x$(LANES).xdc
else
    $(error VARIANT must be "direct" or "switched", got "$(VARIANT)")
endif

# ---- CSR: soc_csr.sv wraps the register block PeakRDL generates from
# 4.build/csr_build/csr.rdl. Regenerate it first if csr.rdl changed:
#   cd .. && make -f MakefileCSR
CSR_GEN_DIR = ../csr_build/generated-files
SV_CSR_PKG  = $(CSR_GEN_DIR)/csr_pkg.sv
SV_CSR      = $(CSR_GEN_DIR)/csr.sv $(SRC_DIR)/soc_csr.sv

# ---- Paths (this Makefile lives in 4.build/hw_build.openXC7/) ---------------
# COMMON_DIR and RTL_DIR are set by the variant block above.
SRC_DIR  = $(COMMON_DIR)/src
PCIE_DIR = $(SRC_DIR)/pcie
# nextpnr-xilinx accepts only [get_ports]/[get_nets] targets, so it CANNOT read
# the full Vivado XDC from 2.rtl/ (shared part in $(COMMON_DIR)/xdc/, GT lane in
# $(RTL_DIR)/xdc/). A reduced version lives here, with only the pins, the
# clocks and the GT pad positions. XDC_FILE is set by the
# variant block above -- they differ only in the GT lanes:
#   openxc7.x1.xdc       C5/D5/C11/D11  -> GTP_CHANNEL_1 = GTPE2_CHANNEL_X0Y5  (lane 2)
#   openxc7.switched.xdc A6/B6/A10/B10  -> GTP_CHANNEL_2 = GTPE2_CHANNEL_X0Y6  (lane 0)
#   openxc7.x4.xdc       lanes 0..3     -> GTP_CHANNEL_2, 0, 1, 3
# The pin-to-channel mapping is straight out of prjxray package_pins.csv.

# firmware.hex: the firmware of this build's VARIANT, made by ../sw_build into
# the build's work folder (rule below WORK). riscv_pcie_soc.sv reads it via
# $readmemh with a bare name, so a copy must sit in Yosys' working directory.
# The tracked ../sw_build/firmware.hex stays the RC-direct board build.
FIRMWARE = $(WORK)/fw/firmware.hex

# ---- Output -----------------------------------------------------------------
# build_artifacts/ holds the bitstreams, side by side (in git), and work/ (not
# in git): the chipdb, and one folder per build for its netlist, FASM, frames,
# logs and sv2v output. Only the default build (default CPU, read_slang, the
# prjxray assembler, SEED 3) of a committed link (BIT_LINKS) writes its
# bitstream to build_artifacts/; any other keeps it in its own work folder, so
# it never replaces a committed one.
SEED_DEF  = 3
SEED     ?= $(SEED_DEF)
OUT_DIR   = build_artifacts
WORK_ROOT = $(OUT_DIR)/work
BUILD_SFX = $(CPU_SFX)$(if $(filter sv2v,$(FRONTEND)),.sv2v)$(if $(filter-out prjxray,$(ASSEMBLER)),.$(ASSEMBLER))$(if $(filter-out $(SEED_DEF),$(SEED)),.seed$(SEED))
WORK      = $(WORK_ROOT)/$(LINK).$(VARIANT)$(BUILD_SFX)
BIT_LINKS = x1g2 x4g1 x4g2
BIT_DIR   = $(if $(BUILD_SFX)$(filter-out $(BIT_LINKS),$(LINK)),$(WORK),$(OUT_DIR))
CHIPDB    = $(WORK_ROOT)/chipdb

# every build asks sw_build again (about a second), as the variant may differ
$(FIRMWARE): FORCE
	@$(MAKE) --no-print-directory -C ../sw_build VARIANT=$(VARIANT) OUT=$(abspath $(dir $(FIRMWARE)))

CONV_DIR      = $(WORK)/converted
EXTRACTED_DIR = $(CONV_DIR)/extracted

CONV_TIMESTAMP    = $(CONV_DIR)/.conversion_timestamp
EXTRACT_TIMESTAMP = $(EXTRACTED_DIR)/.extraction_timestamp

# Every make rebuilds the design from scratch (see the sv2v rule below). File
# dates cannot be trusted -- a tree on a network share, or copied off one, can
# carry timestamps from the future -- and switching LANES, GEN or CPU changes
# only defines and the file list, not any file. Rebuilding always sidesteps both. Only the chipdb, which
# depends on the part and not on the design, stays cached.
FORCE:

# =============================================================================
# SOURCE FILES
# =============================================================================

# Pure Verilog files -- these do not go through sv2v
#
PURE_V_FILES = \
    unimacro_shim.v

# SystemVerilog, ORDER MATTERS for sv2v:
#   package -> interfaces -> modules -> soc -> top
SV_PKG = $(PCIE_DIR)/link_pkg.sv $(PCIE_DIR)/pcie_pkg.sv

SV_IF = \
    $(PCIE_DIR)/axis_if.sv \
    $(PCIE_DIR)/trn_if.sv \
    $(PCIE_DIR)/cfg_if.sv \
    $(PCIE_DIR)/mem_if.sv \
    $(PCIE_DIR)/mim_if.sv \
    $(PCIE_DIR)/gtp_if.sv \
    $(PCIE_DIR)/pipe_if.sv

# All other .sv from pcie/, excluding the package and the interfaces.
SV_PCIE_REST = $(filter-out $(SV_PKG) $(SV_IF), $(sort $(wildcard $(PCIE_DIR)/*.sv)))

# The CPU is SystemVerilog (always_ff, typedef enum, unique case), so it goes
# through sv2v together with the rest of the design.
EDUBOS5_DIR = $(SRC_DIR)/CPU.eduBOS5
SV_CPU_picorv32 = $(SRC_DIR)/picorv32.CHILI.sv
SV_CPU_edubos5  = $(addprefix $(EDUBOS5_DIR)/,edubos5_pkg.sv edubos5_rf.sv edubos5_alu.sv edubos5.sv)
SV_CPU_edubos5_3stg = $(SV_CPU_edubos5)
CPU_DEFS = $(if $(filter picorv32,$(CPU)),-DSOC_CPU_PICORV32) \
           $(if $(filter edubos5_3stg,$(CPU)),-DSOC_EDUBOS5_3STG)

SV_TOP = \
    $(SV_CPU_$(CPU)) \
    $(SRC_DIR)/riscv_pcie_soc.sv \
    $(SRC_DIR)/$(TOP).sv

SV_ORDERED = $(SV_PKG) $(SV_CSR_PKG) $(SV_IF) $(SV_PCIE_REST) $(SV_CSR) $(SV_TOP)

# =============================================================================
# PHONY
# =============================================================================

.PHONY: all convert extract check-env check-sv2v check-sources \
        clean clean-converted clean-all info help FORCE

# Must be explicit. The default goal is otherwise the first target in the file,
# and that is the FORCE rule further up. Plain "make" then
# answers "Nothing to be done for 'FORCE'" and builds nothing.
.DEFAULT_GOAL := all

# A failed recipe must not leave a half-written target behind that looks up to
# date -- in particular a truncated .fasm or .bit.
.DELETE_ON_ERROR:

all: $(BIT_DIR)/$(BITFILE)

help:
	@echo "================================================================"
	@echo " openXC7 build -- opensource RC  [$(VARIANT) x$(LANES) Gen$(GEN), FRONTEND=$(FRONTEND)]"
	@echo "================================================================"
	@echo " make                 full build up to $(BIT_DIR)/$(BITFILE)"
	@echo " make LANES=1         RC-direct as x1 (default x4)"
	@echo " make GEN=2           x4 Gen2 (default x4 Gen1, x1 Gen2)"
	@echo " make VARIANT=switched  build the RC-switched variant (x1)"
	@echo " make CPU=picorv32   PicoRV32 instead of eduBOS5 (edubos5, edubos5_3stg also)"
	@echo " make FRONTEND=sv2v   through sv2v instead of read_slang"
	@echo " make ASSEMBLER=fpga-as  one-step assembler (writes RXCDR_CFG wrong, #41)"
	@echo " make SEED=<n>        another nextpnr seed (default $(SEED_DEF))"
	@echo "   Any non-default CPU, FRONTEND, ASSEMBLER or SEED keeps its bitstream in"
	@echo "   $(WORK_ROOT)/<build>/, so it never replaces a committed one."
	@echo " make convert         sv2v conversion + splitting only (FRONTEND=sv2v)"
	@echo " make check-env       verify the tools are present"
	@echo " make check-sources   verify all source files exist"
	@echo " make info            print the configuration"
	@echo " make clean           remove $(WORK)/"
	@echo " make clean-all       remove $(WORK_ROOT)/: every build's work folder and the chipdb"
	@echo "================================================================"

info:
	@echo "VARIANT        : $(VARIANT)"
	@echo "LANES          : $(LANES)"
	@echo "GEN            : $(GEN)  (user_clk $(USER_CLK_NS) ns)"
	@echo "CPU            : $(CPU)"
	@echo "FRONTEND       : $(FRONTEND)"
	@echo "BITSTREAM      : $(BIT_DIR)/$(BITFILE)"
	@echo "WORK           : $(WORK)"
	@echo "CHIPDB         : $(CHIPDB)"
	@echo "PART           : $(PART)"
	@echo "TOP            : $(TOP)"
	@echo "COMMON_DIR     : $(COMMON_DIR)"
	@echo "RTL_DIR        : $(RTL_DIR)"
	@echo "PRJXRAY_DB_DIR : $(PRJXRAY_DB_DIR)"
	@echo "XDC            : $(XDC_FILE)"
	@echo "firmware.hex   : $(FIRMWARE)"
	@echo "SV2V           : $(SV2V)"
	@echo "YOSYS          : $(YOSYS)"
	@echo "NEXTPNR_XILINX : $(NEXTPNR_XILINX)"
	@echo "NEXTPNR_HIMB.. : $(NEXTPNR_HIMBAECHEL)"
	@echo "BBASM          : $(BBASM)"
	@echo "FPGA_AS        : $(FPGA_AS)"
	@echo "OPENXC7_PYTHON : $(OPENXC7_PYTHON)"
	@echo "SV files       : $(words $(SV_ORDERED))"
	@echo "Pure .v        : $(words $(PURE_V_FILES))"

# =============================================================================
# CHECKS
# =============================================================================

check-env:
	@echo "Checking tools (openXC7 v1.0.0, FRONTEND=$(FRONTEND))..."
	@$(if $(filter sv2v,$(FRONTEND)),command -v $(SV2V) > /dev/null || (echo "ERROR: $(SV2V) not found (see: make check-sv2v)" && exit 1),true)
	@command -v $(YOSYS)              > /dev/null || (echo "ERROR: $(YOSYS) not found"                 && exit 1)
	@command -v $(YOSYS_CONFIG)       > /dev/null || (echo "ERROR: $(YOSYS_CONFIG) not found"          && exit 1)
	@command -v $(NEXTPNR_XILINX)     > /dev/null || (echo "ERROR: $(NEXTPNR_XILINX) (shim) not found" && exit 1)
	@command -v $(NEXTPNR_HIMBAECHEL) > /dev/null || (echo "ERROR: $(NEXTPNR_HIMBAECHEL) not found"    && exit 1)
	@command -v $(BBASM)              > /dev/null || (echo "ERROR: $(BBASM) not found"                 && exit 1)
	@$(if $(filter fpga-as,$(ASSEMBLER)),command -v $(FPGA_AS) > /dev/null || (echo "ERROR: $(FPGA_AS) not found" && exit 1),true)
	@$(if $(filter prjxray,$(ASSEMBLER)),command -v $(FASM2FRAMES) > /dev/null || (echo "ERROR: $(FASM2FRAMES) not found" && exit 1),true)
	@$(if $(filter prjxray,$(ASSEMBLER)),command -v $(XC7FRAMES2BIT) > /dev/null || (echo "ERROR: $(XC7FRAMES2BIT) not found" && exit 1),true)
	@command -v $(OPENXC7_PYTHON)     > /dev/null || (echo "ERROR: $(OPENXC7_PYTHON) not found"        && exit 1)
	@test -d "$(DB_DIR)/artix7" || (echo "ERROR: no prjxray-db for artix7 in $(DB_DIR)"        && exit 1)
	@test -f "$(XILINX_GEN)"    || (echo "ERROR: chipdb generator not found: $(XILINX_GEN)" && exit 1)
	@$(if $(filter slang,$(FRONTEND)),$(YOSYS) -p help 2>/dev/null | grep -q read_slang || (echo "ERROR: this yosys has no read_slang (needs 0.67+)" && exit 1),true)
	@echo "OK -- all tools present"

check-sv2v:
	@command -v $(SV2V) > /dev/null 2>&1 || ( \
	  echo "================================================================"; \
	  echo " $(SV2V) not found."; \
	  echo "================================================================"; \
	  echo " FRONTEND=sv2v needs sv2v (the default, FRONTEND=slang, does not)."; \
	  echo " Quickest way is the prebuilt binary:"; \
	  echo ""; \
	  echo "   wget https://github.com/zachjs/sv2v/releases/latest/download/sv2v-Linux.zip"; \
	  echo "   unzip sv2v-Linux.zip && mkdir -p ~/.local/bin"; \
	  echo "   cp sv2v-Linux/sv2v ~/.local/bin/ && chmod +x ~/.local/bin/sv2v"; \
	  echo "   export PATH=\"\$$HOME/.local/bin:\$$PATH\""; \
	  echo ""; \
	  echo " (Alternative: build from source via Haskell Stack, ~20 min.)"; \
	  echo "================================================================"; \
	  exit 1 )

check-sources:
	@missing=0; \
	for f in $(SV_ORDERED) $(PURE_V_FILES) $(XDC_FILE) \
	         $(RTL_XDC); do \
	    if [ ! -f "$$f" ]; then echo "MISSING: $$f"; missing=$$((missing+1)); fi; \
	done; \
	if [ $$missing -gt 0 ]; then \
	    echo "ERROR: $$missing file(s) missing"; \
	    exit 1; \
	else \
	    echo "OK -- $(words $(SV_ORDERED)) SV + $(words $(PURE_V_FILES)) V + xdc (firmware.hex: built per build)"; \
	fi

# =============================================================================
# 1) SV2V CONVERSION (batch -- all files together)
# =============================================================================

convert: $(EXTRACT_TIMESTAMP)

# FORCE: always reconvert, so every later step -- synthesis, place & route,
# bitstream -- runs again too. See the FORCE rule above.
$(CONV_TIMESTAMP): $(SV_ORDERED) FORCE | check-sv2v
	@echo "================================================================"
	@echo " sv2v: SystemVerilog -> Verilog  ($(words $(SV_ORDERED)) files)"
	@echo "================================================================"
	@mkdir -p $(CONV_DIR)
	@if $(SV2V) -DPCIE_LANES=$(LANES) -DPCIE_GEN=$(GEN) $(CPU_DEFS) -I$(PCIE_DIR) -I$(SRC_DIR) \
	        $(SV_ORDERED) > $(CONV_DIR)/all_converted.v 2> $(CONV_DIR)/sv2v.log; then \
	    echo "  lines   : $$(wc -l < $(CONV_DIR)/all_converted.v)"; \
	    echo "  modules : $$(grep -c '^module ' $(CONV_DIR)/all_converted.v)"; \
	    echo "OK -> $(CONV_DIR)/all_converted.v"; \
	else \
	    echo "ERROR: sv2v conversion failed. Log:"; \
	    cat $(CONV_DIR)/sv2v.log; \
	    exit 1; \
	fi
	@touch $@

# =============================================================================
# 2) SPLITTING all_converted.v INTO MODULES
# =============================================================================

extract: $(EXTRACT_TIMESTAMP)

$(EXTRACT_TIMESTAMP): $(CONV_TIMESTAMP)
	@echo "================================================================"
	@echo " Splitting into individual modules"
	@echo "================================================================"
	@rm -rf $(EXTRACTED_DIR)
	@mkdir -p $(EXTRACTED_DIR)
	@awk 'BEGIN { out=""; inmod=0 } \
	     /^module /  { name=$$2; gsub(/[(;#].*/,"",name); \
	                   out="$(EXTRACTED_DIR)/" name ".v"; inmod=1 } \
	     inmod       { print >> out } \
	     /^endmodule/{ if (inmod) { close(out); inmod=0 } }' \
	     $(CONV_DIR)/all_converted.v
	@echo "  extracted: $$(ls -1 $(EXTRACTED_DIR)/*.v 2>/dev/null | wc -l) modules"
	@touch $@

# =============================================================================
# 3) SYNTHESIS (Yosys)
# =============================================================================

ifeq ($(FRONTEND),slang)
# read_slang elaborates the whole hierarchy up front, so every Xilinx primitive
# the design instantiates must be declared, with its parameters. They come from
# Yosys's own library via gen_xilinx_bb.py (see that file for why). A new
# primitive in the RTL has to be added here, or read_slang reports it as an
# unknown module. SYN_YOSYS_BUG makes the RTL leave out what sv-elab cannot
# take yet (real-valued primitive parameters, povik/sv-elab#282).
XILINX_PRIMS = PCIE_2_1 GTPE2_CHANNEL GTPE2_COMMON MMCME2_ADV IBUFDS_GTE2 \
               BUFG BUFGCTRL FDCE RAMB36E1
SLANG_DEFS   = -D SYN_YOSYS_BUG -D PCIE_LANES=$(LANES) -D PCIE_GEN=$(GEN) $(CPU_DEFS)

$(WORK)/top.json: $(SV_ORDERED) $(PURE_V_FILES) $(FIRMWARE) gen_xilinx_bb.py FORCE
	@echo "================================================================"
	@echo " Synthesis (Yosys read_slang, no sv2v)  --  top: $(TOP), part: $(PART)"
	@echo "================================================================"
	@mkdir -p $(WORK)
	@cp -f $(FIRMWARE) firmware.hex
	$(OPENXC7_PYTHON) gen_xilinx_bb.py "$$($(YOSYS_CONFIG) --datdir)/xilinx" $(WORK)/xilinx_bb.sv $(XILINX_PRIMS)
	$(YOSYS) -l $(WORK)/yosys.log \
	      -p "read_slang $(SLANG_DEFS) --top $(TOP) -I $(PCIE_DIR) -I $(SRC_DIR) \
	                     $(WORK)/xilinx_bb.sv $(SV_ORDERED) $(PURE_V_FILES); \
	          proc; opt; clean; \
	          synth_xilinx -flatten -abc9 -arch xc7 -top $(TOP); \
	          write_json $@"
	@echo "OK -> $@"
else
$(WORK)/top.json: $(EXTRACT_TIMESTAMP) $(PURE_V_FILES) $(FIRMWARE)
	@echo "================================================================"
	@echo " Synthesis (Yosys)  --  top: $(TOP), part: $(PART)"
	@echo "================================================================"
	@mkdir -p $(WORK)
	@# riscv_pcie_soc does $readmemh("firmware.hex") with a bare name ->
	@# a copy must sit in Yosys' working directory
	@cp -f $(FIRMWARE) firmware.hex
	@# The GT channel is pinned through PACKAGE_PIN constraints on the GT
	@# pads themselves -- see openxc7.x*.xdc.
	$(YOSYS) -p "read_verilog $(wildcard $(EXTRACTED_DIR)/*.v) $(PURE_V_FILES); \
	          proc; opt; clean; \
	          synth_xilinx -flatten -abc9 -arch xc7 -top $(TOP); \
	          write_json $@"
	@echo "OK -> $@"
endif

# =============================================================================
# 4) CHIPDB (one-off, takes a while and a fair amount of RAM)
# =============================================================================

$(CHIPDB)/$(PART).bin:
	@echo "================================================================"
	@echo " Generating chipdb for $(PART) (himbaechel xilinx_gen.py)"
	@echo "================================================================"
	@mkdir -p $(CHIPDB)
	@test -f "$(XILINX_GEN)" || { echo "ERROR: cannot find $(XILINX_GEN)"; exit 1; }
	@# The engine's database is per die; the file name keeps the part, which
	@# the nextpnr-xilinx shim passes on as --device (accepted in part form)
	$(OPENXC7_PYTHON) $(XILINX_GEN) --xray $(DB_DIR)/artix7 --device xc7a200t --bba $(PART).bba
	$(BBASM) -l $(PART).bba $(CHIPDB)/$(PART).bin
	@rm -f $(PART).bba
	@echo "OK -> $@"

# =============================================================================
# 5) PLACE & ROUTE (nextpnr-xilinx)
# =============================================================================

$(WORK)/top.fasm: $(WORK)/top.json $(CHIPDB)/$(PART).bin $(XDC_FILE)
	@echo "================================================================"
	@echo " Place & Route (nextpnr-xilinx)"
	@echo "================================================================"
	@# --timing-allow-fail is INTENTIONAL: a timing miss must not stop the build.
	@# The achieved clocks are printed after P&R; x4 Gen2 misses its 250 MHz
	@# user_clk because nextpnr cannot apply the eduBOS5 multicycle paths (#110).
	@#
	@# The exit status is captured DIRECTLY, without piping into tee. Do not rely
	@# on  set -o pipefail : make uses /bin/sh, which on Ubuntu is dash and does
	@# NOT have that option -- it fails silently, so the exit status of tee
	@# (always 0) is what gets seen and a real nextpnr crash passes as success.
	@$(NEXTPNR_XILINX) \
	    --chipdb $(CHIPDB)/$(PART).bin \
	    --xdc $(XDC_FILE) \
	    --json $< \
	    --fasm $@ \
	    --write $(WORK)/top_routed.json \
	    --seed $(SEED) \
	    --timing-allow-fail \
	    --verbose \
	    > $(WORK)/nextpnr.log 2>&1; \
	rc=$$?; \
	tail -3 $(WORK)/nextpnr.log; \
	if [ $$rc -ne 0 ]; then \
	    echo "ERROR: nextpnr failed (rc=$$rc), see $(WORK)/nextpnr.log"; \
	    exit 1; \
	fi
	@test -s $@ || { echo "ERROR: $@ is empty or missing"; exit 1; }
	@echo "-- achieved clocks --"
	@grep -E "Max frequency" $(WORK)/nextpnr.log | tail -4
	@echo "-- checks --"
	@grep -oE "GTP_CHANNEL[A-Z0-9_]*_X[0-9]+Y[0-9]+" $@ | sort -u \
	    | sed 's/^/   GT channel: /'
	@grep -E "LINK_CAP_MAX_LINK_SPEED" $@ | sed 's/^/   /'
	@echo "OK -> $@"

# =============================================================================
# 6) BITSTREAM
# =============================================================================

ifeq ($(ASSEMBLER),fpga-as)
# fpga-as replaces fasm2frames + xc7frames2bit. It writes through a
# redirection; .DELETE_ON_ERROR removes a partial .bit if it fails.
$(BIT_DIR)/$(BITFILE): $(WORK)/top.fasm
	@echo "================================================================"
	@echo " FASM -> bitstream (fpga-as)"
	@echo "================================================================"
	@mkdir -p $(BIT_DIR)
	$(FPGA_AS) --prjxray_db_path=$(DB_DIR)/artix7 --part $(PART) < $< > $@
	@test -s $@ || { echo "ERROR: $@ is empty"; exit 1; }
	@echo "================================================================"
	@echo " SUCCESS -- bitstream: $@"
	@echo "================================================================"
	@ls -lh $@
else
$(WORK)/top.frames: $(WORK)/top.fasm
	@echo "================================================================"
	@echo " FASM -> frames"
	@echo "================================================================"
	$(FASM2FRAMES) --part $(PART) --db-root $(DB_DIR)/artix7 $< > $@
	@echo "OK -> $@"

$(BIT_DIR)/$(BITFILE): $(WORK)/top.frames
	@echo "================================================================"
	@echo " frames -> bitstream"
	@echo "================================================================"
	@mkdir -p $(BIT_DIR)
	$(XC7FRAMES2BIT) \
	    --part_file $(DB_DIR)/artix7/$(PART)/part.yaml \
	    --part_name $(PART) \
	    --frm_file $< \
	    --output_file $@
	@echo "================================================================"
	@echo " SUCCESS -- bitstream: $@"
	@echo "================================================================"
	@ls -lh $@
endif

# =============================================================================
# CLEANUP
# =============================================================================

# The bitstreams in build_artifacts/ stay: they are in git
clean:
	rm -rf $(WORK) firmware.hex

clean-converted:
	rm -rf $(CONV_DIR)

clean-all: clean
	rm -rf $(WORK_ROOT)

# -----------------------------------------------------------------------------
# Project:     openPCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        May 24, 2024
# -----------------------------------------------------------------------------
