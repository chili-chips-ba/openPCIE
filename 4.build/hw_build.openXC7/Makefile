# SPDX-FileCopyrightText: 2026 Chili.CHIPS*ba
#
# SPDX-License-Identifier: BSD-3-Clause

# =============================================================================
# openXC7 build flow for the opensource RC
#
# Run FROM THIS FOLDER:
#   source /opt/openxc7/export.sh
#   make                      RC-direct   (default)
#   make VARIANT=switched     RC-switched
#
# The two variants use separate converted/ and build_artifacts/ folders, so they
# do not overwrite each other and neither picks up the other one's stale output.
# What they DO share is ../sw_build/firmware.hex -- build the matching firmware
# first (make VARIANT=switched over in sw_build/).
#
# Flow:  .sv --sv2v--> .v --yosys--> .json --nextpnr-xilinx--> .fasm
#            --fasm2frames--> .frames --xc7frames2bit--> .bit
#
# Recipes that use a pipeline need  set -o pipefail  -- otherwise make sees the
# exit status of the last command in the pipe (tee) and a tool crash passes as
# success.
#
# The design is SystemVerilog (a package + 2 interfaces + packed structs), which
# Yosys does not understand. Hence sv2v in two steps, as in the wireguard-fpga
# project:
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

# prjxray-db, metadata and constids MUST come from the same tree as nextpnr --
# mixing versions yields wrong wire indices. So everything is taken from the
# submodules of the verified build, not from the snap.
PRJXRAY_DB_DIR ?= $(firstword $(wildcard \
    $(NPNR_SRC)/xilinx/external/prjxray-db \
    /snap/openxc7/current/opt/nextpnr-xilinx/external/prjxray-db))

METADATA ?= $(firstword $(wildcard \
    $(NPNR_SRC)/xilinx/external/nextpnr-xilinx-meta/artix7 \
    /snap/openxc7/current/opt/nextpnr-xilinx/external/nextpnr-xilinx-meta/artix7))

BBAEXPORT ?= $(firstword $(wildcard \
    $(NPNR_SRC)/xilinx/python/bbaexport.py \
    /snap/openxc7/current/opt/nextpnr-xilinx/python/bbaexport.py))

CONSTIDS ?= $(wildcard $(NPNR_SRC)/xilinx/constids.inc)

ifeq ($(PRJXRAY_DB_DIR),)
$(error Cannot find prjxray-db. Build nextpnr 45a986b (see above) or pass: \
        make NPNR_SRC=/path/to/nextpnr-xilinx)
endif

DB_DIR = $(PRJXRAY_DB_DIR)
CHIPDB = chipdb

# ---- Meta -------------------------------------------------------------------
# Acorn CLE-215P carries xc7a200tfbg484-3 (same as the Vivado build)
PART = xc7a200tfbg484-3

# ---- Variant ----------------------------------------------------------------
# direct   -> one endpoint on the far end of the link
# switched -> ASM1184e switch with up to 4 endpoints behind it. The only RTL
#             difference is in riscv_pcie_soc.sv, which derives the Type 0 /
#             Type 1 code of a Configuration TLP from the target bus number.
VARIANT ?= direct

ifeq ($(VARIANT),switched)
    TOP       = RC_switched_opensource
    RTL_DIR   = ../../2.rtl/3.Bonus--RC-switched.opensource
    RTL_XDC   = $(RTL_DIR)/xdc/RC-switched.sv.x1g2.AcornCLE-215P.xdc
    XDC_FILE  = openxc7.switched.xdc
    OUT_SFX   = .switched
else ifeq ($(VARIANT),direct)
    TOP       = RC_direct_opensource
    RTL_DIR   = ../../2.rtl/2.RC-direct.opensource
    RTL_XDC   = $(RTL_DIR)/xdc/RC-direct.sv.x1g2.AcornCLE-215P.xdc
    XDC_FILE  = openxc7.xdc
    OUT_SFX   =
else
    $(error VARIANT must be "direct" or "switched", got "$(VARIANT)")
endif

# ---- CSR back-end -----------------------------------------------------------
# peakrdl -> riscv_pcie_soc.sv instantiates soc_csr.sv, which wraps the register
#            block PeakRDL generates from 4.build/csr_build/csr.rdl. This is the
#            default. Regenerate the RTL first if csr.rdl changed:
#              cd .. && make -f MakefileCSR
# legacy  -> the hand-written register block inside riscv_pcie_soc.sv, selected
#            with `define SOC_CSR_LEGACY. Kept as the reference implementation.
#
# The two are functionally identical, down to the byte offsets, so the firmware
# does not care which one is in the bitstream.
# The choice lives in one place, ../config.mk, so that the hardware and the
# firmware are always built the same way. Override it for a single build with
#   make CSR=legacy
# A command line assignment wins over the file.
-include ../config.mk

