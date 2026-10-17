# opensource openXC7 build flow

Builds the opensource RC into a bitstream with **open-source tools only**, no Vivado. Part `xc7a200tfbg484-3` (Acorn CLE-215P), as in the Vivado build.

- `make`: [`RC-direct.opensource`](../../2.rtl/2.RC-direct.opensource), **x4** (default) -> `top.x4.direct.bit`; `make LANES=1` for x1
- `make VARIANT=switched`: [`RC-switched.opensource`](../../2.rtl/3.Bonus--RC-switched.opensource), x1

Both come from the same RTL, [`2.rtl/0.common.opensource`](../../2.rtl/0.common.opensource) (top `RC_opensource`), and differ only in firmware and GT pins (see [GT channel](#gt-channel)).

| Stage | v1.0.0 (default) | pre-v1.0.0 (`TOOLCHAIN=old`) |
|---|---|---|
| SV front end | `yosys read_slang` (or `sv2v`) | `sv2v` -> `.v` |
| Synthesis | `yosys` -> `top.json` | `yosys` -> `top.json` |
| Place & route | `nextpnr-himbaechel` (via the `nextpnr-xilinx` shim) -> `top.fasm` | `nextpnr-xilinx` -> `top.fasm` |
| Bitstream | `fpga-as` -> `top.bit` | `fasm2frames` + `xc7frames2bit` (prjxray) -> `top.bit` |

## Status: working on hardware

`make TOOLCHAIN=old LANES=1` (pre-v1.0.0) produces `build_artifacts/top.x1.direct.bit`. On the board it brings the link **up at Gen2** against a second Artix-7 board as endpoint, the same readings as the Vivado bitstream from the same RTL:

```
user_lnk_up = 1
LTSSM       = 0x16
phy_lnk_up  = 1
rate        = Gen2
```

It took six fixes: one latent RTL bug and five workarounds for openXC7 defects, all described below.

---

## ⚠ The nextpnr-xilinx version is critical

The pre-v1.0.0 toolchain builds this design **only** with nextpnr-xilinx `45a986b` (`v0.8.2-79-g45a986b8`, 2026-04-18).

| Version | Result |
|---|---|
| 0.8.2, snap (Jun 2024) | **too old**: no `site_type_PCIE_2_1.json`, so no `PCIE_2_1` BELs |
| master `bab26c2` (Jul 2026) | **regression**: `router2` loops in `route_xilinx_const` (gdb) |
| **`45a986b` (Apr 2026)** | **works** |

Yosys 0.38 from the snap is fine.

### Building the right version

```bash
git clone https://github.com/openXC7/nextpnr-xilinx.git && cd nextpnr-xilinx
git checkout 45a986b
git submodule update --init --depth 1 \
    xilinx/external/prjxray-db xilinx/external/nextpnr-xilinx-meta
mkdir build && cd build
cmake .. -DARCH=xilinx -DCMAKE_BUILD_TYPE=Release -DBUILD_GUI=OFF \
         -DCMAKE_POLICY_VERSION_MINIMUM=3.5      # needed with cmake 4.x
make -j$(nproc)
install -Dm755 nextpnr-xilinx bbasm /usr/local/bin/
```

Default tree: `/opt/openxc7_extra/npnr_45a986b`; elsewhere, pass `NEXTPNR_SRC=`.

**Do not mix versions.** `prjxray-db`, the site metadata and `constids.inc` must come from the same tree as the nextpnr binary, or wire indices go wrong and the failures look like router bugs. The Makefile takes all of them from `$(NEXTPNR_SRC)`.

---

## Pre-v1.0.0 and new openXC7 toolchain

**Validated on hardware with the pre-v1.0.0 toolchain:**

| Tool | Version used |
|---|---|
| nextpnr | `nextpnr-xilinx` `45a986b` (Apr 2026), built as above |
| Yosys | 0.38, openXC7 snap |
| Bitstream | prjxray `fasm2frames` + `xc7frames2bit`, openXC7 snap |
| SV conversion | `sv2v` |

Since then `nextpnr-xilinx` is archived and the snap and one-line installer are gone. The **new** toolchain is built with [`toolchain-sources-builder.sh`](https://github.com/openXC7/toolchain-installer), or installed through Nix or Apio:

| Tool | New toolchain (openXC7 v1.0.0, as of Sept 2026) |
|---|---|
| nextpnr | [`openXC7/nextpnr`](https://github.com/openXC7/nextpnr), the *himbaechel* Xilinx engine |
| Yosys | v0.69 |
| Bitstream | `fpga-as`, replacing `fasm2frames` + `xc7frames2bit` |
| Formal, optional | Yosys `sat`; [EBMC](https://www.cprover.org/ebmc/) 6.1 |

The Makefile supports both: `TOOLCHAIN=new` (default) and `TOOLCHAIN=old`. **Only pre-v1.0.0 is validated on hardware**; v1.0.0 builds both variants and their configuration checks out, but none of its bitstreams has been on the board yet. To reproduce the validated result, use pre-v1.0.0 (`45a986b` is still in the archived repo, see [Building the right version](#building-the-right-version)). Below, pre-v1.0.0 is meant unless stated.

### Building with the new toolchain

**1. Toolchain**, into a user-owned prefix (only the package install needs `sudo`):

```bash
git clone https://github.com/openXC7/toolchain-installer && cd toolchain-installer
INSTALL_PREFIX=$HOME/opt/openxc7 ./toolchain-sources-builder.sh all
```

It installs missing Ubuntu packages, then builds Yosys, nextpnr, prjxray and `fpga-as`: about 14 minutes (Ubuntu 24.04 in WSL2, 16 threads).

**2. sv2v**, optional with v1.0.0 - see [Prerequisites](#2-sv2v). We used v0.0.13.

**3. Build:**

```bash
cd 4.build
source set-env.sh                       # finds openXC7 in ~/opt/openxc7 or /opt/openxc7
cd hw_build.openXC7
make check-env
make                                    # read_slang, x4 -> build_artifacts.x4.slang/top.x4.direct.bit
make LANES=1                            # read_slang, x1 -> build_artifacts.slang/top.x1.direct.bit
make VARIANT=switched                   # read_slang, x1 -> build_artifacts.switched.slang/top.x1.switched.bit
make FRONTEND=sv2v                      # sv2v,       x4 -> build_artifacts.x4.new/top.x4.direct.bit
```

v1.0.0 has its own `chipdb.new/` (different format) and output folders, so it never overwrites the validated `build_artifacts*/top.x1.*.bit`. Its `read_slang` bitstreams are kept in git as prebuilt files of the current RTL (not yet tested on the board); the `sv2v` ones are not.

**What changed:** the chipdb comes from `xilinx_gen.py` instead of `bbaexport.py`, and `fpga-as` replaces `fasm2frames` + `xc7frames2bit`. Synthesis and P&R are called as before; the new `nextpnr-xilinx` is a small shim that passes the same options to `nextpnr-himbaechel`.

**Measured** (RC-direct unless noted):

| | Pre-v1.0.0 toolchain | New toolchain |
|---|---|---|
| Build time, chipdb cached | about 2 min | 2 min 13 s (1) |
| First build, incl. chipdb | several minutes | 6 min |
| GT channel, link speed | channel 1, Gen2 | channel 1 (2), Gen2 |
| Flip-flops after synthesis (3) | 1770 | 1486 + 9 SRLs |
| Pipe clock `clk_oobclk`, 250 MHz | misses it (4) | 280 MHz (5), passes |
| On hardware | **link up at Gen2** | not tested yet |

1. RC-switched 2 min 21 s; 16 threads.
2. RC-switched: channel 2.
3. Different RTL, not comparable: Yosys 0.38 on the RTL of 2026-08-19, Yosys 0.69 without `-nosrl` on that of 2026-10-08.
4. Expected and verified harmless, see [Clocks](#clocks).
5. RC-switched 274 MHz.

nextpnr's warning "Overriding derived constraint of 250.0 MHz on net u_pcie.clk_oobclk with user-specified constraint of 125.0 MHz" is harmless: it prints the two values swapped, and the 250 MHz from `openxc7.xdc` applies ([#21](https://github.com/chili-chips-ba/openPCIE/issues/21)).

[openXC7 findings](#openxc7-findings) lists which defects still apply to v1.0.0. The design-side fixes are in the RTL, so v1.0.0 builds get them too.

## Native SV within Yosys, through Slang

Open-source Yosys long read only a subset of SystemVerilog, without the packages, interfaces with modports and packed structs this design uses; hence sv2v. Full SystemVerilog came only with the commercial Verific front end (YosysHQ Tabby CAD Suite).

Since **Yosys 0.67**, every Yosys build has its own SystemVerilog front end, `read_slang`, built on the [slang](https://github.com/MikePopoloski/slang) compiler through [sv-elab](https://github.com/povik/sv-elab). With v1.0.0 it is the default here, no sv2v:

```bash
source ../set-env.sh
make                                    # -> build_artifacts.x4.slang/top.x4.direct.bit
make VARIANT=switched                   # -> build_artifacts.switched.slang/top.x1.switched.bit
```

**Our SystemVerilog goes in unchanged:** all 34 files (packages, interfaces, structs, the SystemVerilog picorv32), no language errors. Synthesis about 10 s, the whole build 2 min 26 s (2 min 13 s with sv2v).

**The Xilinx primitives need three workarounds** for upstream gaps:

| Problem | Workaround |
|---|---|
| Primitives need declarations with parameters (a) | [`gen_xilinx_bb.py`](gen_xilinx_bb.py) writes them for the 8 primitives used |
| No `real` parameters on primitives ([sv-elab#282](https://github.com/povik/sv-elab/issues/282)) | MMCM real settings behind `` `ifndef SYN_YOSYS_BUG `` (b) |
| `IBUFDS_GTE2.CLKSWING_CFG` default is `"TRUE"`, not `2'b11` ([yosys#6322](https://github.com/YosysHQ/yosys/issues/6322)) | `gen_xilinx_bb.py` writes `2'b11` |

- (a) Yosys's blackboxes have no parameters ([sv-elab#367](https://github.com/povik/sv-elab/pull/367)), and its `cells_sim.v` fails slang's checks ([yosys#6323](https://github.com/YosysHQ/yosys/issues/6323)). The script takes them from Yosys's own library; the Makefile runs it.
- (b) In `clk_rst_gen.sv`; the settings are all defaults, and this flow defines `SYN_YOSYS_BUG`.

**Versus the sv2v build**, the FASM differs only in 9 `GTPE2_CHANNEL` fields our RTL leaves unset: `read_slang` passes Xilinx's defaults, sv2v leaves them to nextpnr. So the slang build is closer to Vivado. Not tested on hardware yet.

---

## ⚠ nextpnr's GT attribute defaults do not match Xilinx's

**This is why the design did not work on hardware, and the most generally useful finding here.**

For an omitted RTL parameter, Vivado takes the `unisim` default. In openXC7 the parameter is missing from the netlist, so nextpnr uses **its own** default, nearly always `0`, without a warning.

Comparing every `GTPE2_CHANNEL` attribute the RTL leaves unset against the `cells_xtra.v` default and the `*_or_default(...)` call in `xilinx/fasm.cc` gives the mismatches. The **20** that matter here:

| Attribute | Xilinx library | nextpnr | Consequence |
|---|---|---|---|
| `TX_CLKMUX_EN` | `1'b1` | `0` | **GT-internal TX clock mux off** |
| `RX_CLKMUX_EN` | `1'b1` | `0` | **GT-internal RX clock mux off** |
| `PMA_RSV` | `32'h00000333` | `0` | TX PMA analog config wrecked |
| `TXPI_PPMCLK_SEL` | `"TXUSRCLK2"` | `"TXUSRCLK"` | wrong TX phase-interpolator clock |
| `PD_TRANS_TIME_FROM_P2` | `12'h03C` | `0` | PCIE P-state transition timing |
| `PD_TRANS_TIME_TO_P2` | `8'h64` | `0` | same |
| `OUTREFCLK_SEL_INV` | `2'b11` | `0` | |
| `TRANS_TIME_RATE` | `8'h0E` | `0` | |
| `RXOOB_CFG` | `7'b0000110` | `0` | OOB detection |
| `RXLPM_HF_CFG` / `RXLPM_LF_CFG` | non-zero | `0` | RX equaliser |
| `RX*RESET_TIME` (5, below) | `5'b00001` / `7'b0001111` | `0` | reset pulse widths |
| `SATA_*` (3, below) | non-zero | `0` | |

`RX*RESET_TIME`: `RXBUFRESET_TIME`, `RXCDRFREQRESET_TIME`, `RXCDRPHRESET_TIME`, `RXISCANRESET_TIME`, `RXLPMRESET_TIME`. `SATA_*`: `SATA_BURST_SEQ_LEN`, `SATA_BURST_VAL`, `SATA_EIDLE_VAL`.

Symptom: the GT came up (PLL0 locked, every `resetdone` asserted), but TX phase alignment never started. `TXDLYSRESETDONE` never toggled, the sync FSM sat in `TX_START`, and the LTSSM never left `DETECT_QUIET`.

`lane_xcvr.sv` now sets all 20 to the **library** values, which Vivado was already using. That is also why [regymm/pcie_7x](https://github.com/regymm/pcie_7x) works on openXC7 with the same GTP and TX-buffer-bypass mode: it sets every attribute, so nextpnr has nothing to guess.

**Rule of thumb:** with this toolchain, set every hard-block attribute explicitly.

---

## Design-side requirements

### `-nosrl` at synthesis

Required with pre-v1.0.0. Otherwise the 96- and 128-bit shift registers of the PLL0 power-up delay (`gtp_wrapper.sv`) become `SRLC32E` chains and nextpnr fails on the cascade output:

```
ERROR: No wire found for port Q31 on source cell ... fpga_srl_0
```

v1.0.0 handles the cascade, so the Makefile passes `-nosrl` only with `TOOLCHAIN=old`.

| v1.0.0, RC-direct | with `-nosrl` | without |
|---|---|---|
| Flip-flops | 1702 | 1486 |
| SRL cells | 0 | 7 `SRLC32E`, 2 `SRL16E` |
| LUTs | 1761 | 1740 |
| `clk_oobclk` Fmax (250 MHz target) | 259 MHz | 280 MHz |

*(`-nocarry` and `--router router1` only worked around the broken master nextpnr; `45a986b` needs neither.)*

### `TXPI_SYNFREQ_PPM` forced to non-zero

`lane_xcvr.sv` sets `.TXPI_SYNFREQ_PPM(3'd1)`. With 0, nextpnr stops:

```
fasm.cc:3146  if (txpi_synfreq_ppm == 0) log_error("TXPI_SYNFREQ_PPM must not be zero!")
```

Yet 0 is Xilinx's default, and Xilinx's own PCIE IP uses it. We set 1 only to pass this check.

> ⚠ **This is a hack, and hacks like it are dangerous.** The value satisfies the tool, not the silicon, so our RTL departs from Xilinx's default here, in the Vivado build too. It works on our board, but what `TXPI_SYNFREQ_PPM = 1` does to the TX phase interpolator is unverified. Never change a hard-block attribute just to silence a tool: fix the tool, or check the value against Xilinx's documentation. We go back to 0 once nextpnr accepts it ([#27](https://github.com/chili-chips-ba/openPCIE/issues/27), upstream [nextpnr#88](https://github.com/openXC7/nextpnr/issues/88)).

### Unused GT refclk inputs left unconnected

`gtp_wrapper.sv` tied seven unused refclk inputs (`GTGREFCLK0/1`, `GTREFCLK1`, `GTEASTREFCLK0/1`, `GTWESTREFCLK0/1`) to `1'd0`. Vivado accepts that; nextpnr rejects any constant on a refclk input (`pack_gt_xc7.cc:184`). They are now unconnected.

### PLL0 power-up delay clocked from `clk125`

Xilinx's wrapper clocks the PLL0 power-up delay from:

```systemverilog
BUFG wake_refclk_bufg (.I (PIPE_CLK), .O (gt_cpllpdrefclk));
```

`PIPE_CLK` is `IBUFDS_GTE2.O`. In Vivado this works. **nextpnr routes the net without error, but the BUFG output does not toggle on the board**: a JTAG probe read a counter on `gt_cpllpdrefclk` stuck at 0, while counters on `clk62m5` and `clk_pclk` ran.

```
gt_cpllpdrefclk dead -> power-up delay never finishes counting
                     -> cpllpd and cpllrst stay asserted
                     -> PLL0PD=1, PLL0RESET=1  (PLL0 powered down, not mistuned)
                     -> PLL0LOCK=0 -> GT reset FSM stuck at ST_GTPLL0_LOCK
                     -> LTSSM stuck in DETECT_QUIET forever
```

So no PLL0 *configuration* fix could help: the PLL was off.

Workaround: `gtp_wrapper` clocks the delay from `clk125`, the MMCM's 125 MHz output. It runs while PLL0 is still down, since the MMCM is fed by `TXOUTCLK`, which follows the reference clock regardless of PLL lock. The delay only times startup, so 125 instead of 100 MHz shortens it by 20%, harmlessly.

All RTL changes were re-validated in Vivado end to end: synthesis, implementation, bitstream, 0 errors, 0 critical warnings, link up at Gen2.

---

## Prerequisites

Run [`../set-env.sh`](../set-env.sh) first: it finds these tools, checks their versions and lists what is missing ([4.build/README.md](../README.md#build-environment)).

### 1. openXC7 toolchain

Provides `yosys`, nextpnr and the bitstream tools. The validated build used the openXC7 snap of the time (Yosys 0.38, prjxray `fasm2frames` / `xc7frames2bit`) with nextpnr `45a986b` built as above. The snap and installer are gone; see [Pre-v1.0.0 and new openXC7 toolchain](#pre-v100-and-new-openxc7-toolchain) and [Building with the new toolchain](#building-with-the-new-toolchain).

### 2. sv2v

**Required with pre-v1.0.0**: Yosys 0.38 does not understand SystemVerilog packages, interfaces or packed structs (`link_pkg`, `axis_if`, `pipe_if`). Optional with v1.0.0, whose Slang front end reads our sources as they are ([Native SV within Yosys, through Slang](#native-sv-within-yosys-through-slang)); sv2v is still the more mature path.

```bash
wget https://github.com/zachjs/sv2v/releases/latest/download/sv2v-Linux.zip
unzip sv2v-Linux.zip && install -Dm755 sv2v-Linux/sv2v /usr/local/bin/sv2v
```

### 3. firmware.hex

`riscv_pcie_soc.sv` loads its RAM with `$readmemh("firmware.hex", ram)`, so run sw_build first. The Makefile reads `../sw_build/firmware.hex`.

### 4. The generated CSR

`soc_csr.sv` wraps the register block PeakRDL generates from `../csr_build/csr.rdl`, so two RTL inputs come from `../csr_build/generated-files/`. They are checked in; regenerate only after editing `csr.rdl`:

```bash
cd ..                     # 4.build/
make -f MakefileCSR       # -> csr_build/generated-files/{csr_pkg,csr}.sv
```

---

## Building

```bash
make check-env                          # tools present; warns if nextpnr is the wrong version
make check-sources                      # every RTL file and firmware.hex present
make                                    # v1.0.0, read_slang (default), x4 -> build_artifacts.x4.slang/top.x4.direct.bit
make LANES=1                            # v1.0.0, read_slang, x1           -> build_artifacts.slang/top.x1.direct.bit
make CPU=picorv32                       # PicoRV32 instead of eduBOS5      -> build_artifacts.x4.picorv32.slang/top.x4.direct.bit
make FRONTEND=sv2v                      # v1.0.0, sv2v, x4                 -> build_artifacts.x4.new/top.x4.direct.bit
make TOOLCHAIN=old LANES=1              # pre-v1.0.0, x1                   -> build_artifacts/top.x1.direct.bit
make TOOLCHAIN=old VARIANT=switched     # pre-v1.0.0, x1                   -> build_artifacts.switched/top.x1.switched.bit
```

| Target | Purpose |
|---|---|
| `make convert` | only sv2v conversion + module extraction (`FRONTEND=sv2v`) |
| `make TOOLCHAIN=old` | build with the pre-v1.0.0 toolchain, into `build_artifacts/` |
| `make FRONTEND=sv2v` | v1.0.0 through sv2v instead of `read_slang`, into `build_artifacts.new/` |
| `make info` | print resolved configuration and tool paths |
| `make clean` | remove `build_artifacts/` and the local copy of `firmware.hex` |
| `make clean-converted` | remove `converted/` |
| `make clean-all` | all of the above, plus `chipdb/` |

Each tool is called through a variable (`YOSYS`, `NEXTPNR_XILINX`, `FPGA_AS`, ...) that `set-env.sh` sets; override one with e.g. `make YOSYS=/path/to/yosys`.

`VARIANT=switched` gets its own `converted.switched/` and `build_artifacts.switched/`, and the clean targets act on those, so the variants never mix. `chipdb/` is shared (it depends on the part, not the design). `../sw_build/firmware.hex` is **not** separated: build the matching firmware first (`make VARIANT=switched` in `sw_build/`).

**Every `make` rebuilds from scratch**; only the chipdb is kept. Switching `CSR` changes the file list but no file, so a date-based make would keep the old bitstream, and dates on a network share can be from the future. Always rebuilding avoids both; `make clean` is never needed.

The first build generates the chipdb for `xc7a200tfbg484-3` (317 MB, several minutes) and caches it in `chipdb/`. After that a build takes about 2 minutes.

---

## Constraints

nextpnr's XDC parser accepts only `[get_ports]` and `[get_nets]` targets, so the Vivado XDC cannot be used. `openxc7.x4.xdc` (RC-direct x4, default), `openxc7.x1.xdc` (RC-direct x1) and `openxc7.switched.xdc` (RC-switched, x1) are cut-down versions. The Vivado files (`2.rtl/0.common.opensource/xdc/` plus each variant's GT lane XDC) remain the reference for the AMD flow.

### GT channel

The GT channel `LOC` (x1: `GTPE2_CHANNEL_X0Y5`) is set **indirectly**, through the GT pad pins. In prjxray the `IPAD`, `OPAD` and `GTPE2_CHANNEL` sites share a hard-wired tile, so the pins choose the channel:

```tcl
set_property PACKAGE_PIN C5  [get_ports txn]   ;# MGTPTXN1_216
set_property PACKAGE_PIN D5  [get_ports txp]   ;# MGTPTXP1_216
set_property PACKAGE_PIN C11 [get_ports rxn]   ;# MGTPRXN1_216
set_property PACKAGE_PIN D11 [get_ports rxp]   ;# MGTPRXP1_216
```

Vivado is the other way round: the channel `LOC` decides the pads, and pin constraints alone do not move the lane.

Bank 216, from `prjxray-db/artix7/xc7a200tfbg484-3/package_pins.csv` (the `tile` column names the tile):

| Channel | Vivado LOC | RX pins | TX pins |
|---|---|---|---|
| 0 | `GTPE2_CHANNEL_X0Y4` | A8/B8 | A4/B4 |
| **1** | **`GTPE2_CHANNEL_X0Y5`** | **C11/D11** | **C5/D5** |
| 2 | `GTPE2_CHANNEL_X0Y6` | A10/B10 | A6/B6 |
| 3 | `GTPE2_CHANNEL_X0Y7` | C9/D9 | C7/D7 |

RC-switched uses channel **2** (`openxc7.switched.xdc`), the position its Vivado XDC locks. x4 (`openxc7.x4.xdc`) uses all four: board lanes 0, 1, 2, 3 on channels 2, 0, 1, 3. Channels are numbered as in prjxray; [`2.rtl/README.md`](../../2.rtl/README.md#common-physical-constraints-xdc) lists the same positions by board lane.

After every build the FASM must contain `GTP_CHANNEL_1_MID_LEFT` (`GTP_CHANNEL_2_...` for RC-switched). The P&R step prints it:

```bash
grep -oE "GTP_CHANNEL[A-Z0-9_]*_X[0-9]+Y[0-9]+" build_artifacts/top.fasm | sort -u
```

**Gotcha:** at `PCIE_LANES=1` the netlist port is `txn`, not `txn[0]`; `[get_ports {txn[0]}]` silently matches nothing. At x4 it is the reverse: `openxc7.x4.xdc` must use `{txn[0]}` ... `{txn[3]}`.

### Clocks

`create_clock` on `[get_nets]` **is** supported (`xilinx/xdc.cc:169`); `create_generated_clock`, `set_false_path` and `set_clock_groups` are not.

An **unconstrained** clock gets nextpnr's default target of **12 MHz**, so it is never optimised and never reported as failing. Three of the four domains here were like that; the pipe clock reached 245 MHz against 250 MHz required, silently.

The target must be the **exact** net name nextpnr reports (`u_pcie.clk_oobclk`), not the RTL hierarchical name. On a miss (`getNetByAlias`), the constraint is dropped **silently** (v1.0.0 now warns). That is why the five `create_clock` lines in regymm/pcie_7x do nothing there: Vivado-style `a/b/c` names, while the netlist has `a.b.c`.

---

## Shims

Vivado supplies these from libraries openXC7 lacks. Open replacements here, unused by the Vivado build:

| File | Replaces | Evidence it is faithful |
|---|---|---|
| `unimacro_shim.v` | `BRAM_TDP_MACRO` (UNIMACRO) | yields **10 RAMB36E1**, same as Vivado |

## openXC7 compared with Vivado: the entire design

**Scope:** the entire RC-direct design (`RC_opensource`): PCIE stack, GTPs, SOC with the default CPU (eduBOS5 2-stage), x4 build, 2026-10-16. The SOC alone, with each of the three CPUs: [eduBOS5 README](../../2.rtl/0.common.opensource/src/CPU.eduBOS5/README.md#cpu-options-compared-the-soc-only).

| | openXC7 v1.0.0 | Vivado 2026.1 |
|---|---|---|
| LUT (incl. LUT-RAM) | 1604 | 1360 |
| LUT-RAM (in the LUT count) | 48 | 44 |
| FF | 2238 | 2183 |
| CARRY4 | 71 | 52 |
| RAMB36E1 / DSP48 | 10 / 0 | 10 / 0 |
| PCIE_2_1 / GTPE2_CHANNEL / GTPE2_COMMON / MMCME2 | 1 / 4 / 1 / 1 | 1 / 4 / 1 / 1 |
| Fmax `clk62m5` (CPU, SOC), needs 62.5 MHz | 138.6 MHz | 142.0 MHz |
| Fmax `clk125`, needs 125 MHz | 357.9 MHz | 181.6 MHz |
| Fmax pipe clock, needs 250 MHz | 311.0 MHz | 301.6 MHz |
| Bitstream | 9 730 756 B | 9 730 769 B |

- openXC7: area is Yosys `synth_xilinx` (`stat`), Fmax nextpnr's report. Vivado: area after implementation (`report_utilization`).
- Vivado reports no Fmax. Its figure here is 1 / (period - WNS); Vivado optimises only until each target is met, so it understates what the design could reach. Compare with care.
- nextpnr's Fmax varies between builds: the same eduBOS5 2-stage SOC gave 158.4 MHz in another build.
- The bitstream is uncompressed, so its size does not depend on the design; the difference is header metadata.

## CPU options compared

The SOC CPU is eduBOS5 2-stage (default), `make CPU=edubos5_3stg` or `make CPU=picorv32`. A non-default CPU builds into its own folder (`build_artifacts.x4.picorv32.slang/`). The three CPUs compared on the SOC only (Fmax, area, IPC): [eduBOS5 README](../../2.rtl/0.common.opensource/src/CPU.eduBOS5/README.md#cpu-options-compared-the-soc-only).

## Lint and formal equivalence of RTL changes

`run-lint.sh` lints the RTL in phases: Verilator, Yosys `check`, slang (Yosys `read_slang`), Verible, and Vivado `report_cdc` for clock-domain crossings. A phase whose tool is missing is skipped; usage is in the script header. Reviewed findings are waived inline on an unused instance output, `.PIN (/*LINT:OK*/)` (flagged on an input), or in `run-lint-waivers.txt` where there is no line of ours (generated code). Anything not waived fails the script.

`run-format.sh` applies the project style: `begin` ... `end` around every single-statement body, then `verible-verilog-format` with the project flags. `--check` changes nothing and exits 1 on an unformatted file. Rules: [2.rtl/README.md](../../2.rtl/README.md).

`run-leq.sh` proves, with the v1.0.0 Yosys, that two versions of the whole design (`RC_opensource`: PCIE stack, SOC, CPU, CSR) behave the same. We use it on RTL cleanups before co-sim and the board; usage is in the script header. Hard macros are black boxes whose pins are compared; logic constant only after reset is reported as unproven and needs a manual look.

---

## Programming the board from WSL

WSL has no direct USB access. [usbipd-win](https://github.com/dorssel/usbipd-win) passes the JTAG cable through:

```powershell
winget install usbipd                   # Windows, once
usbipd list                             # find the cable's BUSID
usbipd bind --busid <BUSID>             # once per cable, admin shell
usbipd attach --wsl --busid <BUSID>     # after every replug or reboot
```

In WSL, `lsusb` now lists the cable. Load the bitstream with [openFPGALoader](https://github.com/trabucayre/openFPGALoader) (open source, `sudo apt install openfpgaloader`):

```bash
openFPGALoader --detect                 # cable and FPGA found?
openFPGALoader build_artifacts.x4.slang/top.x4.direct.bit
```

Vivado's Hardware Manager works the same way, once its cable drivers are installed (`<Vivado>/data/xicom/cable_drivers/lin64/install_script/install_drivers/install_drivers`, as root). `usbipd detach --busid <BUSID>` hands the cable back to Windows.

---

## Debugging on the board without an ILA

openXC7 has no ILA. What made bring-up possible was a `BSCANE2` shift register read over JTAG: a small module that Vivado reads with `scan_ir_hw_jtag` / `scan_dr_hw_jtag` while the openXC7 bitstream is loaded.

Three probes sat on separate JTAG user chains. `BSCANE2` connects straight to JTAG, so each probe sits next to its signals, with nothing routed up the hierarchy.

| Chain | IR | Location | Contents |
|---|---|---|---|
| USER2 | `0x03` | top | `user_lnk_up`, `user_reset`, `cfg_status`, heartbeat |
| USER3 | `0x22` | `pcie_core` | **LTSSM state**, phy link, rate, width |
| USER4 | `0x23` | `gtp_wrapper` | GT reset FSM, PLL0 lock, `resetdone`, TX sync FSM |

The probes are now removed from the RTL. Two lessons for reuse:

- **`(* keep *)` is mandatory** on the `BSCANE2`, the shift register and the probe instance. With no output ports the module drives nothing, so Yosys silently deletes it, and JTAG reads return garbage.
- **Heartbeat counters on each clock** were the most useful signal. Two running while a third stayed at 0 exposed the dead `IBUFDS_GTE2.O` BUFG, a net static analysis showed as correctly routed.

The other decisive technique was an **A/B build**: the same RTL and probes built once with Vivado and once with openXC7, on the same board. That settled at once whether a fault was in the design or the tool. It also corrected one assumption: `TXDLYSRESETDONE` reads 0 in the *working* build too, because it is a pulse, not a level.

---

## openXC7 findings

Every openXC7 issue this project hit, rechecked on v1.0.0 (nextpnr `3e5c2cdd`). The numbers are stable, for reference from issues and commits. Open items are tracked under the [post-release](https://github.com/chili-chips-ba/openPCIE/milestone/1) milestone, each linked to its upstream report.

### Issues we found: Still Open

| # | Finding | Status | openPCIE | Upstream |
|---|---|---|---|---|
| 1 | GT attribute defaults differ from Xilinx's | open | [#17](https://github.com/chili-chips-ba/openPCIE/issues/17) | [nextpnr#21](https://github.com/openXC7/nextpnr/issues/21) |
| 8 | `BEL` attribute on non-IO cells | still broken, reproduced upstream (a) | [#28](https://github.com/chili-chips-ba/openPCIE/issues/28) | [nextpnr#89](https://github.com/openXC7/nextpnr/issues/89) |
| 14 | `IBUFDS_GTE2.ODIV2` unusable | open, root cause found upstream | [#24](https://github.com/chili-chips-ba/openPCIE/issues/24) | [nextpnr#91](https://github.com/openXC7/nextpnr/issues/91) |
| 18 | Derived-constraint warning swaps its values | new in v1.0.0 | [#21](https://github.com/chili-chips-ba/openPCIE/issues/21) | [nextpnr#85](https://github.com/openXC7/nextpnr/issues/85) |
| 19 | Yosys: wrong `CLKSWING_CFG` default | new, Slang | [#19](https://github.com/chili-chips-ba/openPCIE/issues/19) | [yosys#6322](https://github.com/YosysHQ/yosys/issues/6322) |
| 20 | sv-elab: no `real` primitive parameters | new, Slang | [#20](https://github.com/chili-chips-ba/openPCIE/issues/20) | [sv-elab#282](https://github.com/povik/sv-elab/issues/282) |
| 22 | `read_slang` fails on `xilinx/cells_sim.v` | new, Slang (b) | [#29](https://github.com/chili-chips-ba/openPCIE/issues/29) | [yosys#6323](https://github.com/YosysHQ/yosys/issues/6323), [sv-elab#72](https://github.com/povik/sv-elab/issues/72) |
| 24 | No XPM / UNIMACRO libraries | open; [shims](#shims) stand in | - | - |
| 26 | `set_multicycle_path` cannot reach registers | new (c) | [#36](https://github.com/chili-chips-ba/openPCIE/issues/36) | [nextpnr#110](https://github.com/openXC7/nextpnr/issues/110) |

- (a) The old error is gone, but the name nextpnr reports (`SLICE_X162Y177/A5FF`) is rejected, an accepted one (`X250Y5/SLICE_X0Y0.AFF`) is ignored, and a malformed one aborts nextpnr. Not used by openPCIE.
- (b) 106 errors in `specify` blocks; the reason for `gen_xilinx_bb.py`.
- (c) Only `-to [get_cells -hier -filter {NAME =~ <glob>}]` is read, and it matches cell names, which flip-flops lose in synthesis; `-from` drops the whole constraint. eduBOS5's 3-stage pipeline (`make CPU=edubos5_3stg`) therefore shows no Fmax gain over 2-stage. Test case, proven safe by formal: [eduBOS5 3-stage multicycle paths](../../2.rtl/0.common.opensource/src/CPU.eduBOS5/README.md#3-stage-multicycle-paths).

#### Temp RTL Workarounds / FIXMEs

Each tool workaround in the sources carries a `FIXME` comment (`grep -rn FIXME`), to be removed once its issue is fixed:

| Where | Workaround | Issue |
|---|---|---|
| `lane_xcvr.sv` | `TXPI_SYNFREQ_PPM = 3'd1` instead of Xilinx's 0 | [#27](https://github.com/chili-chips-ba/openPCIE/issues/27) |
| `gtp_wrapper.sv` | PLL0 power-up delay clocked from `clk125` instead of `BUFG(PIPE_CLK)` | [#22](https://github.com/chili-chips-ba/openPCIE/issues/22) |
| `gtp_wrapper.sv` | none, but nextpnr ignores `PLL0_CFG`/`PLL1_CFG` here | [#18](https://github.com/chili-chips-ba/openPCIE/issues/18) |
| `clk_rst_gen.sv` | MMCM `real` parameters left out under `SYN_YOSYS_BUG` (slang flow) | [#20](https://github.com/chili-chips-ba/openPCIE/issues/20) |
| `gen_xilinx_bb.py` | whole script (blackbox stubs for slang), plus the `CLKSWING_CFG` fix | [#29](https://github.com/chili-chips-ba/openPCIE/issues/29), [#19](https://github.com/chili-chips-ba/openPCIE/issues/19) |

### Issues we found: Closed

These affect only the pre-v1.0.0 toolchain.

| # | Finding | Note | Tracked |
|---|---|---|---|
| 4 | Router regression after `45a986b` | nextpnr-xilinx only | not needed |
| 5 | Snap lacks `PCIE_2_1` metadata | the snap is gone | not needed |
| 9 | Yosys 0.38 `iopadmap -ignore` hangs | Yosys 0.38 only | not needed |
| 17 | `fasm2frames` KeyError on `IBUFDS_GTE2` | v1.0.0 uses `fpga-as` | [#14](https://github.com/chili-chips-ba/openPCIE/issues/14) (closed) |

#### Fixed upstream, after v1.0.0

| # | Finding | Note | Tracked |
|---|---|---|---|
| 2 | `IBUFDS_GTE2.O` -> `BUFG` dead clock | board check pending | [#22](https://github.com/chili-chips-ba/openPCIE/issues/22), [nextpnr-xilinx#100](https://github.com/openXC7/nextpnr-xilinx/issues/100) |
| 3 | `PLL0_CFG`/`PLL1_CFG` hardcoded | now read from the design | [#18](https://github.com/chili-chips-ba/openPCIE/issues/18), [nextpnr#84](https://github.com/openXC7/nextpnr/issues/84) |
| 6 | Unconstrained clock silently timed at 12 MHz | main `5ef14a40`; confirmed on main `46c25a91`: it warns, and `IBUFDS_GTE2` -> `BUFG` derives 100 MHz | [#23](https://github.com/chili-chips-ba/openPCIE/issues/23), [nextpnr#90](https://github.com/openXC7/nextpnr/issues/90) |
| 10 | `--placer sa` placement invalid | confirmed on the fix branch (`fddfed5`), seeds 1 and 3; the default placer still times much better | [#25](https://github.com/chili-chips-ba/openPCIE/issues/25), [nextpnr#92](https://github.com/openXC7/nextpnr/issues/92) |
| 11 | `TXPI_SYNFREQ_PPM` = 0 rejected | upstream: the GT and PCIe tiles now match our Vivado golden; board check pending, `3'd1` workaround stays until then | [#27](https://github.com/chili-chips-ba/openPCIE/issues/27), [nextpnr#88](https://github.com/openXC7/nextpnr/issues/88) |
| 21 | Truncated FASM on error still assembles | main `f9e07df8`; the Makefile also checks nextpnr's exit status | [#26](https://github.com/chili-chips-ba/openPCIE/issues/26), [nextpnr#93](https://github.com/openXC7/nextpnr/issues/93) |
| 23 | Contradicting GT `LOC` accepted silently | main `d3acad91` | [#30](https://github.com/chili-chips-ba/openPCIE/issues/30), [nextpnr#94](https://github.com/openXC7/nextpnr/issues/94) |

#### Fixed in v1.0.0

| # | Finding | Note | Tracked |
|---|---|---|---|
| 7 | `create_clock` on an unknown net dropped silently | now warns | not needed |
| 12 | prjxray `bitread` segfaults on xc7a200t | | not needed |
| 13 | SRL32 cascade `Q31` missing | no `-nosrl`: 216 fewer FFs ([more](#-nosrl-at-synthesis)) | not needed |
| 15 | `PSEUDO_GND` rejected on unused `GTREFCLK` | | not needed |
| 16 | `CARRY4.CIN` ground not routable | no `-nocarry`; 384 carry cells pass timing | not needed |
| 25 | No `get_cells` in XDC, so no `LOC` on a hard block | `LOC` now pins `GTPE2_CHANNEL`; pad pins still required | not needed |

-----------
#### End-of-Document
