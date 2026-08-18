###################################################################
# Makefile for virtual processor openpcie top level test bench
# code in Vivado xsim
#
# Copyright (C) 2025 Chili.CHIPS*ba
#
###################################################################

# --------------------------------------------
# Command line modifiable variables
# --------------------------------------------

# Node 2 (the stub test bench's root complex model) is not instantiated any
# more -- the DUT IS the root complex. What is always there is the endpoint
# model on node 1, plus the LTSSM helper it calls for link training. Node 0 is
# the SOC's CPU, and which model fills it is the CPU variable below.
USER_C           = ltssm.c
USRCODEDIR       = $(CURDIR)/usercode
PCIE_C           = VUserMain1.cpp
PCIECODEDIR      = $(CURDIR)/usercode
OPTFLAG          = -g
# TOPFILELIST      = top.prj
SOCCPUMATCH      = ip.cpu
VPROC_PLI        = VProc.so
USRSIMOPTS       =
USRCFLAGS        =
BUILD            = DEFAULT

# --------------------------------------------
# CPU model for the SOC (VProc node 0)
# --------------------------------------------
#   rtl   the real picorv32 core, executing the compiled firmware.hex out of
#         the SOC's instruction RAM. This is the configuration that goes into
#         the bitstream, so it is both the default and the reference.
#   vproc VProc running a native C++ program (usercode/VUserMain0.cpp) that
#         drives the very same CSR bus. No RISC-V involved at all.
#   iss   VProc running Simon's rv32 instruction set simulator on the real
#         firmware.elf -- real RISC-V instructions, interpreted rather than
#         executed by RTL.
#
# The DUT is identical in all three; only the module plugged into the CPU
# socket of riscv_pcie_soc.sv changes. See models/soc_cpu.VPROC.picorv32.sv.
CPU             ?= rtl

ifeq ("$(CPU)", "vproc")
  USER_C        += VUserMain0.cpp
  CPUDEFINE      = --define SOC_CPU_VPROC
else ifeq ("$(CPU)", "iss")
  BUILD          = ISS
  CPUDEFINE      = --define SOC_CPU_VPROC
else ifneq ("$(CPU)", "rtl")
  $(error CPU must be one of: rtl, vproc, iss  (got "$(CPU)"))
endif

# --------------------------------------------
# Global exported environment variables
# --------------------------------------------

HW_SRC          := $(CURDIR)/../2.rtl
BLD_DIR         := $(CURDIR)/../4.build
SIM_DIR         := $(CURDIR)/../5.sim
TB_NAME         := tb

export BLD_DIR HW_SRC SIM_DIR TB_NAME

# --------------------------------------------
# MSYS2 / MinGW environment repairs
# --------------------------------------------
# GNU make hands its recipes a shell with TMP, TEMP and TMPDIR all unset. gcc
# then falls back to C:\WINDOWS\, where it may not write, and every compile
# dies with "Cannot create temporary file". Put them back.
#
# NOTE: run this make file from a proper MSYS2 MinGW64 shell (mingw64.exe, or
# msys2_shell.cmd -mingw64). Vivado's xvlog/xelab/xsim launchers go through
# /usr/bin/cmd, which needs the environment that shell sets up; started from a
# foreign shell they fail silently with a non-zero exit and no output.

OSTYPE_RAW      := $(shell uname)

ifneq (,$(findstring MINGW,$(OSTYPE_RAW)))
  # make itself only inherits HOME here, so that is what the default is built
  # from. Override with  make LOCALTMP=/some/writable/dir  if need be.
  LOCALTMP      ?= $(HOME)/tmp
  $(shell mkdir -p $(LOCALTMP))
  export TMPDIR := $(LOCALTMP)
  export TMP    := $(LOCALTMP)
  export TEMP   := $(LOCALTMP)
endif

# --------------------------------------------
# VProc C/C++ variables
# --------------------------------------------

