###################################################################
# Makefile for virtual processor openpcie top level test bench
# code in Vivado xsim
#
# Copyright (C) 2025 Chili.CHIPS
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
VPROC_PLI        = VProc.so
USRSIMOPTS       =
BUILD            = DEFAULT

# --------------------------------------------
# CPU model for the SOC (VProc node 0)
# --------------------------------------------
#   rtl   the real RTL core (CORE below), executing the compiled firmware.hex
#         out of the SOC's instruction RAM. This is the configuration that goes
#         into the bitstream, so it is both the default and the reference.
#   vproc VProc running a native C++ program (usercode/VUserMain0.cpp) that
#         drives the very same CSR bus. No RISC-V involved at all.
#   iss   VProc running Simon's rv32 instruction set simulator on the real
#         firmware.elf -- real RISC-V instructions, interpreted rather than
#         executed by RTL.
#
# The DUT is identical in all three; only the module plugged into the CPU
# socket of riscv_pcie_soc.sv changes. See models/soc_cpu.VPROC.picorv32.sv.
CPU             ?= rtl

# The RISC-V core: edubos5 (default, 2-stage), edubos5_3stg or picorv32.
# CPU=rtl builds that core; CPU=iss uses its timing model (-V in vusermain.cfg).
CORE            ?= edubos5
ifeq ("$(CORE)", "edubos5")
  ISS_CORE       = EDUBOS5STG2
else ifeq ("$(CORE)", "edubos5_3stg")
  ISS_CORE       = EDUBOS5STG3
  CORE_DEFINE    = --define SOC_EDUBOS5_3STG
else ifeq ("$(CORE)", "picorv32")
  ISS_CORE       = PICORV32
  CORE_DEFINE    = --define SOC_CPU_PICORV32
else
  $(error CORE must be one of: edubos5, edubos5_3stg, picorv32  (got "$(CORE)"))
endif

ifeq ("$(CPU)", "vproc")
  USER_C        += VUserMain0.cpp
  CPUDEFINE      = --define SOC_CPU_VPROC
else ifeq ("$(CPU)", "iss")
  BUILD          = ISS
  CPUDEFINE      = --define SOC_CPU_VPROC
else ifeq ("$(CPU)", "rtl")
  CPUDEFINE      = $(CORE_DEFINE)
else
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
# VProc C/C++ variables
# --------------------------------------------

# Location of VProc and memory model libraries
COSIMDIR         = $(CURDIR)/models/cosim
PCIEDIR          = $(CURDIR)/models/pcievhost

# --------------------------------------------
# RV32 ISS variables
# --------------------------------------------
#
# If BUILD is ISS, then override user source code list and directory
# and define extra flags
#
ifeq ("$(BUILD)", "ISS")
  USER_C         += VUserMain0.cpp mem_vproc_api.cpp uart.cpp rv32_cache.cpp vuserutils.cpp
  USRCODEDIR     = $(CURDIR)/models/rv32/usercode

  RV32DIR        = $(CURDIR)/models/rv32
  RV32SRC        = $(RV32DIR)/src
  RV32INCLOPTS   = -I$(RV32SRC)
  # the ISS library is built here from the rv32 sources (upstream iss/src)
  RV32OBJDIR     = $(CURDIR)/obj/rv32
  RV32LIB        = $(RV32OBJDIR)/librv32.a
  RV32LDOPTS     = $(RV32LIB)
  RV32_CPP       = rv32i_cpu_elf rv32_cpu_gdb rv32i_cpu rv32csr_cpu rv32m_cpu rv32a_cpu \
                   rv32f_cpu rv32d_cpu rv32c_cpu rv32zba_cpu rv32zbb_cpu rv32zbs_cpu rv32zbc_cpu
  RV32OBJS       = $(addprefix $(RV32OBJDIR)/, $(RV32_CPP:=.o))
  # options come from iss.cfg: vusermain.cfg with CORE's timing model
  ISS_DEFS       = -DCFGFILENAME=\"iss.cfg\"
  RUN_CFG        = iss.cfg
endif

# --------------------------------------------
# VProc user code build variables
# --------------------------------------------

# Compiler executables and standard flags
CC               = $(HOST_CC)
C++              = $(HOST_CXX)
CPPSTD           = -std=c++20
ARCHFLAG         = -m64 

# C/C++ include paths for VProc, memory model and user code
# $(BLD_DIR)/csr_build/generated-files carries csr_cosim.h -- the PeakRDL
# generated register access classes the native C++ CPU model uses, so that it
# talks to the CSR through the same single source of truth as the firmware.
INCLPATHS        = -I$(USRCODEDIR) -I$(PCIECODEDIR) -I$(COSIMDIR)/include -I$(PCIEDIR)/include -I$(PCIEDIR)/ltssm -I$(BLD_DIR)/csr_build/generated-files $(RV32INCLOPTS)
DEFS             = -DVPROC_SV -DVPROC -DEXCLUDE_LTSSM $(ISS_DEFS)

