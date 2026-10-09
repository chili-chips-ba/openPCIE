# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause

# =============================================================================
# Firmware build for the picorv32 core inside the opensource RC
#
# Run FROM THIS FOLDER:
#   make                      RC-direct   firmware (default)
#   make VARIANT=switched     RC-switched firmware
#
# Flow:  start.S + pcie.c + main.c --gcc--> firmware.elf
#                        --objcopy--> firmware.bin
#                        --python--> firmware.hex
#
# All three outputs land in this folder. The hardware build consumes
# firmware.hex -- riscv_pcie_soc.sv reads it with $readmemh("firmware.hex", ram),
# one 32-bit word per line, hex, no prefix.
#
# The two variants share the output names. Every make rebuilds from scratch
# (see FORCE below), so switching variant needs no make clean.
# =============================================================================

# ---- Variant ----------------------------------------------------------------
# direct   -> 3.sw/RC-direct    : one endpoint, straight RC-to-EP link
# switched -> 3.sw/RC-switched  : ASM1184e switch with up to 4 endpoints
VARIANT ?= direct

ifeq ($(VARIANT),switched)
    SW_SUBDIR = RC-switched
else ifeq ($(VARIANT),direct)
    SW_SUBDIR = RC-direct
else
    $(error VARIANT must be "direct" or "switched", got "$(VARIANT)")
endif

# ---- CSR back-end -----------------------------------------------------------
# The choice lives in one place, ../config.mk, so that the firmware and the
# hardware are always built the same way. Override it for a single build with
#   make CSR=legacy
# A command line assignment wins over the file.
-include ../config.mk

CSR ?= peakrdl

ifeq ($(CSR),peakrdl)
    CSR_DIR    = ../csr_build/generated-files
    CSR_CFLAGS = -DUSE_PEAKRDL_CSR -I$(CSR_DIR)
    CSR_DEPS   = $(CSR_DIR)/csr.h $(CSR_DIR)/openpcie_regs.h
else ifeq ($(CSR),legacy)
    CSR_CFLAGS =
    CSR_DEPS   =
else
    $(error CSR must be "legacy" or "peakrdl", got "$(CSR)")
endif

# ---- Simulation build -------------------------------------------------------
# SIM=1 shortens the start-up delay in main.c. That loop waits for the PCIe link
# to train, which matters on hardware but not in co-simulation, where the link
# is already up before the SOC leaves reset -- and where the loop, compiled
# without optimisation, costs about 80 ms of simulated time.
SIM ?= 0

ifeq ($(SIM),1)
    SIM_CFLAGS = -DSTARTUP_DELAY=200
else
    SIM_CFLAGS =
endif

# ---- Paths ------------------------------------------------------------------
# Sources live in 3.sw/; this Makefile only builds, it does not hold sources.
# 3.sw/common/ holds what both variants share (start.S, sections.lds, the PCIe
# request layer pcie.c/.h); the variant folder holds only its main.c.
SW_DIR     = ../../3.sw/$(SW_SUBDIR)
COMMON_DIR = ../../3.sw/common

# ---- Toolchain --------------------------------------------------------------
# xPack GNU RISC-V Embedded GCC. Override CROSS if the prefix differs, e.g.
#   make CROSS=riscv64-unknown-elf-
CROSS   ?= riscv-none-elf-
CC       = $(CROSS)gcc
OBJCOPY  = $(CROSS)objcopy

# ---- MSYS2 / MinGW ----------------------------------------------------------
# GNU make on MSYS2 hands its recipes a shell with TMP, TEMP and TMPDIR unset.
# gcc then falls back to C:\WINDOWS\, where it may not write, and the compile
# dies with "Cannot create temporary file". Put them back.
OSTYPE_RAW := $(shell uname 2>/dev/null)

ifneq (,$(findstring MINGW,$(OSTYPE_RAW)))
    LOCALTMP      ?= $(HOME)/tmp
    $(shell mkdir -p $(LOCALTMP))
    export TMPDIR := $(LOCALTMP)
    export TMP    := $(LOCALTMP)
    export TEMP   := $(LOCALTMP)
endif

# ---- Host differences -------------------------------------------------------
# On Windows make runs recipes through cmd.exe (SHELL defaults to sh.exe, but
# when sh.exe is absent make falls back to cmd), so the delete command differs.
# OS=Windows_NT is set under MSYS2 as well, but there the recipes run in a POSIX
# shell that has no "del", so the test has to be on the shell, not on the OS.
ifneq (,$(findstring MINGW,$(OSTYPE_RAW)))
    PYTHON ?= python
    RM_OUT  = rm -f firmware.elf firmware.bin firmware.hex .build-config
