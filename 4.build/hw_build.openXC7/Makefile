# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause

# =============================================================================
# openXC7 build flow for the opensource RC
#
# Run FROM THIS FOLDER:
#   source /opt/openxc7/export.sh
#   make                      RC-direct, x4   (default)
#   make LANES=1              RC-direct, x1
#   make VARIANT=switched     RC-switched (x1 only)
#
# Each variant and link width uses its own converted/ and build_artifacts/
# folders, so they do not overwrite each other and none picks up another one's
# stale output.
# What they DO share is ../sw_build/firmware.hex -- build the matching firmware
# first (make VARIANT=switched over in sw_build/).
#
# Flow (TOOLCHAIN=old, pre-v1.0.0, the one validated on hardware):
#        .sv --sv2v--> .v --yosys--> .json --nextpnr-xilinx--> .fasm
#            --fasm2frames--> .frames --xc7frames2bit--> .bit
# TOOLCHAIN=new  (openXC7 v1.0.0, the default; not yet tested on hardware),
# FRONTEND=slang (the default with TOOLCHAIN=new, no sv2v):
#        .sv --yosys read_slang--> .json --nextpnr (himbaechel)--> .fasm
#            --fpga-as--> .bit
# TOOLCHAIN=new FRONTEND=sv2v:
#        .sv --sv2v--> .v --yosys--> .json --nextpnr (himbaechel)--> .fasm
#            --fpga-as--> .bit
#
# Recipes that use a pipeline need  set -o pipefail  -- otherwise make sees the
# exit status of the last command in the pipe (tee) and a tool crash passes as
# success.
#
# The design is SystemVerilog (packages, interfaces, packed structs). Yosys reads
# it natively through read_slang (FRONTEND=slang). With FRONTEND=sv2v, and always
# with TOOLCHAIN=old, it goes through sv2v in two steps:
#   1) batch conversion of ALL .sv together (so sv2v can resolve dependencies)
#   2) splitting all_converted.v into individual modules
# =============================================================================

# ---- openXC7 installation ---------------------------------------------------
# openXC7 comes in two layouts, depending on how it was installed:
#   snap (official installer)  ->  /snap/openxc7/current/opt/nextpnr-xilinx
#                                  tools in /snap/bin, NO export.sh
#   nix / from source          ->  /opt/openxc7, with export.sh
# Both are searched. Everything can be overridden from the environment or the
# command line.

# ---- Toolchain and front end ------------------------------------------------
# TOOLCHAIN=old: the pre-v1.0.0 toolchain this project was validated with on
#   hardware -- nextpnr-xilinx 45a986b, Yosys 0.38, prjxray fasm2frames +
#   xc7frames2bit. See "THE nextpnr VERSION IS CRITICAL" below.
# TOOLCHAIN=new (default): openXC7 v1.0.0, as built by
#   toolchain-sources-builder.sh (github.com/openXC7/toolchain-installer) --
#   the himbaechel engine behind a nextpnr-xilinx shim, Yosys 0.67 or later,
#   fpga-as. Builds both variants; NOT yet tested on hardware. Source its
#   export.sh first.
# FRONTEND=slang (default with TOOLCHAIN=new): Yosys's own SystemVerilog front
#   end (read_slang), no sv2v. Defines SYN_YOSYS_BUG for the RTL.
# FRONTEND=sv2v: SystemVerilog through sv2v. The only choice with TOOLCHAIN=old
#   (Yosys 0.38 has no read_slang), so that is its default.
# New-toolchain output goes to its own folders (build_artifacts*.new,
# build_artifacts*.slang, chipdb.new), so it never touches the validated
# build_artifacts*/top.x1.*.bit.
TOOLCHAIN ?= new
FRONTEND  ?= $(if $(filter old,$(TOOLCHAIN)),sv2v,slang)

ifeq ($(TOOLCHAIN),new)
    # export.sh sets NEXTPNR_XILINX_DIR (and PRJXRAY_DB_DIR) to its prefix
    OPENXC7_ROOT   ?= $(or $(NEXTPNR_XILINX_DIR),/opt/openxc7)
    PRJXRAY_DB_DIR ?= $(OPENXC7_ROOT)/share/nextpnr/prjxray-db
    XILINX_GEN      = $(OPENXC7_ROOT)/share/nextpnr/himbaechel/uarch/xilinx/gen/xilinx_gen.py
    ifeq ($(FRONTEND),sv2v)
        TC_SFX = .new
    else ifeq ($(FRONTEND),slang)
        TC_SFX = .slang
    else
        $(error FRONTEND must be "sv2v" or "slang", got "$(FRONTEND)")
    endif