VOBJDIR          = $(CURDIR)/obj

# Separate C and C++ source files
USER_CPP_BASE    = $(notdir $(filter %cpp, $(USER_C) $(PCIE_C)))
USER_C_BASE      = $(notdir $(filter %c,   $(USER_C) $(PCIE_C)))

# Create list of object files (excluding any veriuser object)
VOBJS            = $(addprefix $(VOBJDIR)/,                   \
                    $(USER_C_BASE:%.c=%.o)                    \
                    $(USER_CPP_BASE:%.cpp=%.o))

USERLIB          = libuser.a

COSIMLDOPT       = -lcosimlnx
PCIELDOPT        = -lpcielnx

# xsim loads Vivado's own, older libstdc++ first; link ours in statically so
# VProc.so does not depend on which one is loaded
FLAGSOS          = -shared -lpthread -lrt -rdynamic -static-libstdc++ -static-libgcc

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


WORKDIR          = work

# Tool binaries. ../4.build/set-env.sh finds them and sets these from the
# environment (source it first); anything left unset falls back to the bare
# name on PATH. HOST_CC/HOST_CXX build the VProc and pcievhost C/C++ code.
HOST_CC         ?= gcc
HOST_CXX        ?= g++
HOST_AR         ?= ar

# Xilinx simulation libraries. The design instantiates PCIE_2_1 (secureip),
# plus MMCME2_ADV, BUFG, BUFGCTRL and IBUFDS_GTE2 (unisims). glbl carries the
# GSR/GTS nets those models expect, so it is elaborated as a second top.
# Time limit of a run, in us. A run ends 10 us after the firmware reports its
# result; the limit only stops one that never does. Firmware built without
# SIM=1 opens with wait_cycles(100000), tens of milliseconds on a 62.5 MHz
# picorv32, so it needs more:
#   make run RUN_US=40000
RUN_US          ?= 2000

XILINX_VIVADO   ?= /tools/Xilinx/2026.1/Vivado
GLBL             = $(XILINX_VIVADO)/data/verilog/src/glbl.v
XILLIBS          = -L unisims_ver -L unimacro_ver -L secureip

# firmware.hex is read by riscv_pcie_soc.sv with a bare name, so a copy has to
# sit in the simulation working directory. It is a product of the sw_build
# stage -- run that first.
FIRMWARE         = $(BLD_DIR)/sw_build/firmware.hex

# Flags for xsim
# SIM_FAST_TRAIN turns on the hard macro's shortened LTSSM training timers.
# It is a simulation-only parameter of PCIE_2_1 -- see pcie_core.sv.
# PCIE_LANES goes to xvlog through an options file (xvlog.defines).
# SIM_LANES = 1 until the PIPE model and the test program drive x4 too.
SIM_LANES         ?= 1
ANALYSEFLAGS       = -i $(PCIEDIR)/verilog/headers --define VPROC_SV --define VPROC_BYTE_ENABLE --define SIM_FAST_TRAIN --define SIM_GEN1_ONLY --define SIM_PIPE_CODING -f xvlog.defines $(CPUDEFINE) $(USRSIMOPTS) --prj tb.prj
ELABFLAGS          = -sv_lib $(VPROC_PLI) --timescale 1ps/1ps --debug typical $(XILLIBS) $(TB_NAME) glbl
# The snapshot xelab produces when two tops are elaborated is named
# "<top>#glbl". The hash has to be escaped or make treats the rest as a comment.
SIMFLAGS           = work.$(TB_NAME)\#work.glbl

XVLOG           ?= xvlog
XELAB           ?= xelab
SIMEXE          ?= xsim

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
	@$(C++) -c -fPIC $(OPTFLAG) $(CPPSTD) -Wno-write-strings $(DEFS) $(INCLPATHS) $< -o $@

# Rule to build PCIe user C sources
$(VOBJDIR)/%.o: $(PCIECODEDIR)/%.c
	@$(CC) -c -fPIC $(OPTFLAG) -Wno-write-strings $(DEFS) $(INCLPATHS) $< -o $@

# Rule to build PCIe user C++ sources
$(VOBJDIR)/%.o: $(PCIECODEDIR)/%.cpp
	@$(C++) -c -fPIC $(OPTFLAG) $(CPPSTD) -Wno-write-strings $(DEFS) $(INCLPATHS) $< -o $@