# Location of VProc and memory model libraries
COSIMDIR         = $(CURDIR)/models/cosim
PCIEDIR          = $(CURDIR)/models/pcievhost

# --------------------------------------------
# RV32 ISS variables
# --------------------------------------------
# Get OS type
OSTYPE           = $(shell uname)

#
# If BUILD is ISS, then override user source code list and directory
# and define extra flags
#
ifeq ("$(BUILD)", "ISS")

  ifeq ("$(OSTYPE)", "Linux")
    RV32LIB      = rv32lnx
  else
    RV32LIB      = rv32win
    RV32WINOPTS  = -lWs2_32
    RV32WINFILES = getopt.c
  endif

  USER_C         += VUserMain0.cpp mem_vproc_api.cpp uart.cpp rv32_cache.cpp vuserutils.cpp $(RV32WINFILES)
  USRCODEDIR     = $(CURDIR)/models/rv32/usercode

  RV32DIR        = $(CURDIR)/models/rv32
  RV32INCLOPTS   = -I$(RV32DIR)/include
  RV32LDOPTS     = -L$(RV32DIR)/lib -l$(RV32LIB) $(RV32WINOPTS)
endif

# --------------------------------------------
# VProc user code build variables
# --------------------------------------------

# Compiler executables and standard flags
CC               = gcc
C++              = g++
CPPSTD           = -std=c++20
ARCHFLAG         = -m64 

# C/C++ include paths for VProc, memory model and user code
# $(BLD_DIR)/csr_build/generated-files carries csr_cosim.h -- the PeakRDL
# generated register access classes the native C++ CPU model uses, so that it
# talks to the CSR through the same single source of truth as the firmware.
INCLPATHS        = -I$(USRCODEDIR) -I$(PCIECODEDIR) -I$(COSIMDIR)/include -I$(PCIEDIR)/include -I$(PCIEDIR)/ltssm -I$(BLD_DIR)/csr_build/generated-files $(RV32INCLOPTS)
DEFS             = -DVPROC_SV -DVPROC -DEXCLUDE_LTSSM

VOBJDIR          = $(CURDIR)/obj

# Separate C and C++ source files
USER_CPP_BASE    = $(notdir $(filter %cpp, $(USER_C) $(PCIE_C)))
USER_C_BASE      = $(notdir $(filter %c,   $(USER_C) $(PCIE_C)))

# Create list of object files (excluding any veriuser object)
VOBJS            = $(addprefix $(VOBJDIR)/,                   \
                    $(USER_C_BASE:%.c=%.o)                    \
                    $(USER_CPP_BASE:%.cpp=%.o))

USERLIB          = libuser.a

ifeq ("$(OSTYPE)", "Linux")
  COSIMLDOPT     = -lcosimlnx
  PCIELDOPT      = -lpcielnx
else
  COSIMLDOPT     = -lcosimwin
  PCIELDOPT      = -lpciewin
endif

ifeq ($(OSTYPE), Linux)
  FLAGSOS        = -shared -lpthread -lrt -rdynamic
else
  FLAGSOS        = -shared -Wl,-export-all-symbols
endif

# Flags for compiling/linking shared object
CFLAGS_SO        = $(ARCHFLAG)                         \
                   $(FLAGSOS) -lpthread                \
                   -Wl,-whole-archive                  \
                   -L$(CURDIR)      -luser             \
                   -Wl,-no-whole-archive               \
                   -L$(COSIMDIR)/lib $(COSIMLDOPT)     \
                   -L$(PCIEDIR)/lib  $(PCIELDOPT)      \
                   $(RV32LDOPTS)                       \
                   -o $(VPROC_PLI)

# --------------------------------------------
# Simulation variables
# --------------------------------------------

TBFILELIST       = $(TB_NAME).filelist

WORKDIR          = work