CSR ?= peakrdl

CSR_GEN_DIR = ../csr_build/generated-files

ifeq ($(CSR),peakrdl)
    SV_CSR_PKG = $(CSR_GEN_DIR)/csr_pkg.sv
    SV_CSR     = $(CSR_GEN_DIR)/csr.sv $(SRC_DIR)/soc_csr.sv
    SV2V_DEFS  =
else ifeq ($(CSR),legacy)
    SV_CSR_PKG =
    SV_CSR     =
    SV2V_DEFS  = -DSOC_CSR_LEGACY
else
    $(error CSR must be "peakrdl" or "legacy", got "$(CSR)")
endif

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
NPNR_SRC ?= /opt/openxc7_extra/npnr_45a986b

# ---- Paths (this Makefile lives in 4.build/hw_build.openXC7/) ---------------
# RTL_DIR is set by the variant block above.
SRC_DIR  = $(RTL_DIR)/src
PCIE_DIR = $(SRC_DIR)/pcie
# nextpnr-xilinx accepts only [get_ports]/[get_nets] targets, so it CANNOT read
# the full Vivado XDC from 2.rtl/. A reduced version lives here; what was left
# out and why is documented in the header of that file. XDC_FILE is set by the
# variant block above -- the two differ only in the GT lane:
#   openxc7.xdc          C5/D5/C11/D11  -> GTP_CHANNEL_1 = GTPE2_CHANNEL_X0Y5  (lane 2)
#   openxc7.switched.xdc A6/B6/A10/B10  -> GTP_CHANNEL_2 = GTPE2_CHANNEL_X0Y6  (lane 0)
# The pin-to-channel mapping is straight out of prjxray package_pins.csv.

# firmware.hex is a product of the sw_build stage; riscv_pcie_soc.sv reads it via
# $readmemh with a bare name, so it must sit in Yosys' working directory.
FIRMWARE = ../sw_build/firmware.hex

CONV_DIR      = converted$(OUT_SFX)
EXTRACTED_DIR = $(CONV_DIR)/extracted
BUILD_ARTIFACTS = build_artifacts$(OUT_SFX)

CONV_TIMESTAMP    = $(CONV_DIR)/.conversion_timestamp
EXTRACT_TIMESTAMP = $(EXTRACTED_DIR)/.extraction_timestamp

# Records the configuration the last build used, so that make can see a change
# that lives only in a variable. Rewritten only when the signature really
# changes, so an unchanged setup never re-triggers a build. One per variant,
# matching the per-variant output directories.
BUILD_CFG = .build-config$(OUT_SFX)
BUILD_SIG := $(VARIANT)-$(CSR)

$(BUILD_CFG): FORCE
	@[ "$$(cat $@ 2>/dev/null)" = "$(BUILD_SIG)" ] || echo "$(BUILD_SIG)" > $@

FORCE:

# =============================================================================
# SOURCE FILES
# =============================================================================

# Pure Verilog files -- these do not go through sv2v
#
# xpm_shim.v: open replacement for xpm_cdc_single. Vivado supplies that macro
# itself from the XPM library, Yosys/openXC7 do not have it. See the comment in
# the file.
PURE_V_FILES = \
    $(SRC_DIR)/picorv32.v \
    xpm_shim.v \
    unimacro_shim.v

# SystemVerilog, ORDER MATTERS for sv2v:
#   package -> interfaces -> modules -> soc -> top
SV_PKG = $(PCIE_DIR)/link_pkg.sv

SV_IF = \
    $(PCIE_DIR)/stream_if.sv \
    $(PCIE_DIR)/phy_lanes_if.sv