# Rule to build PCIe LTSSM support model
$(VOBJDIR)/%.o: $(PCIEDIR)/ltssm/%.c
	@$(CC) -c -fPIC $(OPTFLAG) -Wno-write-strings $(DEFS) $(INCLPATHS) $< -o $@

# The user code differs per CPU option (VUserMain0, the ISS and its defines):
# a change of CPU= throws the objects and the library away, so that the next
# build cannot mix them. obj/.cpu holds the CPU of the last build.
CPU_STAMP = $(VOBJDIR)/.cpu
$(CPU_STAMP): FORCE | $(VOBJDIR)
	@if [ "$$(cat $@ 2>/dev/null)" != "$(CPU)" ]; then \
	    rm -f $(VOBJDIR)/*.o $(USERLIB) $(VPROC_PLI); echo "$(CPU)" > $@; fi

# Rule to build library of user code
$(USERLIB): $(CPU_STAMP) $(VOBJS)
	@$(HOST_AR) cr $(USERLIB) $(VOBJS)

# Rules to build the rv32 ISS library (CPU=iss), with upstream's flags
$(RV32OBJDIR):
	@mkdir -p $@

$(RV32OBJDIR)/%.o: $(RV32SRC)/%.cpp $(wildcard $(RV32SRC)/*.h) | $(RV32OBJDIR)
	@$(C++) -c -fPIC $(ARCHFLAG) $(OPTFLAG) -I$(RV32SRC) -D_REENTRANT $< -o $@

$(RV32LIB): $(RV32OBJS)
	@rm -f $@
	@$(HOST_AR) cr $@ $(RV32OBJS)

# Rule to build VProc shared object
$(VPROC_PLI): $(USERLIB) $(RV32LIB)
	@$(C++) $(CFLAGS_SO) -o $@

#
# Compile simulation
#
sysverilog: $(VPROC_PLI) firmware.hex
	@echo "--define PCIE_LANES=$(SIM_LANES)" > xvlog.defines
	@$(XVLOG) $(ANALYSEFLAGS)
	@$(XVLOG) $(GLBL)
	@$(XELAB) $(ELABFLAGS)

# Local copy of the firmware image for $readmemh. Copied on every build, not by
# date: a tree on a network share can carry timestamps from the future, and a
# stale copy would then look newer than the image it came from.
firmware.hex: $(FIRMWARE) FORCE
	@cp -f $< $@

$(FIRMWARE):
	@echo "================================================================"
	@echo " ERROR: $(FIRMWARE) is missing."
	@echo " Build the firmware first:  cd ../4.build/sw_build && make"
	@echo "================================================================"
	@exit 1


#======================================================
# EXECUTION RULES
#======================================================

# tb.sv reads the run length from this file at time 0
run_us.cfg: FORCE
	@echo $(RUN_US) > $@

iss.cfg: FORCE
	@sed -E "s/-V [A-Z0-9]+/-V $(ISS_CORE)/" vusermain.cfg > $@

FORCE:

sim: sysverilog run_us.cfg $(RUN_CFG)
	@$(SIMEXE) $(SIMFLAGS)

run: sysverilog run_us.cfg $(RUN_CFG)
	@$(SIMEXE) -R $(SIMFLAGS)

rungui: sysverilog run_us.cfg $(RUN_CFG)
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
	@$(info $(SPC) $(SPC) USRSIMOPTS:   additional simulator analysis flags, such as setting defines (default blank))
	@$(info $(SPC) $(SPC) BUILD:        Select build type from DEFAULT or ISS (default DEFAULT))
	@$(info $(SPC) $(SPC) CPU:          CPU model on VProc node 0 (default rtl))
	@$(info $(SPC) $(SPC) $(SPC)   rtl    the RTL core (CORE), executing firmware.hex)
	@$(info $(SPC) $(SPC) $(SPC)   vproc  native C++ in usercode/VUserMain0.cpp)
	@$(info $(SPC) $(SPC) $(SPC)   iss    the rv32 ISS, executing firmware.elf)
	@$(info $(SPC) $(SPC) CORE:         edubos5, edubos5_3stg or picorv32: the RTL core, or the ISS timing model (default edubos5))
	@$(info $(SPC) $(SPC) RUN_US:       time limit in microseconds; a run ends 10 us after the firmware result (default $(RUN_US)))
	@$(info )

#======================================================
# CLEANING RULES
#======================================================

clean:
	@rm -rf $(WORKDIR) $(VOBJDIR) $(USERLIB) $(VPROC_PLI) xelab.* xvlog.* xsim.* *.wdb .Xil
	@rm -rf firmware.hex run_us.cfg iss.cfg *.jou *.log webtalk*
