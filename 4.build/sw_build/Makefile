# SPDX-FileCopyrightText: 2026 Chili.CHIPS*ba
#
# SPDX-License-Identifier: BSD-3-Clause

# =============================================================================
# Firmware build for the picorv32 core inside RC-direct.opensource
#
# Run FROM THIS FOLDER:
#   make
#
# Flow:  start.S + main.c --gcc--> firmware.elf
#                        --objcopy--> firmware.bin
#                        --python--> firmware.hex
#
# All three outputs land in this folder. The hardware build consumes
# firmware.hex -- riscv_pcie_soc.sv reads it with $readmemh("firmware.hex", ram),
# one 32-bit word per line, hex, no prefix.
# =============================================================================

# ---- Paths ------------------------------------------------------------------
# Sources live in 3.sw/; this Makefile only builds, it does not hold sources.
SW_DIR = ../../3.sw

# ---- Toolchain --------------------------------------------------------------
# xPack GNU RISC-V Embedded GCC. Override CROSS if the prefix differs, e.g.
#   make CROSS=riscv64-unknown-elf-
CROSS   ?= riscv-none-elf-
CC       = $(CROSS)gcc
OBJCOPY  = $(CROSS)objcopy

# ---- Host differences -------------------------------------------------------
# On Windows make runs recipes through cmd.exe (SHELL defaults to sh.exe, but
# when sh.exe is absent make falls back to cmd), so the delete command differs.
ifeq ($(OS),Windows_NT)
    PYTHON ?= python
    RM_OUT  = del /q firmware.elf firmware.bin firmware.hex 2>nul
else
    PYTHON ?= python3
    RM_OUT  = rm -f firmware.elf firmware.bin firmware.hex
endif

# ---- Flags ------------------------------------------------------------------
# rv32i only -- picorv32 is configured without M/C extensions.
# -ffreestanding -nostdlib: no libc, no crt0; start.S provides the entry point.
ARCH    = -march=rv32i -mabi=ilp32
CFLAGS  = $(ARCH) -ffreestanding -nostdlib
LDFLAGS = -Wl,-Bstatic,-T,$(SW_DIR)/sections.lds,--strip-debug

# start.S must come first -- it holds the reset vector.
SRCS = $(SW_DIR)/start.S $(SW_DIR)/main.c
DEPS = $(SRCS) $(SW_DIR)/sections.lds

# =============================================================================
# TARGETS
# =============================================================================

.PHONY: all clean info help
.DEFAULT_GOAL := all

all: firmware.hex

help:
	@echo ================================================================
	@echo  Firmware build -- RC-direct.opensource
	@echo ================================================================
	@echo  make        build firmware.elf + .bin + .hex
	@echo  make info   print the resolved configuration
	@echo  make clean  remove the three generated files
	@echo ================================================================

info:
	@echo SW_DIR  : $(SW_DIR)
	@echo CC      : $(CC)
	@echo OBJCOPY : $(OBJCOPY)
	@echo PYTHON  : $(PYTHON)
	@echo SOURCES : $(SRCS)

# ---- 1) link ----------------------------------------------------------------
firmware.elf: $(DEPS)
	@echo ================================================================
	@echo  Compile + link  --^> firmware.elf
	@echo ================================================================
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SRCS)
	@echo OK -^> $@

# ---- 2) raw binary ----------------------------------------------------------
firmware.bin: firmware.elf
	@echo ================================================================
	@echo  objcopy  --^> firmware.bin
	@echo ================================================================
	$(OBJCOPY) -O binary $< $@
	@echo OK -^> $@

# ---- 3) hex for $readmemh ---------------------------------------------------
# One 32-bit little-endian word per line, 8 hex digits, no 0x prefix -- exactly
# what $readmemh expects.
firmware.hex: firmware.bin
	@echo ================================================================
	@echo  bin -^> hex  --^> firmware.hex
	@echo ================================================================
	$(PYTHON) -c "import struct; f=open('firmware.bin','rb'); d=f.read(); f.close(); [print('{:08x}'.format(struct.unpack('<I', d[i:i+4])[0])) for i in range(0, len(d), 4)]" > $@
	@echo ================================================================
	@echo  SUCCESS -- firmware.elf, firmware.bin, firmware.hex
	@echo ================================================================

clean:
	-$(RM_OUT)
