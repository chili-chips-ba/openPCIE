# openPCIE Simulation Top Level Test Bench

## Table of Contents

* [Introduction](#introduction)
* [Test Bench Structure](#test-bench-structure)
  * [The PIPE PHY model](#the-pipe-phy-model)
  * [Endpoint feature limitations](#endpoint-feature-limitations)
  * [Prerequisites](#prerequisites)
  * [Model and viewer versions](#model-and-viewer-versions)
  * [What the simulation does](#what-the-simulation-does)
  * [Building and running](#building-and-running)
  * [Viewing the TLPs in WaveCrux](#viewing-the-tlps-in-wavecrux)
  * [Viewing the PIPE in WaveCrux](#viewing-the-pipe-in-wavecrux)
  * [How long a TLP spends in the hard macro](#how-long-a-tlp-spends-in-the-hard-macro)
* [The three CPU options](#the-three-cpu-options)
  * [What they cost](#what-they-cost)
* [Auto-selection of soc_cpu Component](#auto-selection-of-soc_cpu-component)
* [_VProc_ Software](#vproc-software)
  * [Other Software Use Cases](#other-software-use-cases)
    * [Natively Compiled Application](#natively-compiled-application)
    * [RISC-V Compiled Application](#risc-v-compiled-application)
* [Building and Running Code](#building-and-running-code)
  * [Configuring ISS timing model](#configuring-iss-timing-model)
  * [Running ISS code](#running-iss-code)
    * [The openPCIE configuration](#the-openpcie-configuration)
* [PicoRV32 RTL-Only Simulation](#picorv32-rtl-only-simulation)
* [Debugging Code](#debugging-code)
  * [Natively Compiled Code](#natively-compiled-code)
  * [ISS Software](#iss-software)
* [The mem_model Co-Simulation Sparse Memory Model](#the-mem_model-co-simulation-sparse-memory-model)
* [Driving the PCIE Link](#driving-the-pcie-link)
* [Co-simulation HAL](#co-simulation-hal)
  * [Using the HAL](#using-the-hal)
  * [Other Co-simulation considerations](#other-co-simulation-considerations)
* [Our Local VIP Improvements](#our-local-vip-improvements)
* [Open-source PCIE Validation Stacks](#open-source-pcie-validation-stacks)
* [Simulation issues](#simulation-issues)
* [References](#references)


## Introduction

The *openPCIE* top level test bench is based around the [*pcievhost*](https://github.com/wyvernSemi/pcievhost) PCIE 2.0 verification co-simulation IP in order to drive the DUT's PCIE link. This is a C model for generating PCIE 1.1 and 2.0 traffic data connected to the logic simulation using the [*VProc*](https://github.com/wyvernSemi/vproc) virtual processor co-simulation element. _VProc_ allows a user program to be compiled natively on the host machine and 'run' on an instantiated HDL component in a logic simulation, including running the PCIE C model. _VProc_ has a generic memory mapped master bus for generating read and write transactions and a Bus Functional Model (BFM) wrapper encapsulates the _VProc_ component and effectively memory maps the PCIE ports into the address space, allowing software to drive and read these ports and interface with the PCIE C model. Although originally designed as a root complex model, the _pcievhost_ component has <ins>some</ins> endpoint features, enabled by setting a parameter. The endpoint features are [limited](#endpoint-feature-limitations) and were originally designed just as a target for the main root complex model to be tested.

The diagram below is a block diagram of the top level test bench showing the main features.

<p align=center>
<img alt="openPCIE Root Complex test bench structure" width=1000 src="../0.doc/5.sim/tb-structure.drawio.png">
</p>

The DUT PCIE link is connected to the _pcievhost_, instantiated in a wrapper x1 PIPE link (`pcieVHostPipex1.v`) configured as an endpoint, and running some user code  to generate PCIE traffic as required, though it will automatically respond to transactions requiring a completion. The model is capable of displaying link traffic on both the up- and downstream links to the console, configurable via a `ContDisps.hex` file. To drive the DUT's memory mapped slave bus, a _VProc_ component is used with a BFM wrapper for the specific bus protocol used for the device&mdash;in this case PCIE. A program can then be run on the virtual processor to access the device's memory mapped registers etc. and update the TX link signals and read from the RX link signals.

The user software to run on the virtual processor is the means to configure the model, such as setting the config space register settings, doing the required link initialisation, and any further modelling of a specific Endpoint implementation. That software is [`usercode/VUserMain1.cpp`](usercode/VUserMain1.cpp): it builds a Type 0 configuration space with PCIE, MSI and Power Management capabilities, and calls `initFc()` to bring up flow control. What it does not model is device behaviour behind the BARs - see [Endpoint feature limitations](#endpoint-feature-limitations).

## Test Bench Structure

The test bench drives the **real** Root Complex RTL. `tb.sv` instantiates
`RC_opensource` out of `2.rtl/0.common.opensource` -- the same top level that
goes into both bitstreams, RC-direct and RC-switched -- and the whole design
comes along with it:

```
tb.sv
 |
 +- RC_opensource                                   2.rtl/0.common.opensource/src/
      |
      +- pcie_top                                real RTL
      |    +- clk_rst_gen       MMCM                  real RTL
      |    +- pcie_core                            real RTL
      |    |    `- PCIE_2_1                     Xilinx hard macro (secureip)
      |    `- phy_top    <-- REPLACED -->      5.sim/models/phy_top.PIPE.sv
      |                                                +- PIPE PHY model
      |                                                `- pcieVHostPipex1 (endpoint,
      |                                                   VProc node 1, VUserMain1.cpp)
      `- riscv_pcie_soc                             real RTL
           +- picorv32                              real RTL, runs firmware.hex
           `- soc_csr -> csr                        PeakRDL-generated CSR
```

Exactly **one** RTL file is swapped for the simulation, and one file is copied in:

| Item | Why |
|---|---|
| `phy_top.sv` becomes `models/phy_top.PIPE.sv` | the 7-series GTP transceiver turns PIPE symbols into a 5 GT/s serial stream; _pcievhost_ models the link at PIPE symbol level, so the transceiver has to come out |
| `firmware.hex` copied into `5.sim/` | `riscv_pcie_soc.sv` reads it with `$readmemh` and a bare file name |

Everything else -- the hard macro, the transaction layer, the CPU, the CSR and
the firmware -- is what goes into the FPGA. The swap needs no `ifdef` in the
design: the module name and port list match, so the simulation file list
(`tb.prj`) simply picks the other file. (The CPU swap for `CPU=vproc` /
`CPU=iss` is different - that one *is* an `` `ifdef SOC_CPU_VPROC `` in
`riscv_pcie_soc.sv`, see [The three CPU options](#the-three-cpu-options).)

Three simulation-only parameters ARE selected with defines, all set only in
`5.sim/Makefile` and never by either synthesis flow:

| Define | Effect | Why |
|---|---|---|
| `SIM_FAST_TRAIN` | `PL_FAST_TRAIN = "TRUE"` on the hard macro (`pcie_core.sv`) | shortens the LTSSM training timers. This is a simulation feature of the macro -- with the real 12/24 ms timers link training is longer than any practical run |
| `SIM_GEN1_ONLY` | `PCIE_GEN = 1` (`link_pkg.sv`) | the endpoint VIP advertises Gen1 and its LTSSM helper cannot follow a Gen1 to Gen2 retrain |
| `SIM_PIPE_CODING` | `DISABLE_SCRAMBLING = "TRUE"` on the hard macro (`pcie_core.sv`) | matches how the endpoint VIP is configured over PIPE |

### The PIPE PHY model

`models/phy_top.PIPE.sv` stands in for the transceiver and carries the link
partner on its far side. It provides the three things the `PCIE_2_1` LTSSM needs
from a PHY:

* **PHYSTATUS pulses** on exit from PIPE reset, on every power-state change and
  on every rate change
* **Receiver detection** -- a PHYSTATUS pulse together with `RXSTATUS = 3'b011`
  in response to `TXDETECTRX`, which is what lets the LTSSM leave Detect
* **RXVALID / RXELECIDLE**, asserted from the first K character the partner
  sends, standing in for a squelch detector

It also generates the clocks. `TXOUTCLK` is a behavioural 100 MHz oscillator and
everything downstream is the real `clk_rst_gen` MMCM, so the design sees its normal
clock topology: PCLK at 125 MHz (Gen1) or 250 MHz (Gen2), USERCLK1/2 at 62.5 MHz.
**The 100 MHz matters**: `clk_rst_gen` is parameterised with `CLKIN1_PERIOD = 10 ns`
and `CLKFBOUT_MULT_F = 10`, so any other input frequency scales every clock in
the design, and the PIPE then over- or under-samples the link partner. Feeding it
125 MHz, for instance, makes PCLK 156.25 MHz and duplicates one symbol in five.

Two trace facilities are built in, both behind defines:

```
make USRSIMOPTS="--define PIPE_OS_TRACE"    # ordered sets, both directions, with link/lane numbers
make USRSIMOPTS="--define PIPE_RAW_DUMP"    # raw PIPE symbols
```

The LTSSM state is printed on every transition without any define, and `tb.sv`
reports `pl_phy_lnk_up`, `core_rst_n` and `trn_link_up` as they change.

### Endpoint feature limitations

_pcievhost_ was written as a root complex model, and its endpoint side is a
parameter on top of that -- `EndPoint = 1`, set where the model is instantiated
in `models/phy_top.PIPE.sv`. It is enough to train a link and answer
Configuration and Memory requests, which is exactly what testing a root complex
needs, but it is not a device model. What it does and does not give you:

**What it provides**

* A configuration space, built by [`usercode/VUserMain1.cpp`](usercode/VUserMain1.cpp)
  through `writeConfigSpace()` / `writeConfigSpaceMask()`: a Type 0 header
  (vendor `0x14fc`, device `0x0002`), and PCIE, MSI and Power Management
  capability structures. The mask calls are what make the read-only bits behave
  as read-only.
* Automatic completions for Configuration and Memory requests, with Memory
  traffic landing in the
  [sparse memory model](#the-mem_model-co-simulation-sparse-memory-model).
* A full LTSSM, flow control initialisation and DLLP handling.

**What it does not**

* **No device behaviour behind the BARs.** A memory write is stored and a read
  returns it; nothing interprets the data, so there is no DMA, no interrupt
  generation and no application logic to test against.
* **No error injection.** Malformed TLPs, completion timeouts, retries and CRS
  storms have to be provoked by editing the model, not by configuration.
* **One lane.** The wrapper used here is `pcieVHostPipex1`, x1 with a 16-bit
  PIPE datapath. Wider links need a different wrapper.
* **The endpoint LTSSM paths were the least exercised part of the model**, since
  its usual job is to be the root complex. Three of them turned out to be wrong
  when driven by real silicon rather than by another copy of the same VIP. The
  fixes are in `models/pcievhost/ltssm/ltssm.c`, with the original kept beside
  it as `ltssm.c.orig`.

For a link partner with real device behaviour the alternative is an RTL
endpoint, which the project points at in
[`2.rtl/1.EP.opensource`](../2.rtl/1.EP.opensource). That costs the decoded
protocol logging and the controllability this model gives, so the two are
complementary rather than interchangeable.

### Prerequisites

Linux or WSL, once:

- **Vivado 2026.1 for Linux** (needs a license file even for `xsim`) -- `xvlog`, `xelab`, `xsim`. Windows `xsim` can be started from WSL, but it loads the C/C++ models (`-sv_lib`) only as a Windows DLL, not the Linux `.so` built here.
- **GCC 10+** (C++20) and `make`: `sudo apt install build-essential`
- **RISC-V GCC** (xPack `riscv-none-elf-`) for the firmware, see [4.build](../4.build/README.md)

Then, from the repo root:

```sh
source 4.build/set-env.sh     # tcsh: source 4.build/set-env.csh
```

It finds Vivado (`/tools/Xilinx/<version>/Vivado`, `~/Xilinx/<version>/Vivado`, or set `XILINX_VIVADO`) and the
compilers, and lists anything missing. (`peakrdl` is only needed if you edit
`csr.rdl` -- see [4.build/README.md](../4.build/README.md#csr-hal-compilation).)

### Model and viewer versions

| Component | In use | Latest upstream (Oct 2026) | Source |
|---|---|---|---|
| VProc | 1.13.4 | 1.13.4 | [wyvernSemi/vproc](https://github.com/wyvernSemi/vproc) |
| pcievhost **(modified, see below)** | 1.9.3 | 1.9.3 (without our changes) | [wyvernSemi/pcievhost](https://github.com/wyvernSemi/pcievhost) |
| mem_model **(modified, see below)** | `main` c7b9c62 (1.0.1 + one fix) | same | [wyvernSemi/mem_model](https://github.com/wyvernSemi/mem_model) |
| rv32 ISS **(modified, see below)** | 1.3.3 | 1.3.3 | [wyvernSemi/rv32](https://github.com/wyvernSemi/rv32) |
| Vivado simulator (`xsim`) | 2026.1 | 2026.1 | [AMD Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html) |
| WaveCrux Pro | 1.0.1 | 1.0.1 | [Ferrite-Engineering/wavecrux](https://github.com/Ferrite-Engineering/wavecrux) |
| TLP decoder plugin | ours | -- | [`tools/wavecrux-pcie-tlp`](tools/wavecrux-pcie-tlp) |
| PIPE, DLL and serial-line decoder plugin | `wcx-pcie` pcie-v0.2.0 | pcie-v0.2.0 | [Ferrite-Engineering/wavecrux-decoders](https://github.com/Ferrite-Engineering/wavecrux-decoders) |
| RISC-V instruction-trace decoder | built into WaveCrux 1.0.1 | -- | [Ferrite-Engineering/wavecrux](https://github.com/Ferrite-Engineering/wavecrux) |

#### Why XSIM and not Verilator?

Our RTL is 100% SystemVerilog, not mixed-language, and it and the rest of our ecosystem are Verilator-ready. Only the vendor hard macros stand in the way, and of those only `PCIE_2_1` matters: its simulation model is AMD's `secureip` library, encrypted (IEEE 1735), so only vendor simulators can run it, and no open model exists. The Xilinx primitives in the design:

| Primitive | Simulation model | In Verilator |
|---|---|---|
| `PCIE_2_1` | encrypted `secureip` core | no -- the blocker |
| `GTPE2_CHANNEL`, `GTPE2_COMMON` | encrypted `secureip` cores | not needed: co-sim replaces the GTP with [the PIPE PHY model](#the-pipe-phy-model) |
| `MMCME2_ADV` | plain Verilog, `real` arithmetic and `#` delays | not tried |
| `BUFG`, `BUFGCTRL`, `IBUFDS_GTE2`, `RAMB36E1`, `FDCE` | plain Verilog | expected to work |

Verilator-ready means: our RTL passes Verilator lint (`run-lint.sh`), and the co-simulation models (VProc, pcievhost, mem_model, rv32) ship with Verilator flows upstream.

A Verilator run would need `--timing` for the whole test bench, not only for the MMCM: `tb.sv` and the PIPE model make their clocks with `#` delays, and VProc waits a delta cycle for each `UpdateResponse`. VProc's `-GDISABLE_DELTA` drops that wait, but it would not save `--timing` here, and it changes the handshake that pcievhost runs its link on.

#### Why VCD and not FST?

XSIM writes only VCD (`$dumpfile`/`$dumpvars`) and its own `.wdb`. FST is a GTKWave format: Verilator and Icarus write it, XSIM does not. A converted copy is much smaller, and WaveCrux reads it. `make run` with `DUMP_VCD` converts it with [`tools/vcd2fst.sh`](tools/vcd2fst.sh) (GTKWave's `vcd2fst -Z`); `make fst` does it alone. [`tb.fst`](tb.fst) is tracked (5.3 MB VCD -> 73 KB), `tb.vcd` is not.

The ready-made `.wavecrux` sessions open `tb.fst`, so they work from a fresh clone. They bind signals by their number in the file, which differs between the VCD and the FST.

#### Local changes

| File | Change | Why |
|---|---|---|
| `models/cosim/mem_model.sv` | wraps upstream `mem_model.v` (kept as `f_mem_model.v`) in Verilator `lint_off` pragmas | keeps third-party code out of our lint |
| `models/rv32/src/rv32csr_cpu.cpp` (in `rv32-openpcie.patch`) | the timer-compare check in `process_interrupts()` no longer charges cycles | it added 2 cycles to every instruction |
| `models/rv32/src/rv32i_cpu.cpp` (in `rv32-openpcie.patch`) | `sw`, `sh` add the store extra cycles | upstream adds the load ones |
| `models/rv32/usercode/rv32_timing_config.h` | PicoRV32, eduBOS5 2-/3-stage tables measured on the RTL in this SOC | see [Our Local VIP Improvements](#our-local-vip-improvements) |
| `models/rv32/usercode/VUserMain0.cpp` | no fetch/load wait states; bus credit; waits for reset release, restarts on reset | see [Our Local VIP Improvements](#our-local-vip-improvements) |
| `models/soc_cpu.VPROC.picorv32.sv` | 2-clock picorv32 handshake; `!resetn` on VProc interrupt bit 3 | see [Our Local VIP Improvements](#our-local-vip-improvements) |

pcievhost:

| File | Change | Why |
|---|---|---|
| `ltssm/ltssm.c` | As upstream port: send Link and Lane = PAD until the partner assigns them; stay in Configuration.Lanenum for at least 16 TS1 | real PCIE_2_1 downstream port deadlocked or timed out against the model's endpoint LTSSM ([Endpoint feature limitations](#endpoint-feature-limitations)) |
| `verilog/pcieVHost/pcieVHost.v` | VProc `BE` and `Burst` ports, left open | we build VProc with `VPROC_BYTE_ENABLE` |
| `verilog/headers/test_defs.v` | `` `fatal`` calls `tb.Fatal` | our test bench top is `tb` |

The unmodified `ltssm.c` is kept beside it as `ltssm.c.orig`, and our fixes as `ltssm/ltssm-openpcie.patch`. [`tools/vip-upgrade.sh`](tools/vip-upgrade.sh) rebuilds all four models from upstream and re-applies these changes; it stops if the LTSSM or the rv32 patch no longer applies. rv32 is built here from its sources (`models/rv32/src`, upstream `774d84fa`).

### What the simulation does

A full run takes the design from power-up to a verified memory transaction, with
no hardware involved. It ends 10 µs after the firmware reports its result; `RUN_US` (default 2000) is only the time limit:

```
                   0  TB     run length 2000 us
             1000000  TB     PERST# released
             1257001  LTSSM  0xxx -> 0x00 DETECT_QUIET
             3607000  LTSSM  0x00 -> 0x02 POLLING_ACTIVE
             3847000  LTSSM  0x02 -> 0x04 POLLING_CONFIGURATION
             5079000  LTSSM  0x04 -> 0x05 CONFIG_LINKWIDTH_START
            70711000  LTSSM  0x05 -> 0x26      <- link number assigned
            71655000  LTSSM  0x2a -> 0x2b      <- lane number assigned
            72559000  LTSSM  0x2c -> 0x11      <- Configuration complete
            74103001  TB     pl_phy_lnk_up = 1  <- physical layer up
            74479000  LTSSM  0x15 -> 0x16 L0  (linkup)
            75255001  TB     trn_link_up   = 1  <- data link layer up, flow control done
            75255001  TB     ===> PCIe LINK UP -- SOC released from reset
            75271000  TB     core_rst_n   = 1  <- core reset released (TRN, SOC)
           389543000  TB     ===> FIRMWARE RESULT 0x0000face  (PASS)
           399543000  TB     *** run ends 10 us after the firmware result ***
--------------------------------------------------------
 openpcie2-rc co-simulation summary
--------------------------------------------------------
  PCIe link up ............ YES
  LTSSM final state ....... 0x16
  TLPs sent by firmware ... 21
  Payload written to EP ... 0x00000006  (Memory Write TLP)
  Payload read back ....... 0x00000006  (match)
  FIRMWARE RESULT ......... PASS (0x0000face)
--------------------------------------------------------
```

The last three lines of the summary are the actual result. `0x0000FACE` is only the verdict the
firmware reports; the two above it are the dword that really crossed the link --
written to the endpoint at `0x8000_0000` by a Memory Write TLP, then fetched
back by a Memory Read and its completion.

In between, the real firmware enumerates the endpoint model exactly as it does
on the board. The endpoint's own decode of the traffic:

```
RC -> EP   Config read  type 0  Reg=00   ID                    TAG=00
EP -> RC   Completion with data              Device 0002, Vendor 14FC
RC -> EP   Config write type 0  Reg=01   Command = 0           memory decode off
RC -> EP   Config write type 0  Reg=04   BAR0 = 0xFFFFFFFF     size it ...
RC -> EP   Config read  type 0  Reg=04   BAR0
EP -> RC   Completion with data              0xFFFFF008            4 KB, 32-bit, prefetchable
RC -> EP   Config write type 0  Reg=04   BAR0 = 0x80000000     ... and place it
           ... the same for BAR1 (1 KB -> 0x80001000), BAR2/3 (64-bit, 8 GB:
           parked above 4 GB), BAR4/5 (read back 0: not implemented) ...
RC -> EP   Config write type 0  Reg=01   Command = 6           memory space + bus master
RC -> EP   Mem write req  Addr=80000000  data 0x00000006
RC -> EP   Mem read  req  Addr=80000000  TAG=14
EP -> RC   Completion with data              0x00000006            TAG=14
```

Every request goes through the same completion check: the firmware reads the
Completion Status of each one and re-issues a request answered with CRS. All 21 TLPs are enumeration and test: the result marker goes to `status.result`, which sends no TLP.

The same traffic, decoded at TLP level in a waveform viewer, is in
[Viewing the TLPs in WaveCrux](#viewing-the-tlps-in-wavecrux).

And the CSR side of the same sequence, as the firmware sees it:

```
CSR RD [0x20] = 0000001e     status.phy -- Tx FSM idle, 30 buffers free
CSR WR [0x00] = 04000001     tx.header0 -- CfgRd0, length 1
CSR WR [0x04] = 10ee000f     tx.header1 -- requester 0x10EE, tag 0, BE 0xF
CSR WR [0x08] = 01000000     tx.header2 -- bus 1, device 0, function 0, register 0
CSR WR [0x0c] = 00000000     tx.data    -- the write strobe starts the transfer
CSR RD [0x18] = ...          rx.header_info -- polled until the completion lands
...
CSR WR [0x24] = 0000face     status.result -- the pass marker, sends no TLP
```

### Building and running

Set up the [Prerequisites](#prerequisites) first, including `set-env`.

```
cd 5.sim
make                                # firmware + VProc.so + xvlog + xelab
make run                            # -> the summary above
make gui                            # same, with waveforms
```

`make` builds the firmware itself, on every build, into `obj/fw`, with `SIM=1`: `main()` opens with `wait_cycles(100000)`, which waits for the link to train. On hardware that costs nothing; in simulation it is tens of milliseconds of simulated time before the firmware does anything at all. `SIM=1` shortens it to 200 iterations, and the whole run fits in under 0.7 ms (0.4 ms on eduBOS5): it ends 10 µs after the firmware result. The tracked `4.build/sw_build/firmware.hex` stays the board build, untouched by any simulation. `VARIANT=switched` builds the RC-switched firmware instead.

Useful switches:

```
make run RUN_US=10000                        # higher time limit; read at time 0 from run_us.cfg
make USRSIMOPTS="--define CPU_TRACE"         # CPU bus activity and every CSR access
make USRSIMOPTS="--define PIPE_OS_TRACE"     # ordered sets both ways, with link/lane numbers
make USRSIMOPTS="--define PIPE_RAW_DUMP"     # raw PIPE symbols
```

The LTSSM state, the link status bits and the firmware's result marker are
always printed, with no define needed.

### Viewing the TLPs in WaveCrux

All pictures in this section and the next two are from the **RC-direct** run: the Root Complex talks straight to one Endpoint, with no switch in between.

> **Coming in v1.1.0: RC-switched.** The same views for the switched Root Complex: Type 1 Configuration requests through the switch, BARs assigned slot by slot, and a self-test per Endpoint.

XSIM's own waveform database is the `.wdb` that `make gui` opens. For a view at
*TLP level* -- every packet named, every completion paired with the request it
answers -- the run can also write a VCD for [WaveCrux](https://wavecrux.app),
together with a decoder plugin and a ready-made session:

```
make run USRSIMOPTS="--define DUMP_VCD --define DUMP_SOC_CPU"   # -> 5.sim/tb.vcd (not tracked) + tb.fst (tracked)
```

The tracked `tb.fst` comes from this command. `DUMP_SOC_CPU` adds the CPU's RVFI trace for [`tb.RISCV-ISA.wavecrux`](tb.RISCV-ISA.wavecrux); leave it out and that session comes up empty.

Then, once per machine, in WaveCrux (1.0.1 or later): **Settings -> Extensions -> Decoder
Plugins**, accept the safety notice, **Add directory...**
`5.sim/tools/wavecrux-pcie-tlp` and **Reload plugins**. Add Ferrite's PIPE and Data Link Layer plugin the same way ([Viewing the PIPE in WaveCrux](#viewing-the-pipe-in-wavecrux)). After that, open
[`tb.TLP-DLL-PIPE.wavecrux`](tb.TLP-DLL-PIPE.wavecrux) (File -> Open, or `wavecrux_pro tb.TLP-DLL-PIPE.wavecrux`): it
loads `tb.fst` from the same directory with all decoders bound. Our plugin --
source, Windows binary, parameters -- is described in
[tools/wavecrux-pcie-tlp](tools/wavecrux-pcie-tlp/README.md).

In each picture the TLP decoder rows are the TLP stream in either direction:
**TLP Downstream** is Root Complex -> Endpoint (`tx_`), **TLP Upstream** is
Endpoint -> Root Complex (`rx_`). The raw streams they decode are the `tx_`/`rx_` signal rows, one DW per clock. The rows below them are described in [Viewing the PIPE in WaveCrux](#viewing-the-pipe-in-wavecrux).

At this zoom the Data Link Layer and PIPE rows show only thin ticks. Besides each TLP's own frame and Ack, they are:
- SKP ordered sets: the Root Complex sends one every 5.9 µs, the Endpoint every 4.7 µs (1474 and 1180 symbol times), so that each receiver can compensate for the clock difference between the two ends.
- UpdateFC DLLPs: each side re-sends its posted credits about every 30 µs, unchanged, even with no posted TLP in flight.

**BAR0 sizing.** The firmware writes all ones to BAR0, reads it back --
`0xFFFFF008`, a 4 KB, 32-bit, prefetchable BAR -- and places it at `0x80000000`:

<p align="center">
<img alt="WaveCrux TLP view: firmware sizing BAR0" src="images/wavecrux-tlp-bar-sizing.png" width=1000>
</p>

**A 64-bit BAR that does not fit.** BAR2 has already read back `0x0000000C`
(64-bit, prefetchable). The upper half, BAR3, reads back `0xFFFFFFFE`: 8 GB.
That cannot be placed below 4 GB, and this Root Complex only sends 32-bit
addresses, so the firmware parks it at `0x2_0000_0000` instead of squeezing it
in:

<p align="center">
<img alt="WaveCrux TLP view: a 64-bit BAR that does not fit" src="images/wavecrux-tlp-bar-64bit.png" width=1000>
</p>

**The self-test.** Memory Space and Bus Master enabled, then a posted Memory
Write of `6` to `0x80000000` and a Memory Read whose completion brings the same
`6` back -- the `PASS (0x0000face)` of the summary above. Note what is missing: the Memory Write has no completion. It is *posted*: the Root Complex sends it and moves on, which is what makes writes cheap. Reads and Configuration requests are *non-posted*, and each waits for its completion:

<p align="center">
<img alt="WaveCrux TLP view: memory write and read-back self-test" src="images/wavecrux-tlp-mem-rw.png" width=1000>
</p>

The firmware then writes `PASS` to `status.result`. That register sends nothing, so this read is the last TLP of the run. Writing `tx.data` is what launches a TLP, which is why the result has a register of its own.

**The firmware sets the pace.** A Configuration request and its Completion take about 1 µs ([How long a TLP spends in the hard macro](#how-long-a-tlp-spends-in-the-hard-macro)), yet the requests leave about 10 µs apart. The link is idle most of the time, waiting for the SOC's next request.

What makes this possible in the test bench:

* [`models/tlp_dw_monitor.sv`](models/tlp_dw_monitor.sv) re-times the SOC's
  64-bit AXI-Stream into one DW per clock with SOP/EOP flags, one instance per
  direction, onto a [`tlp_dw_if`](models/tlp_dw_if.sv).
* [`models/tlp_wavecrux_view.sv`](models/tlp_wavecrux_view.sv) presents both
  directions as `tb.tlp_view.tx_*` and `rx_*`, named after the decoder's
  inputs, so WaveCrux's auto-bind finds them; its prefix drop-down picks `tx_`
  or `rx_`.

The session stores the decoder bindings as positions in the FST, which are the
same for every run of this test bench. Should a different simulator version
order the dump differently, the decoder rows come up empty: remove them and add
them again with **Ctrl+Shift+D** -- auto-bind fills in all nine inputs.

### Viewing the PIPE in WaveCrux

The same dump also carries the 16-bit PIPE between the Root Complex's
PCIE_2_1 hard macro and the pcieVHost endpoint, one level below the TLPs:
the symbols as they go on the wire, before 8b/10b. All signals are under
`tb.dut.u_pcie.u_phy_top.u_pcie_ep`:

| Signal | Direction |
|---|---|
| `pclk` | PIPE clock, one 16-bit word (two symbols) per rising edge |
| `RxData` / `RxDataK` | Root Complex -> Endpoint |
| `TxData` / `TxDataK` | Endpoint -> Root Complex |

These are the inputs of Ferrite's
[PCIe PIPE and Data Link Layer decoders](https://github.com/Ferrite-Engineering/wavecrux-decoders)
(Apache-2.0). Get the plugin from their
[release page](https://github.com/Ferrite-Engineering/wavecrux-decoders/releases/tag/pcie-v0.2.0)
(Windows: `wcx-pcie-0.2.0-windows-x64.zip`; check it against `SHA256SUMS`), unzip it to a folder of its own and add
that folder under **Settings -> Extensions -> Decoder Plugins**, as above. Then open
[`tb.TLP-DLL-PIPE.wavecrux`](tb.TLP-DLL-PIPE.wavecrux) (File -> Open, or
`wavecrux_pro tb.TLP-DLL-PIPE.wavecrux`): it loads `tb.fst` from the same directory, with the TLP and PIPE rows and all six decoders bound, at the first TLP (a CfgRd0 at 155 µs).

To set it up by hand instead, add
**PCIe PIPE (16-bit)** and **PCIe Data Link Layer (16-bit)** with **Ctrl+Shift+D**,
once per direction: prefix `Rx`, then `Tx`, each time **Apply confirmed only**.
Take the 16-bit variants: each decoder comes in 8, 16, 32 and 64 bits, and only
the one matching the bus binds. Leave `scrambling` at `auto`: the simulation
link runs unscrambled, and the decoder locks to that by itself.
`u_phy_top.rx_active` can be bound to `rxvalid` by hand on the `Tx`
instances (it gates what the Root Complex receives).

In the pictures, the rows follow the protocol stack from top to bottom. The signal rows: the LTSSM state, the TLP view (`tx_`/`rx_`), then the PIPE, `RxData`/`RxDataK` in blue (Root Complex -> Endpoint) and `TxData`/`TxDataK` in orange (Endpoint -> Root Complex). Below them, the decoder rows in the same order: TLP Downstream and Upstream, Data Link Layer `Rx` and `Tx`, PIPE `Rx` and `Tx`.

The link comes up from the bottom of that stack. First only the PIPE carries anything: the training ordered sets. Then the PIPE and the Data Link Layer: the flow-control DLLPs. Only after that do TLPs flow. That is why the TLP rows stay empty in the first two pictures, and the Data Link Layer rows in the first one.

**Link training.** Both sides have been sending TS2s with PAD for link and lane
number (Polling). Now in Configuration, the Root Complex proposes link 0 in
TS1s (`link=0 lane=PAD`), the Endpoint echoes it, then lane 0 is
proposed and echoed (`link=0 lane=0`). TS2s with both numbers close
Configuration. Each side also advertises how many FTS ordered sets it needs to
leave L0s: 255 for the Root Complex, 4 for the Endpoint. The Data Link Layer rows
stay empty: no DLLP is sent before the link is up. The Root Complex's LTSSM
reaches L0 at 74.5 µs, just after this view:

<p align="center">
<img alt="WaveCrux PIPE view: link training" src="images/wavecrux-pipe-training.png" width=1000>
</p>

**Flow-control initialisation.** As soon as the link is up, each side advertises its
receive buffer credits, in header (`H`) and data (`D`) units, for Posted (`P`),
Non-Posted (`NP`) and Completion (`Cpl`) traffic: first in InitFC1 DLLPs, then
in InitFC2 to confirm. No TLP can be sent until this has finished. Each side repeats its set of three InitFC1s until it has received the other side's: the Endpoint sends four rounds, because the Root Complex starts 0.2 µs later. This 115 ns view catches the two sides one step apart:
- The Endpoint is already sending InitFC2 (Data Link Layer `Tx` row): 32 posted headers with
  1008 data credits, and 32 non-posted headers.
- The Root Complex is still sending InitFC1 (Data Link Layer `Rx` row): 32 posted headers
  with 437 data credits.

A data credit is 16 bytes (4 DW): the Endpoint has room for 16 KB of posted data, the Root Complex for 7 KB. For non-posted requests, the Root Complex grants 12 headers (in its InitFC1-NP, outside this view), the Endpoint 32.

`H=0 D=0` means infinite: both ends advertise infinite Completion credits. The
spec requires that of an Endpoint, and of a Root Complex without peer-to-peer
traffic between its ports. Each DLLP is framed SDP (`5c`) ... END (`fd`)
on the PIPE, both K symbols:

<p align="center">
<img alt="WaveCrux PIPE view: flow-control initialisation" src="images/wavecrux-pipe-fc-init.png" width=1000>
</p>

**The first TLP on the wire.** At 155.1 µs the firmware's first Configuration
Read leaves the Root Complex as `TLP seq=0 CfgRd0`, framed STP ... END. The
Endpoint answers with its Completion, `TLP seq=0 CplD`: seq 0 again, because
each direction numbers its own TLPs. It then sends `Ack seq=0` for the
Configuration Read, so the Root Complex can drop it from its replay buffer. It
also sends `UpdateFC-NP` to return the non-posted credit that the read used.
The Root Complex acknowledges the Completion in turn, with its own `Ack seq=0`
at 155.73 µs, just outside this view. It takes 0.44 µs to do so, where the Endpoint model acknowledged the read after 0.13 µs. An Ack does not have to be immediate: `Ack seq=N` acknowledges every TLP up to N, so a receiver may wait and acknowledge several at once. In this run the TLPs are too far apart for that, and each one gets its own Ack.

<p align="center">
<img alt="WaveCrux PIPE view: first TLP and its Ack" src="images/wavecrux-pipe-tlp-ack.png" width=1000>
</p>

**Why `UpdateFC-NP` says `H=33`, not `H=1`.** An UpdateFC does not say "here is one more credit". It carries the running total of credits granted since flow-control initialisation: the 32 of InitFC, plus the 1 that the read just returned. Follow it through the run and it counts up by one header per non-posted TLP: 34, 35, 36, ... Its data credits go up only after a Configuration Write, which carries a DW of data; after a Configuration Read they stay put.

Why a total and not a delta? DLLPs are never acknowledged or replayed, so one can be lost on the wire. With a delta, a lost credit would be gone for good, and the link would slowly run dry. With a total, the next UpdateFC repairs it. The same reason explains the UpdateFCs that repeat every 30 µs with unchanged values ([Viewing the TLPs](#viewing-the-tlps-in-wavecrux)): a regular refresh, so that a lost one never stalls the link.

**The Data Link Layer: its traffic is shown, its internals are not.** On this
Root Complex, the Data Link Layer lives inside the 7-series PCIE_2_1 hard macro.
Nothing inside it reaches the VCD:

* the replay buffer, which holds each TLP until it is acknowledged
* the sequence counters (next to send, next expected)
* the Ack/Nak latency and replay timers
* the flow-control credit counters

What the Data Link Layer *puts on the wire* does reach the VCD, because it
crosses the PIPE. That is what Ferrite's Data Link Layer decoder
(`ferrite.pcie_dll_w16`) reads. From the PIPE symbols alone it names:

* every DLLP: `Ack seq=0`, `Nak`, `InitFC1-P` / `InitFC2-NP` / `UpdateFC-Cpl`
  with their header and data credits, and the PM DLLPs, each with its CRC-16
  checked
* every TLP with its sequence number and LCRC check, the TLP type (`CfgRd0`,
  `CplD`, `MWr32`, ...), Length, TC, TD and EP
* replays, sequence-number errors and nullified TLPs

So the pictures above show the Data Link Layer protocol between the two ends:
which TLP got which sequence number, when it was acknowledged, and how many
credits each side granted. They do not show how the hard macro arrived at those
decisions. For that, see an open-source Data Link Layer in RTL, where every
internal signal can be dumped: the sibling project's
[openCologne-PCIE `2.rtl/4.dll`](https://github.com/chili-chips-ba/openCologne-PCIE/tree/main/2.rtl/4.dll).
Its wave snapshots are coming soon.

**A clean bill of health.** Read across the whole run, the wire shows no sign of trouble, and each check below is something you can look for in any PCIE dump:
- **No replay.** The Root Complex sent 21 TLPs, seq 0 to 20, and the Endpoint 20, seq 0 to 19: no gap and no repeat, so no TLP had to be sent twice.
- **No error.** No Nak, and no TLP ended in EDB (a nullified TLP): every frame passed its CRC check.
- **Nothing left unacknowledged.** Every TLP in both directions got its Ack.
- **Every request answered.** 21 requests, one of them the posted Memory Write: 20 completions came back, exactly one per non-posted request.

### How long a TLP spends in the hard macro

With all three layers in one view, you can follow a single request through the
Root Complex and see how long the PCIE_2_1 hard macro takes to pass it on.
Open [`tb.TLP-DLL-PIPE.wavecrux`](tb.TLP-DLL-PIPE.wavecrux) (it needs both
plugins). It shows the TLP view of the SOC's AXI-Stream at the top, the PIPE
below it, and the TLP, PIPE and Data Link Layer decoders at the bottom.

Here is the firmware's first Configuration Read and its Completion. The markers
on the time axis show where the TLP crosses from one layer to the next:

<p align="center">
<img alt="WaveCrux view of one request through the hard macro, markers a to d" src="images/wavecrux-hm-latency.png" width=1000>
</p>

| Marker | What happens |
|---|---|
| **a** | The CPU's request leaves the SOC on the AXI-Stream |
| **b** | About 0.4 µs later, it appears on the PIPE, on its way to the Endpoint |
| **c** | The Endpoint's Completion has fully arrived on the PIPE |
| **d** | About 0.4 µs later, the Completion reaches the SOC |

The Endpoint model answers almost at once, so nearly all of the 1 µs round trip
is spent inside the hard macro, about 0.4 µs each way. On the way back, the
clock starts only once the whole TLP has arrived (marker **c**): the hard macro
holds each TLP until its LCRC has checked out, and only then hands it to the
SOC.

The same holds for every TLP in the run, give or take one clock. Two things
to keep in mind when comparing with real hardware:

* The simulation link runs at Gen1 (see `SIM_GEN1_ONLY` above). At Gen2 the
  link itself is twice as fast.
* The PIPE PHY model is ideal. On the board, the GTP transceiver adds its own
  latency on both sides of the link.


## The three CPU options

The SOC's CPU socket takes three different occupants, selected with `CPU=` on the make command line. The DUT is otherwise identical in all three -- the same CSR, the same PCIE stack, the same top level -- so the same test runs each time; only the thing issuing the bus accesses changes. `CORE=` picks the RISC-V core: [`edubos5`](../2.rtl/0.common.opensource/src/CPU.eduBOS5) (default, 2-stage), `edubos5_3stg` or `picorv32`.

| `CPU=` | What sits on VProc node 0 | Executes |
|---|---|---|
| `rtl` (default) | nothing -- the real RTL core: `CORE=edubos5` (default), `edubos5_3stg` or `picorv32` | `firmware.hex`, the same image that goes into the bitstream |
| `vproc` | VProc | [`usercode/VUserMain0.cpp`](usercode/VUserMain0.cpp), compiled for the host |
| `iss` | VProc + the [rv32](models/rv32) instruction set simulator, with `CORE`'s timing model | `firmware.elf`, interpreted -- real RISC-V instructions, no RTL core |

```sh
make run                               # CPU=rtl CORE=edubos5, the default
make run CORE=picorv32
make run CPU=vproc
make run CPU=iss                       # -V PICORV32
make run CPU=iss CORE=picorv32         # -V PICORV32
```

The swap happens in [`riscv_pcie_soc.sv`](../2.rtl/0.common.opensource/src/riscv_pcie_soc.sv): eduBOS5 is the default, `` `ifdef SOC_CPU_PICORV32 `` selects PicoRV32, `` `ifdef SOC_CPU_VPROC `` the replacement module for the two VProc builds, [`models/soc_cpu.VPROC.picorv32.sv`](models/soc_cpu.VPROC.picorv32.sv): VProc dressed up as a picorv32, driving the core's *native* memory interface.

> Note the difference from the inherited `models/soc_cpu.VPROC.sv`, which is kept for reference. That one speaks the `soc_if` bus interface of the sibling Chili.CHIPS SOC infrastructure. This design has no `soc_if` -- it instantiates the core directly -- so it needed its own wrapper.

The native C++ model reaches the CSR through `csr_cosim.h`, which PeakRDL generates from the same [`csr.rdl`](../4.build/csr_build/csr.rdl) that produces the register RTL and the firmware's `csr.h`. Hardware, firmware and the co-simulation CPU model therefore cannot drift apart. The ISS is configured in [`vusermain.cfg`](vusermain.cfg), where `-x`/`-X` place the CSR window on the simulated bus and leave code and data in the ISS's own memory. The make file copies it to `iss.cfg` with `-V` set from `CORE`.

### What they cost

Vivado XSIM 2026.1, simulated time, which is exact. Every run gives the same result: link up, LTSSM `0x16`, 21 TLPs, `PASS (0x0000face)`.

| `CPU=` | Core | Result at (simulated) | Run time, wall clock, relative |
|---|---|---|---|
| `rtl` | PicoRV32 | 667.2 µs | 1.3x |
| `rtl` | eduBOS5 2-stage | **389.5 µs** | 1.0x |
| `rtl` | eduBOS5 3-stage | 470.9 µs | 1.1x |
| `iss` | PicoRV32 timing | 663.1 µs (-0.6%) | 1.4x |
| `iss` | eduBOS5 2-stage timing | 389.5 µs (0.0%) | 1.4x |
| `iss` | eduBOS5 3-stage timing | 470.9 µs (0.0%) | 1.4x |
| `vproc` | native C++ | **138.3 µs** | **0.7x** |

The run times are for information only. They come from one batch of single runs (2026-10-16, Ryzen 9 6900HX, WSL2, `rtl` eduBOS5 = about 55 s), and wall-clock time varies with host load: two identical `rtl` eduBOS5 runs with `DUMP_VCD` took 54 s and 197 s on this machine, on the same day. The simulated times are exact.

- **eduBOS5 vs PicoRV32:** IPC, Fmax and area compared in the [eduBOS5 README](../2.rtl/0.common.opensource/src/CPU.eduBOS5/README.md#cpu-options-compared-the-soc-only).
- **`iss`** matches the RTL core it models to within 0.6% (see [Our Local VIP Improvements](#our-local-vip-improvements)). It runs the real firmware binary in a debuggable native process (`-g` in `vusermain.cfg` opens a gdb port).
- **`vproc`** covers the least simulated time: the native program skips the firmware's start-up delay and polls the CSR without instructions in between.

### Use the right mode for the job!

| `CPU=` | Speed | Use it for |
|---|---|---|
| `vproc` | fastest: least simulated time | iterating on the PCIE logic. Its timing is not the firmware's |
| `iss` | as `rtl`, timing within 0.6% | debugging the real firmware binary: gdb, instruction trace, disassembly |
| `rtl` | reference | the cycle-accurate core that goes into the bitstream |

For additional detail, check [this table](#what-they-cost).

## Auto-selection of soc_cpu Component

> Historical note. This describes the arrangement in the sibling
> Chili.CHIPS SOC infrastructure, where the CPU was selected by filtering a file list. Here the choice
> is the `CPU=` switch above, and the file list is [`tb.prj`](tb.prj).

The SOC top level component has the required RTL files listed in <tt>2.rtl/top.filelist</tt>. This includes files for the `soc_cpu`, under the directory <tt>ip.cpu</tt>. The simulation build make file ([see below](#building-and-running-code)) will process the <tt>top.filelist</tt> file to generate a new local copy, having removed all references to the files under the <tt>ip.cpu</tt> directory. Since the VProc <tt>soc_cpu</tt> component is a verification model, the <tt>soc_cpu.VPROC.sv</tt> HDL file is placed in <tt>5.sim/models</tt> whilst the the HDL files for _VProc_ and _mem_model_ are in `5.sim/models/cosim`. These are referenced within the make file, along with the other test models that are used in the test bench. Thus the VProc device is selected for the simulation as the CPU component.

## VProc Software

The VProc software consists of DPI-C code for communication and synchronisation with the simulation, for _VProc_. On top of this are the APIs for _VProc_ for use by the running code. In the case of _VProc_ there is a low level C API) or, if preferred, a C++ API. In _openPCIE_, the _VProc_ <tt>soc_cpu</tt> is node 0, and so the entry point for user software is <tt>VUserMain0</tt>, in place of a normal C or C++ <tt>main</tt>.

The _VProc_ software is compiled into libraries located in `5.sim/models/cosim/lib`, with the headers in `5.sim/models/cosim/include` (see [here](models/cosim/README.md) for more details). The C++ API is defined in a class <tt>VProc</tt> (defined in <tt>VProcClass.h</tt>), and a constructor creates an API object, defining the node for which it is connected:

```c++
VProc (const uint32_t node);
```

For the C++ VProc API there are two basic word access methods:

```c++
    int  write (const unsigned   addr, const unsigned    data, const int delta=0);
    int  read  (const unsigned   addr,       unsigned   *data, const int delta=0);
```

For these methods, the address argument is agnostic to being a byte address or a word address, but for the _openPCIE_ implementation these are **byte addresses**. The `delta` argument is unused in _openPCIE_, and should be left at its default value, with just the `address` and `data` arguments used in the call to these methods. Along with these basic methods is a method to advance simulation time without doing a read or write transaction.

```c++
int  tick (const unsigned ticks);
```
This method's units of the <tt>ticks</tt> argument are in clock cycles, as per the clock that the _VProc_ HDL is connected to. A basic _VProc_ program, then, is shown below:

```c++
#include "VProcClass.h"
extern "C" {
#include "mem.h"
}

static const int node    = 0;

extern "C" void VUserMain0(void)
{
    // Create VProc access object for this node
    VProc* vp0 = new VProc(node);

    // Wait a bit
    vp0->tick(100);

    uint32_t addr  = 0x10001000;
    uint32_t wdata = 0x900dc0de;

    vp0->write(addr, wdata);
    VPrint("Written   0x%08x  to  addr 0x%08x\n", wdata, addr);

    vp0->tick(3);

    uint32_t rdata;
    vp0->read(addr, &rdata);

    if (rdata == wdata)
    {
        VPrint("Read back 0x%08x from addr 0x%08x\n", rdata, addr);
    }
    else
    {   VPrint("***ERROR: data mis-match at addr = 0x%08x. Got 0x%08x, expected 0x%08x\n", addr, rdata, wdata);
    }

    // Sleep forever
    while(true)
        vp0->tick(GO_TO_SLEEP);
}
```
The above code is a slightly abbreviated version of the code in <tt>5.sim/usercode</tt>. Note that the <tt>VUserMain0</tt> function must have C linkage as the _VProc_ software that calls it is in C (as all the programming logic interfaces, including DPI-C, are C). The API also has a set of other methods for finer access control which are listed below, and more details can be found in the [_VProc_ manual](https://github.com/wyvernSemi/vproc/blob/master/doc/VProc.pdf).

```c++
    int  writeByte    (const unsigned   byteaddr, const unsigned    data, const int delta=0);
    int  writeHword   (const unsigned   byteaddr, const unsigned    data, const int delta=0);
    int  writeWord    (const unsigned   byteaddr, const unsigned    data, const int delta=0);
    int  readByte     (const unsigned   byteaddr,       unsigned   *data, const int delta=0);
    int  readHword    (const unsigned   byteaddr,       unsigned   *data, const int delta=0);
    int  readWord     (const unsigned   byteaddr,       unsigned   *data, const int delta=0);

```
The other methods in this class are not, at this point, used by _openPCIE_. These methods can now be used to write test code to drive the CPU bus of the <tt>soc_cpu</tt> component (here picorv32's native memory interface), and is the basic method to write test code software.

As well as the _VProc_ API, the user software can have direct access to the sparse memory model API (which is part of the _pcievhost_ model) by including <tt>mem.h</tt>, which are a set of C methods (and <tt>mem.h</tt> must be included as <tt>extern "C"</tt> in C++ code). The functions relevant to _openPCIE_ are shown below:

```c++
void     WriteRamByte  (const uint64_t addr, const uint32_t data, const uint32_t node);
void     WriteRamHWord (const uint64_t addr, const uint32_t data, const int little_endian, const uint32_t node);
void     WriteRamWord  (const uint64_t addr, const uint32_t data, const int little_endian, const uint32_t node);
uint32_t ReadRamByte   (const uint64_t addr, const uint32_t node);
uint32_t ReadRamHWord  (const uint64_t addr, const int little_endian, const uint32_t node);
uint32_t ReadRamWord   (const uint64_t addr, const int little_endian, const uint32_t node);
```

Note that, as C functions, there are no default parameters and the <tt>little_endian</tt> and <tt>node</tt> arguments must be passed in, even though they are constant. The <tt>little_endian</tt> argument is non-zero for little endian and zero for big endian. The <tt>node</tt> argument is **not** the same as for _VProc_, but allows multiple separate memory spaces to be modelled, just as for _VProc_ multiple virtual processor instantiations. For _openPCIE_, this is always 0. All instantiated <tt>mem_model</tt> components in the HDL have (through the DPI) access to the same memory space model as the API, and so data can be exchanged from the simulation and the running code, such as the RISC-V programs.

Compiling co-designed application code, either compiled for the native host machine, or to run on the <tt>rv32</tt> RISC-V ISS will need further layers on top of these APIs, which will be virtualised away by that point ([see the sections below](#co-simulation-hal)). The diagram below summarises the software layers that make up a program running on the _VProc_ HDL component. The "native test code" use case, shown at the top left, is for the case just described above  that use the APIs directly, though they can optionally use the HAL.

<p align="center">
<img alt="Software layers on the VProc soc_cpu" src="../0.doc/5.sim/soc-cpu-vproc-stack.drawio.png" width=800>
</p>

### Other Software Use Cases

#### Natively Compiled Application

As well as the native test code case seen in the previous section, the _openPCIE_ application can be compiled natively for the host machine, including the hardware access layer (HAL), generated from SystemRDL. The HAL software output from this is processed to generate a version that makes accesses to the _VProc_ and PCIE memory model APIs in place of accesses with pointers to and from memory (see the [Co-simulation HAL](#co-simulation-hal) section below). The rest of the application software has these details hidden away in the HAL and sees the same API as presented by the auto-generated code. The <tt>main</tt> entry point is also swapped for <tt>VUserMain0</tt>.

This is exactly the `CPU=vproc` build. In _openPCIE_ the transactions leave the CPU model on picorv32's native memory interface rather than on an <tt>soc_if</tt> port, since that is what this SOC instantiates -- see [The three CPU options](#the-three-cpu-options). The generated co-simulation HAL is `csr_cosim.h`, and [`usercode/VUserMain0.cpp`](usercode/VUserMain0.cpp) is the application on top of it.

#### RISC-V Compiled Application

To execute RISC-V compiled application code, the <tt>rv32</tt> instruction set simulator is used as the code running on the virtual processor. The <tt>VUserMain0</tt> program now becomes software that creates an ISS object and integrate with _VProc_. This uses the ISS's external memory access callback function to direct loads and stores either towards the PCIE memory model, the _VProc_ API for simulation transactions, or back to the ISS itself to handle. This ISS integration <tt>VUserMain0</tt> program is located in <tt>5.sim/models/rv32/usercode</tt>. When built the code here is compiled and links the ISS library, which the make file builds from the rv32 sources in <tt>5.sim/models/rv32/src</tt>. More details of the integration code and methods can be found [here](models/rv32/README.md).

The ISS supports interrupts, but these are not currently used on _openPCIE_. The integration software can read a configuration file, if present in the <tt>5.sim/</tt> directory, called <tt>vusermain.cfg</tt>. This allows the ISS and other features to be configured at run-time. The configuration file is in lieu of command line options and the entries in the file are formatted as if they were such, with a command matching the `VUserMain` program:

```
vusermain0 [options]
```
One of the options is <tt>-h</tt> for a help message, which is as shown below:
```
Usage:vusermain0 -t <test executable> [-hHebdrgxXRcI][-n <num instructions>]
      [-S <start addr>][-A <brk addr>][-D <debug o/p filename>][-p <port num>]
      [-l <line bytes>][-w <ways>][-s <sets>][-j <imem base addr>][-J <imem top addr>]
      [-P <cycles>][-x <base addr>][-X <top addr>][-V <core>]
   -t specify test executable/binary file (default test.exe)
   -B specify to load a raw binary file (default load ELF executable)
   -L specify address to load binary, if -B specified (default 0x00000000)
   -n specify number of instructions to run (default 0, i.e. run until unimp)
   -d Enable disassemble mode (default off)
   -r Enable run-time disassemble mode (default off. Overridden by -d)
   -C Use cycle count for internal mtime timer (default real-time)
   -a display ABI register names when disassembling (default x names)
   -T Use external memory mapped timer model (default internal)
   -H Halt on unimplemented instructions (default trap)
   -e Halt on ecall instruction (default trap)
   -E Halt on ebreak instruction (default trap)
   -b Halt at a specific address (default off)
   -A Specify halt address if -b active (default 0x00000040)
   -D Specify file for debug output (default stdout)
   -R Dump x0 to x31 on exit (default no dump)
   -c Dump CSR registers on exit (default no dump)
   -g Enable remote gdb mode (default disabled)
   -p Specify remote GDB port number (default 49152)
   -S Specify start address (default 0)
   -I Enable instruction cache timing model (default disabled)
   -l Specify number of bytes in icache line (default 8)
   -w Specify number of ways in icache (default 2)
   -s Specify number of sets in icache (default 256)
   -j Specify cached IMEM base address (default 0x00000000)
   -J Specify cached IMEM top address (default 0x7fffffff)
   -P Specify penalty, in cycles, of one slow mem access (default 4)
   -x Specify base address of external access region (default 0xFFFFFFFF)
   -X Specify top address of external access region (default 0xFFFFFFFF)
   -V Specify RISC-V core timing model to use (default "DEFAULT")
   -h display this help message
```
With these options the model can load an elf executable or raw binary file to memory directly and be set up with some execution termination conditions. Disassembly output can also be switched on and registers dumped on exit. More details of all these features can be found in the <tt>rv32</tt> [ISS manual](https://github.com/wyvernSemi/rv32/blob/main/iss/doc/iss_manual.pdf).

Specific to the _openPCIE_ project is the ability to specify the region where memory loads and stores will make external simulation transactions rather than use internal memory modelling or peripherals, using the <tt>-x</tt> and <tt>-X</tt> options. This is useful to allow access to the CSR registers in the HDL whilst mapping all of the memory internally using the sparse C PCIE memory model. The cache model can be enabled with the <tt>-I</tt> option and the cache configured. The <tt>-l</tt> option specifies the number of bytes in a cache line, which can be 4, 8 or 16. The number of ways is set with <tt>-w</tt> and can be either 1 or 2, and the number of sets is specified with the <tt>-s</tt> options and can be 128, 256, 512 or 1024. The _openPCIE_ project also has the option to load a raw binary file to memory in place of reading an ELF file. The <tt>-B</tt> selects this mode (with the <tt>-t</tt> still specifying the file name), and the load address can be changed from 0 with the <tt>-L</tt> option. A set of pre-configured timing models can be specified with the <tt>-V</tt> option. The argument must be one of the following:

* DEFAULT
* PICORV32
* EDUBOS5STG2
* EDUBOS5STG3
* IBEXMULSGL
* IBEXMULFAST
* IBEXMULSLOW

This reflects the available models as detailed in the _Configuring ISS timing model_ section below.

## Building and Running Code

A <tt>Makefile</tt> file is provided in the <tt>5.sim/</tt> directory to compile the user *VProc* software, for both the `soc_cpu` and _pcieVHost_ components, and to build and run the test bench HDL. The make file will compile all the user code or, where an ISS build is selected (see make file variables below) the provided `soc_cpu` user code that's the _rv32_ ISS integration software.

In _openPCIE_ the node-1 (_pcieVHost_) entry point is <tt>VUserMain1.cpp</tt> in <tt>5.sim/usercode</tt>, named in the `PCIE_C` variable, and it is always compiled. What gets compiled for node 0 depends on the `CPU` variable: nothing for `CPU=rtl`, <tt>usercode/VUserMain0.cpp</tt> for `CPU=vproc`, and the ISS integration code in <tt>models/rv32/usercode</tt> for `CPU=iss`. To alter which files to compile, the make file `USER_C` variable can be updated to list a set of C++ files for the `soc_cpu`. Similarly, the `PCIE_C` variable can be updated with a list of files for the PCIE component. The location of the source files is in the variable `USRCODEDIR`, which may also be altered. Any modifications can be done to the make file itself, or on the command line. E.g., to add additional files to the `soc_cpu` build:

```
make USER_C="VUserMain0.cpp MyTest1Class.cpp"
```

If many variants of software build are required then either scripts can be constructed with the various command line variable modification calls to `make` or other make files which set these variables and call the common make file. This is useful in managing source code for multiple tests located in different directories, compiling for ISS (perhaps also calling the RISC-V application build), or for compiling application code natively which will have a different set of source files.

The user software is compiled into a local static library, <tt>libuser.a</tt>, which is linked into the <tt>VProc.so</tt> shared object that the simulator loads (<tt>xelab -sv_lib</tt>), along with the precompiled <tt>libcosimlnx.a</tt> located in <tt>5.sim/models/cosim/lib</tt> and containing the precompiled code for *VProc*. The headers for the *VProc* API software are in <tt>5.sim/models/cosim/include</tt>. The HDL required for these models' use in the _openPCIE_ test bench can be found in <tt>5.sim/models/cosim</tt>, and the make file picks these up from there to compile with the rest of the test bench HDL.

The <tt>Makefile</tt> make file has a target <tt>help</tt>, which produces the following output:

```
make help          Display this message
make               Build C/C++ and HDL code without running simulation
make run           Build and run batch simulation
make rungui/gui    Build and run GUI simulation
make clean         clean previous build artefacts

Command line configurable variables:
  USER_C:       list of user source code files for soc_cpu (default VUserMain0.cpp)
  PCIE_C:       list of user source code files for pcievhost modules (default VUserMain1.cpp)
  USRCODEDIR:   directory containing user source code (default $(CURDIR)/usercode)
  OPTFLAG:      Optimisation flag for user VProc code (default -g)
  USRSIMOPTS:   additional simulator analysis flags, such as setting defines (default blank)
  BUILD:        Select build type from DEFAULT or ISS (default DEFAULT)
  CPU:          CPU model on VProc node 0 (default rtl)
                  rtl    the RTL core (CORE), executing firmware.hex
                  vproc  native C++ in usercode/VUserMain0.cpp
                  iss    the rv32 ISS, executing firmware.elf
  RUN_US:       time limit in microseconds; a run ends 10 us after the firmware result (default 2000)
```

By default, without a named target, the simulation executable will be built but not run. With a <tt>run</tt> target, the simulation executable is built and then executed in batch mode. To fire up waveforms after the run, a target of <tt>rungui</tt> or <tt>gui</tt> can be used. A target of <tt>clean</tt> removes all intermediate files of previous compilations.

The make file has a set of variables (with default settings) that can be overridden on running <tt>make</tt>. E.g. <tt>make VAR=NewVal</tt>. The help output shows these variables with brief descriptions. Entries with multiple values should be enclosed in double quotes.

The variable to reach for is <tt>CPU</tt>, which picks what occupies node 0 and sets everything else to match -- <tt>CPU=iss</tt> is what selects the ISS build, overriding <tt>USER_C</tt> and <tt>USRCODEDIR</tt> with the supplied ISS integration source. (The underlying <tt>BUILD=ISS</tt> switch is still there and still works, but it only changes the C side; without <tt>CPU=iss</tt> the HDL is still built with the RTL core, and the ISS would have no processor socket to occupy.)

The <tt>USER_C</tt> and <tt>USRCODEDIR</tt> make file variables allow different (and multiple) user source file names to override the defaults, and to change the location of where the user code is located (if not the ISS build). This allows different programs to be run by simply changing these variable, and to organise the different source code in different directories etc. By default, the _VProc_ code is compiled for debugging (<tt>-g</tt>), but this can be overridden by changing <tt>OPTFLAG</tt>. The trace and timing options can also be overridden to allow a faster executable. If any additional options for the simulator are required, then these can be added to <tt>USRSIMOPTS</tt>.

```
make run                                                   # Build and run with the RTL eduBOS5 (the default)
make                                                       # Build but don't run
make run CPU=vproc                                         # Native C++ CPU model, usercode/VUserMain0.cpp
make run CPU=iss                                           # rv32 ISS on the real firmware.elf
make CPU=iss gui                                           # Build and run ISS simulation and show waves
make run RUN_US=3000                                       # Higher time limit
make USER_C="test1.cpp subfuncs.cpp" USRCODEDIR=test1 CPU=vproc run
make clean                                                 # Clean all intermediate files
```

### Configuring ISS timing model

Configuration of the timing model can be done from the supplied integration code in <tt>VUserMain0.cpp</tt>. The main <tt>pre_run_setup()</tt> function, in <tt>VUserMain0.cpp</tt>, creates an <tt>rv32_timing_config</tt> object (<tt>rv32_time_cfg</tt>) which has an <tt>update_timing</tt> method that takes a pointer to the iss object and an enumerated type to select the model to use for the particular core timings required. This second argument is selected from one of the following:

* <tt>rv32_timing_config::risc_v_core_e::DEFAULT&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</tt> : Default timing values
* <tt>rv32_timing_config::risc_v_core_e::PICORV32&nbsp;&nbsp;&nbsp;&nbsp;</tt> : picoRV32 timings
* <tt>rv32_timing_config::risc_v_core_e::EDUBOS5STG2&nbsp;</tt> : 2 stage [eduBOS5](../2.rtl/0.common.opensource/src/CPU.eduBOS5)
* <tt>rv32_timing_config::risc_v_core_e::EDUBOS5STG3&nbsp;</tt> : 3 stage [eduBOS5](../2.rtl/0.common.opensource/src/CPU.eduBOS5)
* <tt>rv32_timing_config::risc_v_core_e::IBEXMULSGL&nbsp;&nbsp;</tt> : IBEX single cycle multiplier
* <tt>rv32_timing_config::risc_v_core_e::IBEXMULFAST&nbsp;</tt> : IBEX fast multi-cycle multiplier
* <tt>rv32_timing_config::risc_v_core_e::IBEXMULSLOW&nbsp;</tt> : IBEX slow multi-cycle multiplier

As detailed in the _RISC-V Compiled Application_ section above, the ISS can be configured via the <tt>vusermain.cfg</tt> file using the <tt>-V</tt> option.

### Running ISS code

When the test bench is built for the rv32 ISS, the actual 'user' application code is run on the RISC-V ISS model itself, and is compiled using the normal RISC-V GNU toolchain to produce a binary file that the ISS can load and run. As described above, the code that is run is selected with the <tt>vusermain.cfg</tt> file and the <tt>-t</tt> option. The various flags configure the ISS and determines when the ISS is halted (if at all). An example assembly file is provided in <tt>5.sim/models/rv32/riscvtest/main.s</tt> (as well as a recompiled <tt>main.bin</tt>). This assembly code reproduces the functionality of the example <tt>VUserMain0.cpp</tt> program discussed previously, writing to memory, reading back and comparing for a mismatch. The example assembly code is compiled with:

```
riscv-none-elf-as -fpic -march=rv32imafdc -aghlms=main.list -o main.o main.s
riscv-none-elf-ld main.o -Ttext 0 -Tdata 1000 -melf32lriscv -o main.bin
```
In this instance, the code is set to compile to use the MAFDC extensions (maths, atomic, float, double and compressed). To run this code the <tt>vusermain.cfg</tt> is set to:

```
vusermain0 -x 0x10000000 -X 0x20000000 -rEHRca -t ./models/rv32/riscvtest/main.bin
```
This sets the address region that will be sent to the HDL <tt>soc_cpu</tt> bus to be between byte addresses 0x10000000 and 0x1FFFFFFF. All other accesses will use the direct memory model's API, with no simulation transactions. The next set of options turn on run-time disassembly (<tt>-r</tt>), exit on <tt>ebreak</tt> (<tt>-E</tt>) or unimplemented instruction (<tt>-H</tt>), dump registers (<tt>-R</tt>) and CSR register (<tt>-c</tt>) and display the registers in ABI format (<tt>-a</tt>). The pre-compiled example program binary is then selected with the <tt>-t</tt> option. Of course, many of these options are not necessary and, for example, the output flags (<tt>-rRca</tt>) can be removed and the program will still run correctly. In the <tt>5.sim/</tt> directory, using <tt>make</tt> to build and run the code gives something like the following output (with other output removed; this transcript is from an earlier XSIM 2023.2 run):

```
$make CPU=iss run

   .
   .
   .
ECHO is off.
ECHO is off.

****** xsim v2023.2 (64-bit)
  **** SW Build 4029153 on Fri Oct 13 20:14:34 MDT 2023
  **** IP Build 4028589 on Sat Oct 14 00:45:43 MDT 2023
  **** SharedData Build 4025554 on Tue Oct 10 17:18:54 MDT 2023
    ** Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
    ** Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.

source xsim.dir/work.tb/xsim_script.tcl
# xsim {work.tb} -autoloadwcfg -runall
Time resolution is 1 ps
run -all
VInit(0): initialising DPI-C interface
  VProc version 1.13.2. Copyright (c) 2004-2025 Simon Southwell.


  ******************************
  *   Wyvern Semiconductors    *
  * rv32 RISC-V ISS (on VProc) *
  *     Copyright (c) 2025     *
  ******************************

00000000: 0x00001197    auipc     gp, 0x00000001
00000004: 0x0101a183    lw        gp, 16(gp)
00000008: 0x0001a103    lw        sp, 0(gp)
0000000c: 0x10001237    lui       tp, 0x00010001
00000010: 0x00222023    sw        sp, 0(tp)
00000014: 0x00022283    lw        t0, 0(tp)
00000018: 0x00229663    bne       t0, sp, 12
0000001c: 0x00004505'   addi      a0, zero, 1
0000001e: 0x00004501'   addi      a0, zero, 0
00000020: 0x05d00893    addi      a7, zero, 93
00000024: 0x00009002'   ebreak
    *

Register state:

  zero = 0x00000000   ra = 0x00000000   sp = 0x900dc0de   gp = 0x00001000
    tp = 0x10001000   t0 = 0x900dc0de   t1 = 0x00000000   t2 = 0x00000000
    s0 = 0x00000000   s1 = 0x00000000   a0 = 0x00000000   a1 = 0x00000000
    a2 = 0x00000000   a3 = 0x00000000   a4 = 0x00000000   a5 = 0x00000000
    a6 = 0x00000000   a7 = 0x0000005d   s2 = 0x00000000   s3 = 0x00000000
    s4 = 0x00000000   s5 = 0x00000000   s6 = 0x00000000   s7 = 0x00000000
    s8 = 0x00000000   s9 = 0x00000000  s10 = 0x00000000  s11 = 0x00000000
    t3 = 0x00000000   t4 = 0x00000000   t5 = 0x00000000   t6 = 0x00000000

CSR state:

  mstatus    = 0x00003800
  mie        = 0x00000000
  mvtec      = 0x00000000
  mscratch   = 0x00000000
  mepc       = 0x00000000
  mcause     = 0x00000000
  mtval      = 0x00000000
  mip        = 0x00000000
  mcycle     = 0x0000000000000037
  minstret   = 0x000000000000000b
  mtime      = 0x0006263f2bfc6bcf
  mtimecmp   = 0xffffffffffffffff

$finish called at time : 39217 ns : File "C:/git/openpcie/5.sim/models/pcievhost/verilog/pcieVHost/pcieVHost.v" Line 209
exit
INFO: [Common 17-206] Exiting xsim at Tue Aug 19 16:03:05 2025...

```

Note that the disassembled output is a mixture of 32-bit and compressed 16-bit instructions, with the compressed instruction hexadecimal values shown followed by a <tt>'</tt> character and the instruction hexadecimal value in the lower 16-bits. Unlike for the native compiled code use cases, unless the HDL has changed, the test bench does not need to be re-built when the RISC-V source code is changed or a different binary is to be run, just the RISC-V code is re-compiled or the <tt>vusermain.cfg</tt> updated to point to a different binary file.

#### The openPCIE configuration

The walk-through above is Simon's stand-alone assembler example, and its
<tt>vusermain.cfg</tt> line is kept commented out in the file for checking the
ISS on its own. What [`vusermain.cfg`](vusermain.cfg) actually selects is the
real firmware:

```
vusermain0 -V EDUBOS5STG2 -H -x 0x30000000 -X 0x3FFFFFFF -t ../4.build/sw_build/firmware.elf
```

`-x`/`-X` put **only** the CSR window on the simulated bus. Code and data at
`0x0000_0000` are served from the ISS's own memory, which is why instruction
fetch costs no simulation time at all. `-V` (set from `CORE`) makes the ISS reckon
cycles the way the RTL core does: the result lands within 0.6% of it
([What they cost](#what-they-cost)). It runs `obj/fw/firmware.elf`, which `make` builds with the short co-simulation start-up delay.

### PicoRV32 RTL-Only Simulation

This is `make run CORE=picorv32` (eduBOS5 is the default core), and it
uses the same XSIM flow as everything else, driving the PCIE BFM on
node 1 from [`usercode/VUserMain1.cpp`](usercode/VUserMain1.cpp). See
[The three CPU options](#the-three-cpu-options).

> Historical note. There was once a separate Verilator-based makefile here for
> this case, producing `output/Vtb` and an FST trace for GTKWave. It is gone:
> the DUT instantiates `PCIE_2_1`, a Xilinx `secureip` model that only the
> Vivado simulator can elaborate, so the RTL core case had to move to XSIM
> along with the rest.

## Debugging Code

In each of the three usage cases of software, each can be debugged using <tt>gdb</tt>, either for the host computer or the gnu RISC-V toolchain's gdb.

### Natively Compiled code

For natively compiled code, whether test code or natively compiled application code, so long as each was compiled with the `-g` flag set ([see above](#building-and-running-code) for make file options) then the code can be debugged as part of the running simulation process. If XSIM is run for the simulation, but halted at time 0, then the simulation kernel process, xsim, will be running and its process ID is required. Under Linux this can be found by running:
```
    ps -e | grep xsim
```

This will give an output something like that shown below:
```
    3200 pts/0 00:00:00 xsim
```

Thus the process ID is 3200. Once the PID for the simulation kernel process is known, from the directory where VProc.so resides, we can attach a `gdb` session to it using:
```
    gdb -p <PID>
```
It may be required to be root user on Linux for this to work. There might also be a load of warnings that there are no debugging symbols for the system libraries being used, but this is not an issue so long as there are none regarding `VProc.so`. Once the `gdb` session starts, you can list code (e.g. list `VUserMain0`) and set breakpoints (e.g. `b 66`). At this point the simulation is paused by `gdb`, so a `continue` command is needed to start
the simulation process once more. On the simulator command line, then the simulation can be run (e.g. `run all`) and will continue until a break point in the C/C++ code is hit, or the simulation ends. If at a breakpoint, `gdb` will have a command prompt once again and state can be inspected and any other `gdb` debug command used as normal. And so debugging of user code can proceed. When at a `gdb` prompt, the simulation process will be paused and simulator command lines and window buttons etc. will not respond to inputs.

Of course, the simulation may stop if, say, run for a set time (e.g. run 100 µs) or any other criteria, and then waveforms and state can be inspected. At this point, `gdb` will still be ‘running’ waiting for a breakpoint, and so cannot take new command inputs.

### ISS Software
The ISS has a remote <tt>gdb</tt> interface (enable with the <tt>-g</tt> option in the <tt>vusermain.cfg</tt> file) allowing the loading of programs via this connection, and of doing all the normal debugging steps of the RISC-V code. The [ISS manual](https://github.com/wyvernSemi/rv32/blob/main/iss/doc/iss_manual.pdf) details how to use the <tt>gdb</tt> remote debug interface but, to summarise, when the ISS is run in GDB mode, it will create a TCP socket and advertise the port number to the screen (e.g. <tt>RV32GDB: Using TCP port number: 49152</tt>). The RISC-V <tt>gdb</tt> is then run and a remote connection is made with a command:

 ```
 (gdb) target remote :49152
 ```

A blank before the colon character in the port number indicates the connection is on the local host, but a remote host name can be used to do remote debugging from another machine on the network, or even over the internet, if sufficient access permissions. The program (if not done so by other means) can be loaded over this connection and then debugging commence as normal.

The [ISS manual](https://github.com/wyvernSemi/rv32/blob/main/iss/doc/iss_manual.pdf) has more details on this and also has an appendix showing how to setup an Eclipse IDE project to debug the code via <tt>gdb</tt>.

## The mem_model Co-Simulation Sparse Memory Model

The _openPCIE_ test bench makes use of the [mem_model](https://github.com/wyvernSemi/mem_model) co-simulation HDL component. This makes use of the sparse memory model, written in C with a software API for read and write transactions that is part of the _pcieVHost_ model's software. It can map a 64-bit address space, with pages allocated on demand to restrict the actual memory required. The API can be accessed from any _VProc_ running code to share this memory space. This model can also be accessed from the HDL using the `mem_model` HDL component, which may be instantiated any number of times, but always accesses the same memory. This allows multiple _VProc_ virtual processors and the simulated test bench logic to access a common memory space.

The inherited `soc_cpu.VPROC` component has a `mem_model` instantiated for program writes via a UART; the `soc_cpu.VPROC.picorv32` wrapper used here has none, but the software running on its _VProc_ virtual processor can still access the memory directly via the API. The software running on the  _VProc_ used on the [_pcievhost_](#driving-the-pcie-link) in the `pcieVHostPipex1` driver also has access to the same API and memory space.

Details of the memory model HDL can be found in the [README.md](models/cosim/README.md) in `5.sim/models/cosim`.

## Driving the PCIE Link

The _openPCIE_ logic has interfaces for a single PCIE PIPE x1 downstream data port, transferring PCIE packets for GEN1 and GEN2 standards. In order to drive these interfaces, the test bench has a `pcieVHostPipex1` module based on the _pcieVHost_ VIP to generate the PCIE traffic.

<p align=center>
<img alt="pcieVHost module" width=750 src="models/pcievhost/images/pcievhost_module.png">
</p>

More details on the PCIE driver and _pcieVHost_ can be found in the [README.md](models/pcievhost/README.md) file in `5.sim/models/pcievhost`, along with details of configuring and driving the model.

## Co-simulation HAL

### Using the HAL

The HAL provides a hierarchical access to the registers via a set of pointer dereferencing and a final access method (for reads and writes of registers and their bit fields) that reflects the hierarchy of the RDL specification. The following are real accesses out of [`usercode/VUserMain0.cpp`](usercode/VUserMain0.cpp), the `CPU=vproc` application, based on `4.build/csr_build/csr.rdl`:

```c++
#include "csr_cosim.h"

// The root object, at the CSR base address in the SOC memory map
csr_vp_t* csr = new csr_vp_t((uint32_t*)0x30000000);

// Whole-register write. Writing tx.data is what launches the TLP,
// because the field is marked swmod in the RDL.
csr->tx->header0->full(h0);
csr->tx->header1->full(h1);
csr->tx->header2->full(h2);
csr->tx->data->full(data);

// Whole-register read, then fields picked out with the generated
// masks and positions from csr.h -- one bus access, not two
uint32_t phy = csr->status->phy->full();
uint32_t state = (phy & CSR__STATUS__PHY__TX_STATE_bm)  >> CSR__STATUS__PHY__TX_STATE_bp;
uint32_t avail = (phy & CSR__STATUS__PHY__TX_BUF_AV_bm) >> CSR__STATUS__PHY__TX_BUF_AV_bp;

// Single-field read -- one bus access, field extracted for you
uint32_t status = csr->rx->status->cpl_status();
```

Each access becomes a real transaction on the CPU bus in the simulation, so the
waveform and the `CPU_TRACE` output show them exactly as they show the RTL
core's accesses.
The above code will compile either natively for *VProc* or for the RISC-V hardware, with the appropriate header, as described above. Write accesses use a method with the final register bit field name with an appropriate argument (this is either a `uint64_t` or `uint32_t` as appropriate to the register's definition). A read access is done in the same manner but without an argument and returns a value (either a `uint64_t` or `uint32_t` as appropriate).

A convention has been used where to access a whole register the 'bit field' access method is named `full`, with bit field accesses using their declared names, as normal. Some assumptions have been made with the script as it stands based on the current `csr.rdl` (but new features can be added). The main one currently is that arrays can't be multi-dimensional (hierarchy can be used to achieve the same thing) and an error is thrown if detected.

### Other Co-simulation considerations

The HAL software abstracts away the details of hardware and co-simulation register accesses but a couple of other considerations are needed to allow code to compile both for hardware and simulation. The first of these is the `main` entry point.

A normal application compiled for the target has a `main()` entry point function. In *VProc* co-simulation, this is not the case as the logic simulation itself has a `main()` function already defined and there can be multiple *VProc* node instantiations, each with their own entry point. These are named `VUserMain<n>`, where `<n>` is the node number. So, node 0 has an entry point function `VUserMain0`. The auto-generated HAL co-simulation headers include a `PCIEMAIN` definition that is either `main` for the hardware code or `VUserMain0` for *VProc* code (assuming node 0 for `soc_cpu`). This is then used in place of `main` at the top level application code.

```
#include "openpcie_regs.h"

// Application top level
void PCIEMAIN (void)
{
  // Top level source code here
}
```

The second consideration is the use of delay functions. This can be in the form of standard C functions, such as `usleep`, or application specific functions using instruction loops. In either case, these should be wrapped in a commonly named function&mdash;e.g., `pcie_usleep(int time)`. The wrapper delay library function will then need to have `VPROC` selected code to either call the application specific target delay function, or to convert the specified time to clock cycles and call the *VProc* API function `VTick` (or its C++ API equivalent) to advance simulation time the appropriate amount. The co-simulation auto-generated HAL header has `SOC_CPU_CLK_PERIOD_PS` defined that can be configured on the `4.build/sysrdl_cosim.py` command line with `-C` or `--clk_period`, but defaults to 16000, i.e. the 62.5MHz `clk62m5` that the PCIE hard macro hands to `riscv_pcie_soc` on an x1 Gen2 link with a 64-bit datapath. A `SOC_CPU_VPNODE` is also defined, defaulting to 0, for use when calling the *VProc* C API functions directly. The definition is affected by the `-v` or `--vp_node` command line options of `4.build/sysrdl_cosim.py`.

## Our Local VIP Improvements

How our co-simulation models differ from upstream, beyond [Local changes](#local-changes):

- **rv32 ISS built from source.** `models/rv32/src` holds the ISS sources at upstream `774d84fa`; the make file builds the library. Two fixes in `rv32-openpcie.patch`: the timer-compare check no longer adds 2 cycles to every instruction, and `sw`/`sh` take store timing, not load.
- **Timing measured on our RTL.** `rv32_timing_config.h` holds cycles per instruction class measured in this SOC, so they include its memory latency (fetch included, no wait states):

  | Core | linear | jump | load | store |
  |---|---|---|---|---|
  | PicoRV32 (`BARREL_SHIFTER=0`) | 4 | 4 | 8 | 7 |
  | eduBOS5 2-stage | 2 | 2 | 5 | 2 |
  | eduBOS5 3-stage | 3 | 3 | 6 | 3 |

  eduBOS5 is exact; PicoRV32 is a fit, as it prefetches and its shifts take 1 cycle per 4 or 1 bit.
- **Bus credit.** A load or store to the simulation takes real clocks on the VProc bus, but the timing table already counts them. The ISS takes those clocks (2 per access) off its next synchronisation, so an access costs only its table cycles.
- **2-clock bus.** `soc_cpu.VPROC.picorv32.sv` runs picorv32's handshake: `mem_valid` with the request, `mem_ready` as the ack, one idle cycle after. Was 4 clocks.
- **Reset input.** `!resetn` drives VProc interrupt bit 3. The ISS starts at reset release, as the RTL core does, and restarts at the reset vector on a new reset.

Result: the ISS lands within 0.6% of the RTL core it models ([What they cost](#what-they-cost)).

## Open-source PCIE Validation Stacks

What exists in the open (Oct 2026), dynamic and static:

| Stack | Technique | Level | Checks the protocol? |
|---|---|---|---|
| [pcievhost](https://github.com/wyvernSemi/pcievhost) | co-simulation model, C | PIPE lanes up to TLP: LTSSM, DLL, TLP | not as a checker: a link partner, the Endpoint here |
| [cocotbext-pcie](https://github.com/alexforencich/cocotbext-pcie) | cocotb model, Python | TLP: Root Complex, switches, Endpoints, config space, BARs, MSI, DMA | not as a checker: a link partner; Xilinx models are UltraScale(+) device only, no 7-series `PCIE_2_1` |
| WaveCrux plugins: [our TLP decoder](tools/wavecrux-pcie-tlp), [Ferrite's PCIe decoders](https://github.com/Ferrite-Engineering/wavecrux-decoders) | post-simulation, on the waveform | TLP; PIPE, DLL and serial line | partly: CRC, sequence numbers, 8b/10b and disparity |
| [ngscopeclient](https://www.ngscopeclient.org/) (scopehal, BSD-3) | post-capture, on scope or imported VCD waveforms | serial lane up: 8b/10b, 128b/130b, link training, 1-32 lane logical layer, DLL, TLP | partly: flags bad symbols and malformed packets; starts from the serial line, so it does not read our PIPE dump; no FST import yet: requested in [scopehal #1121](https://github.com/ngscopeclient/scopehal/issues/1121), details in [#38](https://github.com/chili-chips-ba/openPCIE/issues/38) |
| [SymbiYosys](https://github.com/YosysHQ/sby) | formal | any, with your own SVA | only what you write: no open PCIE property set found |

**The gap:** no open checker of the PCIE rules themselves -- flow-control credits, Ack/Nak and replay timing, ordering, completion matching and timeout, TLP format. The models are link partners: they talk PCIE, they do not judge it. Commercial verification IP covers this.

The WaveCrux decoders already parse every layer that these rules are about, from the serial line up to TLPs, and run on the dump of any simulator. We asked Ferrite to turn them into a protocol checker ([WaveCrux discussion #55](https://github.com/Ferrite-Engineering/wavecrux/discussions/55)).

## Simulation issues

Fixed in this repo only; [Local changes](#local-changes) lists how we differ from upstream.

| # | Model | Issue | Status |
|---|---|---|---|
| 1 | pcievhost | LTSSM deadlocks against the real `PCIE_2_1` | fixed here: `ltssm-openpcie.patch` |
| 2 | pcievhost | UpdateFC sent before InitFC1 | fixed upstream, 1.9.3 |
| 3 | RV32-ISS | Charges 2 cycles more per instruction than its timing model | fixed here: `rv32-openpcie.patch`, [#32](https://github.com/chili-chips-ba/openPCIE/issues/32) |
| 4 | RV32-ISS | `sw`/`sh` take load timing, not store | fixed here: `rv32-openpcie.patch`, [#33](https://github.com/chili-chips-ba/openPCIE/issues/33) |
| 5 | RV32-ISS | No reset input; runs before the RTL core leaves reset | fixed here: reset on VProc interrupt bit 3, [#34](https://github.com/chili-chips-ba/openPCIE/issues/34) |
| 6 | RV32-ISS | Ours was v1.3.3; upstream is 3 commits ahead | fixed here: sources at `774d84fa`, [#32](https://github.com/chili-chips-ba/openPCIE/issues/32) |
| 7 | RV32-ISS | Timing tables not matched to the RTL cores | fixed here: within 0.6%, [#35](https://github.com/chili-chips-ba/openPCIE/issues/35) |

## References:
- [VProc](https://github.com/wyvernSemi/vproc)
- [mem_model](https://github.com/wyvernSemi/mem_model)
- [PCIe VHost Model](https://github.com/wyvernSemi/pcievhost)
- [Logic sim using pcieVHost and 3rd Party PCIe](https://www.linkedin.com/pulse/case-study-logic-simulation-environment-using-third-party-southwell-tyere)
- [rv32 RISC-V ISS](https://github.com/wyvernSemi/rv32/tree/main/iss)
- [SystemRDL](https://www.accellera.org/downloads/standards/systemrdl)
- [PeakRDL and SystemRDLcompiler](https://github.com/SystemRDL)
- [WaveCrux waveform viewer](https://wavecrux.app) and its [decoder plugin interface](https://github.com/Ferrite-Engineering/wavecrux/blob/main/include/wavecrux_decoder.h)
- [wavecrux-decoders](https://github.com/Ferrite-Engineering/wavecrux-decoders): Ferrite's open-source PCIE PIPE and Data Link Layer decoders for WaveCrux


-------
#### End-of-Document