# Xilinx simulation libraries. The design instantiates PCIE_2_1 (secureip),
# plus MMCME2_ADV, BUFG, BUFGCTRL and IBUFDS_GTE2 (unisims). glbl carries the
# GSR/GTS nets those models expect, so it is elaborated as a second top.
# How long to run. 2 ms is enough to see the link train and reach L0. The
# firmware opens with wait_cycles(100000), which is tens of milliseconds on a
# 62.5 MHz picorv32, so seeing enumeration and the memory test needs more:
#   make run RUN_US=40000
RUN_US          ?= 2000

XILINX_VIVADO   ?= /c/Xilinx/Vivado/2024.2
GLBL             = $(XILINX_VIVADO)/data/verilog/src/glbl.v
XILLIBS          = -L unisims_ver -L unimacro_ver -L secureip

# firmware.hex is read by riscv_pcie_soc.sv with a bare name, so a copy has to
# sit in the simulation working directory. It is a product of the sw_build
# stage -- run that first.
FIRMWARE         = $(BLD_DIR)/sw_build/firmware.hex

# Flags for xsim
# SIM_FAST_TRAIN turns on the hard macro's shortened LTSSM training timers.
# It is a simulation-only parameter of PCIE_2_1 -- see silicon_core.sv.
ANALYSEFLAGS       = -i $(PCIEDIR)/verilog/headers --define VPROC_SV --define VPROC_BYTE_ENABLE --define SIM_FAST_TRAIN --define SIM_GEN1_ONLY --define SIM_PIPE_CODING $(CPUDEFINE) $(USRSIMOPTS) --prj tb.prj
ELABFLAGS          = -sv_lib $(VPROC_PLI) --timescale 1ps/1ps --debug typical $(XILLIBS) $(TB_NAME) glbl
# The snapshot xelab produces when two tops are elaborated is named
# "<top>#glbl". The hash has to be escaped or make treats the rest as a comment.
SIMFLAGS           = work.$(TB_NAME)\#work.glbl

# Get OS type
OSTYPE          := $(shell uname)

ifneq ($(OSTYPE), Linux)
  SIMLDFLAGS     = -Wl,-export-all-symbols
else
  SIMLDFLAGS     = -Wl,-E
endif

SIMMAKEFLAGS     = --quiet

XVLOG            = xvlog
XELAB            = xelab
SIMEXE           = xsim

#
# Formatting
#

SPC =

#======================================================
# BUILD RULES
#======================================================

.PHONY: all, compile, run, rungui, gui, help, clean

all: sysverilog

# Rule to build object file temporary directory
$(VOBJDIR):
	@mkdir $(VOBJDIR)

# Rule to build user C sources
$(VOBJDIR)/%.o: $(USRCODEDIR)/%.c
	@$(CC) -c -fPIC $(OPTFLAG) -Wno-write-strings $(DEFS) $(INCLPATHS) $< -o $@

# Rule to build user C++ sources
$(VOBJDIR)/%.o: $(USRCODEDIR)/%.cpp
	@$(C++) -c -fPIC $(OPTFLAGS) $(CPPSTD) -Wno-write-strings $(DEFS) $(INCLPATHS) $< -o $@

# Rule to build PCIe user C sources
$(VOBJDIR)/%.o: $(PCIECODEDIR)/%.c
	@$(CC) -c -fPIC $(OPTFLAG) -Wno-write-strings $(DEFS) $(INCLPATHS) $< -o $@

# Rule to build PCIe user C++ sources
$(VOBJDIR)/%.o: $(PCIECODEDIR)/%.cpp
	@$(C++) -c -fPIC $(OPTFLAGS) $(CPPSTD) -Wno-write-strings $(DEFS) $(INCLPATHS) $< -o $@

# Rule to build PCIe LTSSM support model
$(VOBJDIR)/%.o: $(PCIEDIR)/ltssm/%.c
	@$(CC) -c -fPIC $(OPTFLAG) -Wno-write-strings $(DEFS) $(INCLPATHS) $< -o $@