# All other .sv from pcie/, excluding the package and the interfaces.
# _catB_backup/ holds the original Xilinx files as *.sv.orig -- the *.sv wildcard
# does not catch them, and they must not enter synthesis.
SV_PCIE_REST = $(filter-out $(SV_PKG) $(SV_IF), $(sort $(wildcard $(PCIE_DIR)/*.sv)))

SV_TOP = \
    $(SRC_DIR)/riscv_pcie_soc.sv \
    $(SRC_DIR)/$(TOP).sv

SV_ORDERED = $(SV_PKG) $(SV_CSR_PKG) $(SV_IF) $(SV_PCIE_REST) $(SV_CSR) $(SV_TOP)

# =============================================================================
# PHONY
# =============================================================================

.PHONY: all convert extract check-env check-sv2v check-sources \
        clean clean-converted clean-all info help FORCE

# Must be explicit. The default goal is otherwise the first target in the file,
# and that is the FORCE rule up in the BUILD_CFG section (.build-config is
# skipped, make never picks a target starting with a period). Plain "make" then
# answers "Nothing to be done for 'FORCE'" and builds nothing.
.DEFAULT_GOAL := all

all: $(BUILD_ARTIFACTS)/top.bit

help:
	@echo "================================================================"
	@echo " openXC7 build -- opensource RC  [$(VARIANT), CSR=$(CSR)]"
	@echo "================================================================"
	@echo " make                 full build up to top.bit"
	@echo " make VARIANT=switched  build the RC-switched variant"
	@echo " make CSR=legacy      build with the hand-written CSR instead"
	@echo " make convert         sv2v conversion + splitting only"
	@echo " make check-env       verify the tools are present"
	@echo " make check-sources   verify all source files exist"
	@echo " make info            print the configuration"
	@echo " make clean           remove $(BUILD_ARTIFACTS)"
	@echo " make clean-all       remove $(CONV_DIR)/ and chipdb/ as well"
	@echo "================================================================"

info:
	@echo "VARIANT        : $(VARIANT)"
	@echo "CSR            : $(CSR)"
	@echo "PART           : $(PART)"
	@echo "TOP            : $(TOP)"
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

# Switching CSR changes only the FILE LIST, not any file, so without the two
# extra prerequisites below make would compare the timestamp against unchanged
# sources, decide it is up to date, and quietly leave the previous conversion --
# and therefore the previous bitstream -- in place. See BUILD_SIG above.
# (VARIANT needs no such guard: it selects a separate $(CONV_DIR) and
# $(BUILD_ARTIFACTS), so the two variants never share an output.)
$(CONV_TIMESTAMP): $(SV_ORDERED) $(wildcard ../config.mk) $(BUILD_CFG) | check-sv2v
	@echo "================================================================"
	@echo " sv2v: SystemVerilog -> Verilog  ($(words $(SV_ORDERED)) files)"
	@echo "================================================================"
	@mkdir -p $(CONV_DIR)
	@if sv2v -I$(PCIE_DIR) -I$(SRC_DIR) $(SV2V_DEFS) \
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
	@# -nosrl is the ONLY required flag. Yosys would otherwise turn the
	@# wake_timer shift registers into SRLC32E chains, and nextpnr then fails on
	@# the cascade output:
	@#   ERROR: No wire found for port Q31 on source cell ... fpga_srl_0
	@# Without SRLs these are plain flip-flops -- 224 extra FFs on a chip with
	@# 269200. This is a build-flow choice; the RTL is NOT touched.
	@#
	@# NOTE: -nocarry is NOT needed. It was only required with the broken master
	@# nextpnr; with version 45a986b the carry chains route cleanly.
	yosys -p "read_verilog $(wildcard $(EXTRACTED_DIR)/*.v) $(PURE_V_FILES); \
	          proc; opt; clean; \
	          synth_xilinx -flatten -abc9 -nosrl -arch xc7 -top $(TOP); \
	          write_json $@"
	@echo "OK -> $@"

# =============================================================================
# 4) CHIPDB (one-off, takes a while and a fair amount of RAM)
# =============================================================================

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

$(BUILD_ARTIFACTS)/top.frames: $(BUILD_ARTIFACTS)/top.fasm
	@echo "================================================================"
	@echo " FASM -> frames"
	@echo "================================================================"
	fasm2frames --part $(PART) --db-root $(DB_DIR)/artix7 $< > $@
	@echo "OK -> $@"

$(BUILD_ARTIFACTS)/top.bit: $(BUILD_ARTIFACTS)/top.frames
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

# =============================================================================
# CLEANUP
# =============================================================================

clean:
	rm -rf $(BUILD_ARTIFACTS) firmware.hex $(BUILD_CFG)

clean-converted:
	rm -rf $(CONV_DIR)

clean-all: clean clean-converted
	rm -rf $(CHIPDB)
