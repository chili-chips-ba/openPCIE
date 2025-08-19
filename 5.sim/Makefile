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

USER_C           = VUserMain0.cpp VUserMain2.cpp ltssm.c
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
# Global exported environment variables
# --------------------------------------------

HW_SRC          := $(CURDIR)/../1.rtl
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

  USER_C         += mem_vproc_api.cpp uart.cpp rv32_cache.cpp vuserutils.cpp $(RV32WINFILES)
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
INCLPATHS        = -I$(USRCODEDIR) -I$(PCIECODEDIR) -I$(COSIMDIR)/include -I$(PCIEDIR)/include -I$(PCIEDIR)/ltssm $(RV32INCLOPTS)
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

# Flags for xsim
ANALYSEFLAGS       = -i $(PCIEDIR)/verilog/headers --define VPROC_SV --define VPROC_BYTE_ENABLE $(USRSIMOPTS) --prj tb.prj
ELABFLAGS          = -sv_lib $(VPROC_PLI) --timescale 1ps/1ps --debug typical $(TB_NAME)
SIMFLAGS           = $(TB_NAME)

# Get OS type
OSTYPE          := $(shell uname)

ifneq ($(OSTYPE), Linux)
  SIMLDFLAGS     = -Wl,-export-all-symbols
else
  SIMLDFLAGS     = -Wl,-E
endif

SIMMAKEFLAGS     = --quiet
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
sysverilog: $(VPROC_PLI)
	@xvlog $(ANALYSEFLAGS)
	@xelab $(ELABFLAGS)

# Create local file list for top, with PicoRv32 files removed
# So soc_cpu.VPROC can be used instead
#$(TOPFILELIST): $(HW_SRC)/$(TOPFILELIST)
#	@sed -e "/$(SOCCPUMATCH)/d" $< > $@

#======================================================
# EXECUTION RULES
#======================================================

sim: sysverilog
	@xsim $(SIMFLAGS)

run: sysverilog
	@xsim -R $(SIMFLAGS)

rungui: sysverilog
	@xsim -g --autoloadwcfg $(SIMFLAGS)

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
	@$(info )

#======================================================
# CLEANING RULES
#======================================================

clean:
	@rm -rf $(WORKDIR) $(VOBJDIR) $(USERLIB) $(VPROC_PLI) xelab.* xvlog.* xsim.* *.wdb .Xil