# Rule to build library of user code
$(USERLIB): $(VOBJDIR) $(VOBJS)
	@ar cr $(USERLIB) $(VOBJS)
    
# Rule to build VProc shared object
$(VPROC_PLI): $(USERLIB)
	@$(C++) $(CFLAGS_SO) -o $@

#
# Compile simulation
#
sysverilog: $(VPROC_PLI) firmware.hex
	@$(XVLOG) $(ANALYSEFLAGS)
	@$(XVLOG) $(GLBL)
	@$(XELAB) $(ELABFLAGS)

# Local copy of the firmware image for $readmemh
firmware.hex: $(FIRMWARE)
	@cp -f $< $@

$(FIRMWARE):
	@echo "================================================================"
	@echo " ERROR: $(FIRMWARE) is missing."
	@echo " Build the firmware first:  cd ../4.build/sw_build && make"
	@echo "================================================================"
	@exit 1

# Create local file list for top, with PicoRv32 files removed
# So soc_cpu.VPROC can be used instead
#$(TOPFILELIST): $(HW_SRC)/$(TOPFILELIST)
#	@sed -e "/$(SOCCPUMATCH)/d" $< > $@

#======================================================
# EXECUTION RULES
#======================================================

# tb.sv reads the run length from this file at time 0
run_us.cfg: FORCE
	@echo $(RUN_US) > $@

FORCE:

sim: sysverilog run_us.cfg
	@$(SIMEXE) $(SIMFLAGS)

run: sysverilog run_us.cfg
	@$(SIMEXE) -R $(SIMFLAGS)

rungui: sysverilog run_us.cfg
	@$(SIMEXE) -g --autoloadwcfg $(SIMFLAGS)

gui: rungui

help:
	@$(info make help          Display this message)
	@$(info make               Build C/C++ and HDL code without running simulation)
	@$(info make run           Build and run batch simulation)
	@$(info make rungui/gui    Build and run GUI simulation)
	@$(info make clean         clean previous build artefacts)
	@$(info )
	@$(info Command line configurable variables:)
	@$(info $(SPC) $(SPC) USER_C:       list of user source code files for soc_cpu (default VUserMain0.cpp))
	@$(info $(SPC) $(SPC) PCIE_C:       list of user source code files for pcievhost modules (default VUserMain1.cpp))
	@$(info $(SPC) $(SPC) USRCODEDIR:   directory containing user source code (default $$(CURDIR)/usercode))
	@$(info $(SPC) $(SPC) OPTFLAG:      Optimisation flag for user VProc code (default -g))
	@$(info $(SPC) $(SPC) SOCCPUMATCH:  string to match for soc_cpu filtering in h/w file list (default ip.cpu))
	@$(info $(SPC) $(SPC) USRSIMOPTS:   additional simulator analysis flags, such as setting defines (default blank))
	@$(info $(SPC) $(SPC) BUILD:        Select build type from DEFAULT or ISS (default DEFAULT))
	@$(info $(SPC) $(SPC) CPU:          CPU model on VProc node 0 (default rtl))
	@$(info $(SPC) $(SPC) $(SPC)   rtl    the real picorv32, executing firmware.hex)
	@$(info $(SPC) $(SPC) $(SPC)   vproc  native C++ in usercode/VUserMain0.cpp)
	@$(info $(SPC) $(SPC) $(SPC)   iss    the rv32 ISS, executing firmware.elf)
	@$(info $(SPC) $(SPC) RUN_US:       simulated run length in microseconds (default $(RUN_US)))
	@$(info )

#======================================================
# CLEANING RULES
#======================================================

clean:
	@rm -rf $(WORKDIR) $(VOBJDIR) $(USERLIB) $(VPROC_PLI) xelab.* xvlog.* xsim.* *.wdb .Xil
	@rm -rf firmware.hex run_us.cfg *.jou *.log webtalk*
