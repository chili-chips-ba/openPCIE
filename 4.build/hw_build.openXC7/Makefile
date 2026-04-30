# =============================================================================
# openXC7 Makefile - Work in progress
# Couple of RTL files are still missing!
# =============================================================================

PREFIX ?= /opt/openxc7

ifndef PRJXRAY_DB_DIR
$(error Please run: source $(PREFIX)/setup_env.sh)
endif

# =============================================================================
# CONFIGURATION
# =============================================================================

PART = xc7a200tfbg484-3

DB_DIR = $(PREFIX)/share/prjxray-db
CHIPDB = ../chipdb

RTL_DIR = 2.rtl/2.RC-direct.opensource
BUILD_ARTIFACTS = 4.build/hw_build.openXC7/build_artifacts

TOP = RC_direct_opensource
XDC_FILE = $(RTL_DIR)/xdc/RC-direct.opensource.x1g2.AcornCLE-215P.xdc

# =============================================================================
# RTL SOURCES
# =============================================================================

SRC_FILES = \
	$(RTL_DIR)/RC_direct_opensource.v \
	$(RTL_DIR)/pcie_7x_0_support.v \
	$(RTL_DIR)/riscv_pcie_soc.v \
	$(RTL_DIR)/pcie_7x_0_pipe_clock.v \
	$(RTL_DIR)/picorv32.v

# =============================================================================
# TARGETS
# =============================================================================

.PHONY: all
all: $(BUILD_ARTIFACTS)/top.bit

# =============================================================================
# SYNTHESIS
# =============================================================================

$(BUILD_ARTIFACTS)/top.json: $(SRC_FILES) $(CHIPDB)/$(PART).bin
	@echo "================================================================"
	@echo "Synthesis stage (Yosys)"
	@echo "================================================================"
	@mkdir -p $(BUILD_ARTIFACTS)
	@echo "Top module: $(TOP)"
	@echo "FPGA part: $(PART)"
	@echo ""
	yosys -p "proc; opt; clean; delete t:\$$scopeinfo; synth_xilinx -flatten -abc9 -arch xc7 -top $(TOP); write_json $@" \
		$(SRC_FILES)
	@echo ""
	@echo "✓ Synthesis complete: $@"

# =============================================================================
# CHIPDB GENERATION
# =============================================================================

$(CHIPDB)/$(PART).bin:
	@echo "================================================================"
	@echo "Generating chipdb for $(PART)"
	@echo "================================================================"
	@echo "This may take several minutes..."
	@mkdir -p $(CHIPDB)

	python3 $(PREFIX)/share/nextpnr-xilinx/python/bbaexport.py \
		--device $(PART) \
		--bba $(PART).bba

	bbasm -l $(PART).bba $(CHIPDB)/$(PART).bin

	rm -f $(PART).bba

	@echo ""
	@echo "✓ Chipdb generated: $@"

# =============================================================================
# PLACE AND ROUTE
# =============================================================================

$(BUILD_ARTIFACTS)/top.fasm: $(BUILD_ARTIFACTS)/top.json $(CHIPDB)/$(PART).bin
	@echo "================================================================"
	@echo "Place and Route stage (nextpnr-xilinx)"
	@echo "================================================================"

	nextpnr-xilinx \
		--chipdb $(CHIPDB)/$(PART).bin \
		--xdc $(XDC_FILE) \
		--json $< \
		--fasm $@ \
		--verbose --debug \
		2>&1 | tee $(BUILD_ARTIFACTS)/nextpnr.log

	@echo ""
	@echo "✓ Place and Route complete: $@"

# =============================================================================
# BITSTREAM GENERATION
# =============================================================================

$(BUILD_ARTIFACTS)/top.frames: $(BUILD_ARTIFACTS)/top.fasm
	@echo "================================================================"
	@echo "FASM to frames conversion"
	@echo "================================================================"

	fasm2frames \
		--part $(PART) \
		--db-root $(DB_DIR)/artix7 \
		$< > $@

	@echo ""
	@echo "✓ Frames file created: $@"

$(BUILD_ARTIFACTS)/top.bit: $(BUILD_ARTIFACTS)/top.frames
	@echo "================================================================"
	@echo "Bitstream generation"
	@echo "================================================================"

	xc7frames2bit \
		--part_file $(DB_DIR)/artix7/$(PART)/part.yaml \
		--part_name $(PART) \
		--frm_file $< \
		--output_file $@

	@echo "================================================================"
	@echo "SUCCESS! Bitstream created:"
	@echo "$(BUILD_ARTIFACTS)/top.bit"
	@echo "================================================================"

	@ls -lh $(BUILD_ARTIFACTS)/top.bit

# =============================================================================
# CLEAN
# =============================================================================

.PHONY: clean
clean:
	rm -rf $(BUILD_ARTIFACTS)

.PHONY: clean-all
clean-all: clean
	rm -rf $(CHIPDB)