else ifeq ($(TOOLCHAIN),old)
    ifneq ($(FRONTEND),sv2v)
        $(error FRONTEND=$(FRONTEND) needs TOOLCHAIN=new -- Yosys 0.38 has no read_slang)
    endif
    # prjxray-db, metadata and constids MUST come from the same tree as nextpnr
    # -- mixing versions yields wrong wire indices. So everything is taken from
    # the submodules of the verified build, not from the snap. The new
    # toolchain's export.sh exports PRJXRAY_DB_DIR as well; it must not leak in
    # here, so only a command-line value overrides the search.
    NEXTPNR_SRC ?= /opt/openxc7_extra/npnr_45a986b
    ifneq ($(origin PRJXRAY_DB_DIR),command line)
        override PRJXRAY_DB_DIR := $(firstword $(wildcard \
            $(NEXTPNR_SRC)/xilinx/external/prjxray-db \
            /snap/openxc7/current/opt/nextpnr-xilinx/external/prjxray-db))
    endif
    TC_SFX =
else
    $(error TOOLCHAIN must be "old" or "new", got "$(TOOLCHAIN)")
endif

METADATA ?= $(firstword $(wildcard \
    $(NEXTPNR_SRC)/xilinx/external/nextpnr-xilinx-meta/artix7 \
    /snap/openxc7/current/opt/nextpnr-xilinx/external/nextpnr-xilinx-meta/artix7))

BBAEXPORT ?= $(firstword $(wildcard \
    $(NEXTPNR_SRC)/xilinx/python/bbaexport.py \
    /snap/openxc7/current/opt/nextpnr-xilinx/python/bbaexport.py))

CONSTIDS ?= $(wildcard $(NEXTPNR_SRC)/xilinx/constids.inc)