else ifeq ($(OS),Windows_NT)
    PYTHON ?= python
    RM_OUT  = del /q firmware.elf firmware.bin firmware.hex .build-config 2>nul
else
    PYTHON ?= python3
    RM_OUT  = rm -f firmware.elf firmware.bin firmware.hex .build-config
endif

# ---- Flags ------------------------------------------------------------------
# rv32i only -- picorv32 is configured without M/C extensions.
# -ffreestanding -nostdlib: no libc, no crt0; start.S provides the entry point.
ARCH    = -march=rv32i -mabi=ilp32
CFLAGS  = $(ARCH) -ffreestanding -nostdlib -I$(COMMON_DIR) $(CSR_CFLAGS) $(SIM_CFLAGS)
LDFLAGS = -Wl,-Bstatic,-T,$(COMMON_DIR)/sections.lds,--strip-debug

# start.S must come first -- it holds the reset vector.
SRCS = $(COMMON_DIR)/start.S $(COMMON_DIR)/pcie.c $(SW_DIR)/main.c

# The firmware is ALWAYS rebuilt - it takes about a second. make decides what to
# rebuild from file dates alone, and two things defeat that here:
#
#   - a configuration that leaves no trace on disk: switch VARIANT, CSR or SIM
#     and it would compare the same sources against the same outputs, report
#     "Nothing to be done", and leave the PREVIOUS image sitting there;
#   - dates that cannot be trusted: a tree on a network share, or copied off
#     one, can carry timestamps from the future, so a stale firmware.hex looks
#     newer than everything it was built from.
#
# FORCE on firmware.elf closes both, with no bookkeeping to go wrong.
FORCE:

DEPS = $(SRCS) $(COMMON_DIR)/pcie.h $(COMMON_DIR)/sections.lds $(CSR_DEPS) FORCE

# =============================================================================
# TARGETS
# =============================================================================

.PHONY: all clean info help FORCE
.DEFAULT_GOAL := all

all: firmware.hex

help:
	@echo ================================================================
	@echo  Firmware build -- opensource RC
	@echo ================================================================
	@echo  make                     build firmware.elf + .bin + .hex
	@echo  make VARIANT=switched    build the RC-switched firmware
	@echo  make CSR=legacy          hard-coded register map instead of PeakRDL
	@echo  make SIM=1               short start-up delay, for co-simulation
	@echo  make info                print the resolved configuration
	@echo  make clean               remove the three generated files
	@echo ================================================================

info:
	@echo VARIANT : $(VARIANT)
	@echo CSR     : $(CSR)
	@echo SIM     : $(SIM)
	@echo SW_DIR  : $(SW_DIR)
	@echo CC      : $(CC)
	@echo OBJCOPY : $(OBJCOPY)
	@echo PYTHON  : $(PYTHON)
	@echo SOURCES : $(SRCS)

# ---- 1) link ----------------------------------------------------------------
firmware.elf: $(DEPS)
	@echo ================================================================
	@echo  Compile and link into firmware.elf   [$(VARIANT), CSR=$(CSR), SIM=$(SIM)]
	@echo ================================================================
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SRCS)
	@echo OK: $@

# ---- 2) raw binary ----------------------------------------------------------
firmware.bin: firmware.elf
	@echo ================================================================
	@echo  objcopy into firmware.bin
	@echo ================================================================
	$(OBJCOPY) -O binary $< $@
	@echo OK: $@

# ---- 3) hex for $readmemh ---------------------------------------------------
# One 32-bit little-endian word per line, 8 hex digits, no 0x prefix -- exactly
# what $readmemh expects.
firmware.hex: firmware.bin
	@echo ================================================================
	@echo  bin to hex into firmware.hex
	@echo ================================================================
	$(PYTHON) -c "import struct; f=open('firmware.bin','rb'); d=f.read(); f.close(); [print('{:08x}'.format(struct.unpack('<I', d[i:i+4])[0])) for i in range(0, len(d), 4)]" > $@
	@echo ================================================================
	@echo  SUCCESS -- firmware.elf, firmware.bin, firmware.hex
	@echo ================================================================

clean:
	-$(RM_OUT)
