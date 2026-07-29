# SPDX-FileCopyrightText: 2026 Chili.CHIPS*ba
#
# SPDX-License-Identifier: BSD-3-Clause

# =============================================================================
# openXC7 build flow for RC-direct.opensource
#
# Run FROM THIS FOLDER:
#   source /opt/openxc7/export.sh
#   make
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
TOP  = RC_direct_opensource

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
RTL_DIR  = ../../2.rtl/2.RC-direct.opensource
SRC_DIR  = $(RTL_DIR)/src
PCIE_DIR = $(SRC_DIR)/pcie
# nextpnr-xilinx accepts only [get_ports]/[get_nets] targets, so it CANNOT read
# the full Vivado XDC from 2.rtl/. A reduced version lives here; what was left
# out and why is documented in the header of that file.
XDC_FILE = openxc7.xdc

# firmware.hex is a product of the sw_build stage; riscv_pcie_soc.sv reads it via
# $readmemh with a bare name, so it must sit in Yosys' working directory.
FIRMWARE = ../sw_build/firmware.hex

CONV_DIR      = converted
EXTRACTED_DIR = $(CONV_DIR)/extracted
BUILD_ARTIFACTS = build_artifacts

CONV_TIMESTAMP    = $(CONV_DIR)/.conversion_timestamp
EXTRACT_TIMESTAMP = $(EXTRACTED_DIR)/.extraction_timestamp

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

SV_ORDERED = $(SV_PKG) $(SV_IF) $(SV_PCIE_REST) $(SV_TOP)

# =============================================================================
# PHONY
# =============================================================================

.PHONY: all convert extract check-env check-sv2v check-sources \
        clean clean-converted clean-all info help

all: $(BUILD_ARTIFACTS)/top.bit

help:
	@echo "================================================================"
	@echo " openXC7 build -- RC-direct.opensource"
	@echo "================================================================"
	@echo " make               full build up to top.bit"
	@echo " make convert       sv2v conversion + splitting only"
	@echo " make check-env     verify the tools are present"
	@echo " make check-sources verify all source files exist"
	@echo " make info          print the configuration"
	@echo " make clean         remove build_artifacts"
	@echo " make clean-all     remove converted/ and chipdb/ as well"
	@echo "================================================================"

info:
	@echo "PART           : $(PART)"
	@echo "TOP            : $(TOP)"
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
	         $(RTL_DIR)/xdc/RC-direct.sv.x1g2.AcornCLE-215P.xdc; do \
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

$(CONV_TIMESTAMP): $(SV_ORDERED) | check-sv2v
	@echo "================================================================"
	@echo " sv2v: SystemVerilog -> Verilog  ($(words $(SV_ORDERED)) files)"
	@echo "================================================================"
	@mkdir -p $(CONV_DIR)
	@if sv2v -I$(PCIE_DIR) -I$(SRC_DIR) \
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

# ---- THE SEED MATTERS -------------------------------------------------------
# The pipe clock (pcie_inst.clk_oobclk, 250 MHz in Gen2) sits right at the edge
# of what nextpnr achieves on this design. The critical path is not in the
# datapath but a reset-counter feedback loop in
# serdes_ctrl_i.lane_gen[0].lane_keeper_i:
#     FF.Q -> LUT -> CARRY4 -> 3x LUT -> FF.SR
#     4.5 ns  =  1.3 ns logic  +  3.2 ns routing
# Routing carries 71% of the path because the placer scatters the counter across
# ~11 rows.
#
# -----------------------------------------------------------------------------
# WHY A TIMING FAILURE IS ALLOWED (--timing-allow-fail)
# -----------------------------------------------------------------------------
# The 250 MHz constraint is deliberately PESSIMISTIC. The Vivado XDC has
# set_clock_groups -physically_exclusive on the two branches of the BUFGCTRL mux,
# plus 14 set_false_path on asynchronous GT/PCIe status lines. nextpnr accepts
# NONE of those commands, so it sees both mux branches as one clock and measures
# them at the faster one, and it counts the false paths as real. The metric is
# therefore stricter than the actual requirement.
#
# MEASURED ON HARDWARE -- every build that FAILS this metric works, while the
# only one that CLOSED 250 MHz (250.94 MHz, seed 4) does NOT work on the board:
#     probes on,  seed 3 -> 210 MHz    FAIL     link up, Gen2   OK
#     probes on,  seed 3 -> 229 MHz    FAIL     link up, Gen2   OK
#     probes on,  seed 4 -> 207 MHz    FAIL     link up, Gen2   OK
#     probes off, seed 3 -> 230 MHz    FAIL     link up, Gen2   OK
#     probes off, seed 4 -> 250.9 MHz  PASS     DOES NOT WORK
#
# Explanation: to squeeze the reset counter in lane_keeper_i (the tightest path),
# the placer stretches something the constraint model does NOT cover -- precisely
# what the missing set_false_path / set_clock_groups would have covered. Forcing
# this metric to close therefore actively BREAKS the design.
#
# There used to be a loop here that tried seeds until timing closed -- REMOVED,
# because it did exactly the wrong thing: it hunted for a placement that does not
# work on hardware.
#
# Proper fix (for later, not required for operation): port the equivalent of the
# missing set_false_path into openxc7.xdc, if/when nextpnr supports them. Only
# then does this metric become meaningful as a pass/fail criterion.
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
	rm -rf $(BUILD_ARTIFACTS) firmware.hex

clean-converted:
	rm -rf $(CONV_DIR)

clean-all: clean clean-converted
	rm -rf $(CHIPDB)