ifeq ($(PRJXRAY_DB_DIR),)
  ifeq ($(TOOLCHAIN),new)
    $(error Cannot find prjxray-db. Source the new toolchain's export.sh, or pass OPENXC7_ROOT=<prefix>)
  else
    $(error Cannot find prjxray-db. Build nextpnr 45a986b (see above) or pass: \
            make NEXTPNR_SRC=/path/to/nextpnr-xilinx)
  endif
endif

DB_DIR = $(PRJXRAY_DB_DIR)
# The two toolchains' chip databases are different formats
CHIPDB = chipdb$(if $(filter new,$(TOOLCHAIN)),.new)
# -nosrl only for the pre-v1.0.0 toolchain; see the note at synthesis
NOSRL  = $(if $(filter new,$(TOOLCHAIN)),,-nosrl)

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
# runs only on the direct link: the switch ports are x1. Direct x1 keeps the
# unsuffixed folders (build_artifacts/top.x1.direct.bit is the hardware-validated
# x1 build).
LANES ?= $(if $(filter switched,$(VARIANT)),1,4)

# The bitstream's name says what it is for: top.x4.direct.bit, top.x1.direct.bit,
# top.x1.switched.bit
BITFILE = top.x$(LANES).$(VARIANT).bit
ifeq ($(filter 1 4,$(LANES)),)
    $(error LANES must be 1 or 4, got "$(LANES)")
endif

TOP        = RC_opensource
COMMON_DIR = ../../2.rtl/0.common.opensource

ifeq ($(VARIANT),switched)
    ifneq ($(LANES),1)
        $(error RC-switched is x1 only -- the switch ports are x1)
    endif
    RTL_DIR   = ../../2.rtl/3.Bonus--RC-switched.opensource
    RTL_XDC   = $(RTL_DIR)/xdc/RC-switched.x1g2.AcornCLE-215P.xdc
    XDC_FILE  = openxc7.switched.xdc
    OUT_SFX   = .switched
else ifeq ($(VARIANT),direct)
    RTL_DIR   = ../../2.rtl/2.RC-direct.opensource
    RTL_XDC   = $(RTL_DIR)/xdc/RC-direct.x$(LANES)g2.AcornCLE-215P.xdc
    XDC_FILE  = openxc7.x$(LANES).xdc
    OUT_SFX   = $(if $(filter 4,$(LANES)),.x4)
else
    $(error VARIANT must be "direct" or "switched", got "$(VARIANT)")
endif

# ---- CSR: soc_csr.sv wraps the register block PeakRDL generates from
# 4.build/csr_build/csr.rdl. Regenerate it first if csr.rdl changed:
#   cd .. && make -f MakefileCSR
CSR_GEN_DIR = ../csr_build/generated-files
SV_CSR_PKG  = $(CSR_GEN_DIR)/csr_pkg.sv
SV_CSR      = $(CSR_GEN_DIR)/csr.sv $(SRC_DIR)/soc_csr.sv

# ---- THE nextpnr VERSION IS CRITICAL ----------------------------------------
# This design builds ONLY with nextpnr-xilinx around commit 45a986b
# (v0.8.2-79-g45a986b8, 2026-04-18).
#
#   snap 0.8.2 (Jun 2024)     -> too old: no site_type_PCIE_2_1.json, so the
#                                PCIE_2_1 site gets 0 BELs and placement fails
#   master bab26c2 (Jul 2026) -> REGRESSION: router2 enters an infinite loop in
#                                route_xilinx_const (confirmed by gdb stack trace)
#   45a986b (Apr 2026)        -> WORKS
#
# Building the correct version:
#   git clone https://github.com/openXC7/nextpnr-xilinx.git && cd nextpnr-xilinx
#   git checkout 45a986b
#   git submodule update --init --depth 1 \
#       xilinx/external/prjxray-db xilinx/external/nextpnr-xilinx-meta
#   mkdir build && cd build
#   cmake .. -DARCH=xilinx -DCMAKE_BUILD_TYPE=Release -DBUILD_GUI=OFF \
#            -DCMAKE_POLICY_VERSION_MINIMUM=3.5
#   make -j$(nproc) && install -Dm755 nextpnr-xilinx bbasm /usr/local/bin/
#
# Yosys 0.38 from the snap is entirely sufficient -- a newer one is NOT needed.
NEXTPNR_SRC ?= /opt/openxc7_extra/npnr_45a986b

# ---- Paths (this Makefile lives in 4.build/hw_build.openXC7/) ---------------
# COMMON_DIR and RTL_DIR are set by the variant block above.
SRC_DIR  = $(COMMON_DIR)/src
PCIE_DIR = $(SRC_DIR)/pcie
# nextpnr-xilinx accepts only [get_ports]/[get_nets] targets, so it CANNOT read
# the full Vivado XDC from 2.rtl/ (shared part in $(COMMON_DIR)/xdc/, GT lane in
# $(RTL_DIR)/xdc/). A reduced version lives here; what was left
# out and why is documented in the header of that file. XDC_FILE is set by the
# variant block above -- they differ only in the GT lanes:
#   openxc7.x1.xdc       C5/D5/C11/D11  -> GTP_CHANNEL_1 = GTPE2_CHANNEL_X0Y5  (lane 2)
#   openxc7.switched.xdc A6/B6/A10/B10  -> GTP_CHANNEL_2 = GTPE2_CHANNEL_X0Y6  (lane 0)
#   openxc7.x4.xdc       lanes 0..3     -> GTP_CHANNEL_2, 0, 1, 3
# The pin-to-channel mapping is straight out of prjxray package_pins.csv.

# firmware.hex is a product of the sw_build stage; riscv_pcie_soc.sv reads it via
# $readmemh with a bare name, so it must sit in Yosys' working directory.
FIRMWARE = ../sw_build/firmware.hex

CONV_DIR      = converted$(OUT_SFX)$(TC_SFX)
EXTRACTED_DIR = $(CONV_DIR)/extracted
BUILD_ARTIFACTS = build_artifacts$(OUT_SFX)$(TC_SFX)

CONV_TIMESTAMP    = $(CONV_DIR)/.conversion_timestamp
EXTRACT_TIMESTAMP = $(EXTRACTED_DIR)/.extraction_timestamp

# Every make rebuilds the design from scratch (see the sv2v rule below). File
# dates cannot be trusted -- a tree on a network share, or copied off one, can
# carry timestamps from the future -- and switching CSR changes only the file
# list, not any file. Rebuilding always sidesteps both. Only the chipdb, which
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
# _catB_backup/ holds the original Xilinx files as *.sv.orig -- the *.sv wildcard
# does not catch them, and they must not enter synthesis.
SV_PCIE_REST = $(filter-out $(SV_PKG) $(SV_IF), $(sort $(wildcard $(PCIE_DIR)/*.sv)))

# picorv32.CHILI.sv is SystemVerilog (always_ff, typedef enum, unique case),
# so the CPU goes through sv2v together with the rest of the design.
SV_TOP = \
    $(SRC_DIR)/picorv32.CHILI.sv \
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

all: $(BUILD_ARTIFACTS)/$(BITFILE)

help:
	@echo "================================================================"
	@echo " openXC7 build -- opensource RC  [$(VARIANT) x$(LANES), TOOLCHAIN=$(TOOLCHAIN), FRONTEND=$(FRONTEND)]"
	@echo "================================================================"
	@echo " make                 full build up to $(BITFILE)"
	@echo " make LANES=1         RC-direct as x1 (default x4)"
	@echo " make VARIANT=switched  build the RC-switched variant (x1)"
	@echo " make FRONTEND=sv2v   v1.0.0 through sv2v instead of read_slang"
	@echo " make TOOLCHAIN=old   pre-v1.0.0 toolchain (hardware-validated), sv2v"
	@echo " make convert         sv2v conversion + splitting only (FRONTEND=sv2v)"
	@echo " make check-env       verify the tools are present"
	@echo " make check-sources   verify all source files exist"
	@echo " make info            print the configuration"
	@echo " make clean           remove $(BUILD_ARTIFACTS)"
	@echo " make clean-all       remove $(CONV_DIR)/ and chipdb/ as well"
	@echo "================================================================"

info:
	@echo "VARIANT        : $(VARIANT)"
	@echo "LANES          : $(LANES)"
	@echo "TOOLCHAIN      : $(TOOLCHAIN)"
	@echo "FRONTEND       : $(FRONTEND)"
	@echo "BUILD_ARTIFACTS: $(BUILD_ARTIFACTS)"
	@echo "CHIPDB         : $(CHIPDB)"
	@echo "PART           : $(PART)"
	@echo "TOP            : $(TOP)"
	@echo "COMMON_DIR     : $(COMMON_DIR)"
	@echo "RTL_DIR        : $(RTL_DIR)"
	@echo "PRJXRAY_DB_DIR : $(PRJXRAY_DB_DIR)"
	@echo "BBAEXPORT      : $(BBAEXPORT)"
	@echo "XDC            : $(XDC_FILE)"
	@echo "firmware.hex   : $(FIRMWARE)"
	@echo "SV files       : $(words $(SV_ORDERED))"
	@echo "Pure .v        : $(words $(PURE_V_FILES))"

# =============================================================================
# CHECKS
# =============================================================================

ifeq ($(TOOLCHAIN),new)
check-env:
	@echo "Checking tools (new openXC7 toolchain, FRONTEND=$(FRONTEND))..."
	@$(if $(filter sv2v,$(FRONTEND)),which sv2v           > /dev/null || (echo "ERROR: sv2v not found (see: make check-sv2v)" && exit 1),true)
	@which yosys          > /dev/null || (echo "ERROR: yosys not found"                       && exit 1)
	@which yosys-config   > /dev/null || (echo "ERROR: yosys-config not found"                && exit 1)
	@which nextpnr-xilinx > /dev/null || (echo "ERROR: nextpnr-xilinx (shim) not found"       && exit 1)
	@which nextpnr-himbaechel > /dev/null || (echo "ERROR: nextpnr-himbaechel not found"      && exit 1)
	@which bbasm          > /dev/null || (echo "ERROR: bbasm not found"                       && exit 1)
	@which fpga-as        > /dev/null || (echo "ERROR: fpga-as not found"                     && exit 1)
	@which python3        > /dev/null || (echo "ERROR: python3 not found"                     && exit 1)
	@test -d "$(DB_DIR)/artix7" || (echo "ERROR: no prjxray-db for artix7 in $(DB_DIR)"        && exit 1)
	@test -f "$(XILINX_GEN)"    || (echo "ERROR: chipdb generator not found: $(XILINX_GEN)" && exit 1)
	@$(if $(filter slang,$(FRONTEND)),yosys -p help 2>/dev/null | grep -q read_slang || (echo "ERROR: this yosys has no read_slang (needs 0.67+)" && exit 1),true)
	@echo "OK -- all tools present"
else
check-env:
	@echo "Checking tools..."
	@which sv2v           > /dev/null || (echo "ERROR: sv2v not found (see: make check-sv2v)" && exit 1)
	@which yosys          > /dev/null || (echo "ERROR: yosys not found"                       && exit 1)
	@which nextpnr-xilinx > /dev/null || (echo "ERROR: nextpnr-xilinx not found"               && exit 1)
	@which fasm2frames    > /dev/null || (echo "ERROR: fasm2frames not found"                  && exit 1)
	@which xc7frames2bit  > /dev/null || (echo "ERROR: xc7frames2bit not found"                && exit 1)
	@which python3        > /dev/null || (echo "ERROR: python3 not found"                      && exit 1)
	@test -d "$(DB_DIR)/artix7" || (echo "ERROR: no prjxray-db for artix7 in $(DB_DIR)"        && exit 1)
	@test -f "$(METADATA)/site_type_PCIE_2_1.json" || ( \
	   echo "ERROR: site_type_PCIE_2_1.json missing in $(METADATA)"; \
	   echo "       Without it the PCIE_2_1 site gets 0 BELs and placement fails."; exit 1)
	@# the nextpnr version is critical -- see the comment at the top
	@nextpnr-xilinx --version 2>&1 | grep -q "45a986b" || ( \
	   echo "WARNING: nextpnr is not version 45a986b but:"; \
	   nextpnr-xilinx --version 2>&1 | head -1; \
	   echo "  master (bab26c2+) has a regression: infinite loop in route_xilinx_const"; \
	   echo "  snap 0.8.2 is too old: no PCIE_2_1 model"; \
	   echo "  See the instructions at the top of this Makefile.")
	@echo "OK -- all tools present"
endif

check-sv2v:
	@which sv2v > /dev/null 2>&1 || ( \
	  echo "================================================================"; \
	  echo " sv2v not found."; \
	  echo "================================================================"; \
	  echo " Yosys does not understand SystemVerilog packages/interfaces, so"; \
	  echo " sv2v is a mandatory step. Quickest way is the prebuilt binary:"; \
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
	for f in $(SV_ORDERED) $(PURE_V_FILES) $(XDC_FILE) $(FIRMWARE) \
	         $(RTL_XDC); do \
	    if [ ! -f "$$f" ]; then echo "MISSING: $$f"; missing=$$((missing+1)); fi; \
	done; \
	if [ $$missing -gt 0 ]; then \
	    echo "ERROR: $$missing file(s) missing"; \
	    echo "If firmware.hex is missing -- run the sw_build stage before this."; \
	    exit 1; \
	else \
	    echo "OK -- $(words $(SV_ORDERED)) SV + $(words $(PURE_V_FILES)) V + xdc + firmware.hex"; \
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
	@if sv2v -DPCIE_LANES=$(LANES) -I$(PCIE_DIR) -I$(SRC_DIR) \
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
SLANG_DEFS   = -D SYN_YOSYS_BUG -D PCIE_LANES=$(LANES)

$(BUILD_ARTIFACTS)/top.json: $(SV_ORDERED) $(PURE_V_FILES) $(FIRMWARE) gen_xilinx_bb.py FORCE
	@echo "================================================================"
	@echo " Synthesis (Yosys read_slang, no sv2v)  --  top: $(TOP), part: $(PART)"
	@echo "================================================================"
	@mkdir -p $(BUILD_ARTIFACTS)
	@cp -f $(FIRMWARE) firmware.hex
	python3 gen_xilinx_bb.py "$$(yosys-config --datdir)/xilinx" $(BUILD_ARTIFACTS)/xilinx_bb.sv $(XILINX_PRIMS)
	yosys -l $(BUILD_ARTIFACTS)/yosys.log \
	      -p "read_slang $(SLANG_DEFS) --top $(TOP) -I $(PCIE_DIR) -I $(SRC_DIR) \
	                     $(BUILD_ARTIFACTS)/xilinx_bb.sv $(SV_ORDERED) $(PURE_V_FILES); \
	          proc; opt; clean; \
	          synth_xilinx -flatten -abc9 $(NOSRL) -arch xc7 -top $(TOP); \
	          write_json $@"
	@echo "OK -> $@"
else
$(BUILD_ARTIFACTS)/top.json: $(EXTRACT_TIMESTAMP) $(PURE_V_FILES) $(FIRMWARE)
	@echo "================================================================"
	@echo " Synthesis (Yosys)  --  top: $(TOP), part: $(PART)"
	@echo "================================================================"
	@mkdir -p $(BUILD_ARTIFACTS)
	@# riscv_pcie_soc does $readmemh("firmware.hex") with a bare name ->
	@# a copy must sit in Yosys' working directory
	@cp -f $(FIRMWARE) firmware.hex
	@# NOTE on the GT pins:
	@# The built-in iopadmap also glues a plain IBUF/OBUF onto RXN/RXP/TXN/TXP,
	@# and those pins go straight into GTPE2_CHANNEL. The obvious remedy would be
	@#     synth_xilinx ... -noiopad
	@#     iopadmap ... -ignore GTPE2_CHANNEL GTPRXP:GTPRXN:GTPTXP:GTPTXN ...
	@# but -ignore in yosys 0.38 ENTERS AN INFINITE LOOP (99% CPU, RSS flat,
	@# >25 min with no end; the same command without -ignore finishes in ~25 s).
	@# So the default flow stays, and the GT channel is pinned via PACKAGE_PIN
	@# constraints on the GT pads themselves -- see openxc7.xdc.
	@#
	@# -nosrl history (see README, "-nosrl at synthesis"):
	@#   pre-v1.0.0: required. Yosys turns the PLL0 power-up shift registers into
	@#     SRLC32E chains, and nextpnr fails on the cascade output:
	@#     ERROR: No wire found for port Q31 on source cell ... fpga_srl_0
	@#   v1.0.0: fixed, so NOSRL (top of file) drops the flag there (216 fewer FFs).
	@#
	@# NOTE: -nocarry is NOT needed. It was only required with the broken master
	@# nextpnr; with version 45a986b the carry chains route cleanly.
	yosys -p "read_verilog $(wildcard $(EXTRACTED_DIR)/*.v) $(PURE_V_FILES); \
	          proc; opt; clean; \
	          synth_xilinx -flatten -abc9 $(NOSRL) -arch xc7 -top $(TOP); \
	          write_json $@"
	@echo "OK -> $@"
endif

# =============================================================================
# 4) CHIPDB (one-off, takes a while and a fair amount of RAM)
# =============================================================================

ifeq ($(TOOLCHAIN),new)
$(CHIPDB)/$(PART).bin:
	@echo "================================================================"
	@echo " Generating chipdb for $(PART) (himbaechel xilinx_gen.py)"
	@echo "================================================================"
	@mkdir -p $(CHIPDB)
	@test -f "$(XILINX_GEN)" || { echo "ERROR: cannot find $(XILINX_GEN)"; exit 1; }
	@# The engine's database is per die; the file name keeps the part, which
	@# the nextpnr-xilinx shim passes on as --device (accepted in part form)
	python3 $(XILINX_GEN) --xray $(DB_DIR)/artix7 --device xc7a200t --bba $(PART).bba
	bbasm -l $(PART).bba $(CHIPDB)/$(PART).bin
	@rm -f $(PART).bba
	@echo "OK -> $@"
else
$(CHIPDB)/$(PART).bin:
	@echo "================================================================"
	@echo " Generating chipdb for $(PART) -- takes a few minutes"
	@echo "================================================================"
	@mkdir -p $(CHIPDB)
	@test -n "$(BBAEXPORT)" || { echo "ERROR: cannot find bbaexport.py"; exit 1; }
	@# --metadata and --constids are passed explicitly so nothing gets mixed with
	@# the snap's metadata (which lacks site_type_PCIE_2_1.json)
	python3 $(BBAEXPORT) --device $(PART) \
	    --xray $(DB_DIR)/artix7 \
	    $(if $(METADATA),--metadata $(METADATA)) \
	    $(if $(CONSTIDS),--constids $(CONSTIDS)) \
	    --bba $(PART).bba
	bbasm -l $(PART).bba $(CHIPDB)/$(PART).bin
	@rm -f $(PART).bba
	@echo "OK -> $@"
endif

# =============================================================================
# 5) PLACE & ROUTE (nextpnr-xilinx)
# =============================================================================

SEED ?= 3

$(BUILD_ARTIFACTS)/top.fasm: $(BUILD_ARTIFACTS)/top.json $(CHIPDB)/$(PART).bin $(XDC_FILE)
	@echo "================================================================"
	@echo " Place & Route (nextpnr-xilinx)"
	@echo "================================================================"
	@# --timing-allow-fail is INTENTIONAL -- see the rationale above. Failing the
	@# 250 MHz metric is expected and verified harmless; forcing closure breaks it.
	@#
	@# The exit status is captured DIRECTLY, without piping into tee. Do not rely
	@# on  set -o pipefail : make uses /bin/sh, which on Ubuntu is dash and does
	@# NOT have that option -- it fails silently, so the exit status of tee
	@# (always 0) is what gets seen and a real nextpnr crash passes as success.
	@nextpnr-xilinx \
	    --chipdb $(CHIPDB)/$(PART).bin \
	    --xdc $(XDC_FILE) \
	    --json $< \
	    --fasm $@ \
	    --write $(BUILD_ARTIFACTS)/top_routed.json \
	    --seed $(SEED) \
	    --timing-allow-fail \
	    --verbose \
	    > $(BUILD_ARTIFACTS)/nextpnr.log 2>&1; \
	rc=$$?; \
	tail -3 $(BUILD_ARTIFACTS)/nextpnr.log; \
	if [ $$rc -ne 0 ]; then \
	    echo "ERROR: nextpnr failed (rc=$$rc), see $(BUILD_ARTIFACTS)/nextpnr.log"; \
	    exit 1; \
	fi
	@test -s $@ || { echo "ERROR: $@ is empty or missing"; exit 1; }
	@echo "-- achieved clocks (a failure on clk_oobclk is expected) --"
	@grep -E "Max frequency" $(BUILD_ARTIFACTS)/nextpnr.log | tail -4
	@echo "-- checks --"
	@grep -oE "GTP_CHANNEL[A-Z0-9_]*_X[0-9]+Y[0-9]+" $@ | sort -u \
	    | sed 's/^/   GT channel: /'
	@grep -E "LINK_CAP_MAX_LINK_SPEED" $@ | sed 's/^/   /'
	@echo "OK -> $@"

# =============================================================================
# 6) BITSTREAM
# =============================================================================

ifeq ($(TOOLCHAIN),new)
# fpga-as replaces fasm2frames + xc7frames2bit. It writes through a
# redirection; .DELETE_ON_ERROR removes a partial .bit if it fails.
$(BUILD_ARTIFACTS)/$(BITFILE): $(BUILD_ARTIFACTS)/top.fasm
	@echo "================================================================"
	@echo " FASM -> bitstream (fpga-as)"
	@echo "================================================================"
	fpga-as --prjxray_db_path=$(DB_DIR)/artix7 --part $(PART) < $< > $@
	@test -s $@ || { echo "ERROR: $@ is empty"; exit 1; }
	@echo "================================================================"
	@echo " SUCCESS -- bitstream: $@"
	@echo "================================================================"
	@ls -lh $@
else
$(BUILD_ARTIFACTS)/top.frames: $(BUILD_ARTIFACTS)/top.fasm
	@echo "================================================================"
	@echo " FASM -> frames"
	@echo "================================================================"
	fasm2frames --part $(PART) --db-root $(DB_DIR)/artix7 $< > $@
	@echo "OK -> $@"

$(BUILD_ARTIFACTS)/$(BITFILE): $(BUILD_ARTIFACTS)/top.frames
	@echo "================================================================"
	@echo " frames -> bitstream"
	@echo "================================================================"
	xc7frames2bit \
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

clean:
	rm -rf $(BUILD_ARTIFACTS) firmware.hex .build-config$(OUT_SFX)

clean-converted:
	rm -rf $(CONV_DIR)

clean-all: clean clean-converted
	rm -rf $(CHIPDB)
