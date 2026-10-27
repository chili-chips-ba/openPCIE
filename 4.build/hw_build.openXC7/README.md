# opensource openXC7 build flow

From RTL to bitstream with **open-source tools only**. No Vivado, no license server, no tears. Part `xc7a200tfbg484-3` (Acorn CLE-215P), same as the Vivado build.

- `make`: [`RC-direct.opensource`](../../2.rtl/2.RC-direct.opensource), **x4 Gen1** (default). `make GEN=2` for x4 Gen2, `make LANES=1` for x1 Gen2.
- `make VARIANT=switched`: [`RC-switched.opensource`](../../2.rtl/3.Bonus--RC-switched.opensource), x1.

Both share one RTL, [`2.rtl/0.common.opensource`](../../2.rtl/0.common.opensource) (top `RC_opensource`). Only the firmware and the GT pins differ ([GT channel](#gt-channel)). All commands and output folders: [Building](#building).

| Stage | openXC7 v1.0.0 |
|---|---|
| SV front end | `yosys read_slang` (or `sv2v`) |
| Synthesis | `yosys` -> `top.json` |
| Place & route | `nextpnr-himbaechel` (via the `nextpnr-xilinx` shim) -> `top.fasm` |
| Bitstream | `fasm2frames` + `xc7frames2bit` -> `top.<link>.<variant>.bit` (`ASSEMBLER=fpga-as` for the one-step assembler, row 27). Not compressed: neither can do it yet ([lromor/fpga-assembler#59](https://github.com/lromor/fpga-assembler/issues/59)) |

## Status: working on hardware

The pre-v1.0.0 bitstream (`build_artifacts/pre-v1.0.0/top.x1g2.direct.bit`) brings the link **up at Gen2**, against a second Artix-7 board as endpoint. Same readings as the Vivado bitstream from the same RTL:

```
user_lnk_up = 1
LTSSM       = 0x16
phy_lnk_up  = 1
rate        = Gen2
```

It took six fixes: one latent RTL bug and five workarounds for openXC7 defects. All below.

The pre-v1.0.0 flow that built it (nextpnr-xilinx `45a986b`, Yosys 0.38, sv2v) is no longer in the Makefile; commit `54c5409` is the last one that has it (`make TOOLCHAIN=old`). v1.0.0 builds both variants, and their configuration checks out. None of its bitstreams has met the board yet. The findings below were made with pre-v1.0.0, unless stated.

---

## Pre-v1.0.0 and new openXC7 toolchain

**Validated on hardware with the pre-v1.0.0 toolchain:**

| Tool | Version used |
|---|---|
| nextpnr | `nextpnr-xilinx` `45a986b` (Apr 2026), built as above |
| Yosys | 0.38, openXC7 snap |
| Bitstream | prjxray `fasm2frames` + `xc7frames2bit`, openXC7 snap |
| SV conversion | `sv2v` |

Since then, `nextpnr-xilinx` is archived, and the snap and the one-line installer are gone. Build the **new** toolchain with [`toolchain-sources-builder.sh`](https://github.com/openXC7/toolchain-installer), or install it through Nix or Apio:

| Tool | New toolchain (openXC7 v1.0.0, as of Sept 2026) |
|---|---|
| nextpnr | [`openXC7/nextpnr`](https://github.com/openXC7/nextpnr), the *himbaechel* Xilinx engine |
| Yosys | v0.69 |
| Bitstream | `fpga-as`, replacing `fasm2frames` + `xc7frames2bit`; we keep the prjxray pair until `fpga-as` is fixed (row 27) |
| Formal, optional | Yosys `sat`; [EBMC](https://www.cprover.org/ebmc/) 6.1 |

The Makefile builds with v1.0.0 only. To rebuild the board-tested bitstream, check out commit `54c5409` and run `make TOOLCHAIN=old LANES=1` there, with nextpnr-xilinx `45a986b` from the archived repo (its README has the steps).

### Building with the new toolchain

**1. Toolchain**, into a user-owned prefix (only the package install needs `sudo`):

```bash
git clone https://github.com/openXC7/toolchain-installer && cd toolchain-installer
INSTALL_PREFIX=$HOME/opt/openxc7 ./toolchain-sources-builder.sh all
```

It installs missing Ubuntu packages, then builds Yosys, nextpnr, prjxray and `fpga-as`. About 14 minutes (Ubuntu 24.04 in WSL2, 16 threads): one coffee.

**2. sv2v**, optional with v1.0.0 ([Prerequisites](#2-sv2v)). We used v0.0.13.

**3. Build:** `source ../set-env.sh`, then the commands in [Building](#building). `set-env.sh` finds openXC7 in `~/opt/openxc7` or `/opt/openxc7`.

Bitstreams go to `build_artifacts/`, everything else to `build_artifacts/work/` ([Building](#building)). The `read_slang` bitstreams are in git for convenience only, not yet on the board: always rebuild from the current RTL. The board-tested pre-v1.0.0 ones are in `build_artifacts/pre-v1.0.0/`.

The chipdb now comes from `xilinx_gen.py` instead of `bbaexport.py`. Synthesis and P&R are called as before: the new `nextpnr-xilinx` is a small shim that hands the same options to `nextpnr-himbaechel`.

**Measured** on the same build for both: RC-direct x1 Gen2, sv2v front end, unless noted. The default x4 builds use channels 0-3.

| | Pre-v1.0.0 toolchain | New toolchain |
|---|---|---|
| Build time, chipdb cached | about 2 min | 2 min 13 s (1) |
| First build, incl. chipdb | several minutes | 6 min |
| GT channel, link speed | channel 1, Gen2 | channel 1 (2), Gen2 |
| Pipe clock `pipe_clk`, 250 MHz | misses it (3) | 280 MHz (4), passes |
| On hardware | **link up at Gen2** | not tested yet |

1. RC-switched 2 min 21 s; 16 threads.
2. RC-switched: channel 2.
3. Expected and verified harmless, see [Clocks](#clocks).
4. RC-switched 274 MHz.

Older builds warned "Overriding derived constraint of 250.0 MHz on net u_pcie.clk_oobclk with user-specified constraint of 125.0 MHz" (`clk_oobclk` is now `pipe_clk`). v1.0.0 printed the two values swapped, and the 250 MHz from the XDC applied. Fixed on nextpnr main `e313e46f` ([#21](https://github.com/chili-chips-ba/openPCIE/issues/21)).

[openXC7 findings](#openxc7-findings) lists which defects still bite on v1.0.0. The design-side fixes live in the RTL, so v1.0.0 builds get them too.

## Native SV within Yosys, through Slang

For years, open-source Yosys read only a subset of SystemVerilog. No packages, no interfaces with modports, no packed structs: all things this design uses. Hence sv2v. Full SystemVerilog took the commercial Verific front end (YosysHQ Tabby CAD Suite).

Since **Yosys 0.67**, every Yosys has its own SystemVerilog front end, `read_slang`. It is the [slang](https://github.com/MikePopoloski/slang) compiler, through [sv-elab](https://github.com/povik/sv-elab). With v1.0.0 it is our default: plain `make`, no sv2v.

**Our SystemVerilog goes in unchanged:** all 35 files (32 with PicoRV32: packages, interfaces, structs, the CPU), no language errors. Synthesis takes about 10 s, the whole build 2 min 26 s (2 min 13 s with sv2v).

**The Xilinx primitives need three workarounds** for upstream gaps:

| Problem | Workaround |
|---|---|
| Primitives need declarations with parameters (a) | [`gen_xilinx_bb.py`](gen_xilinx_bb.py) writes them for the 9 primitives used |
| No `real` parameters on primitives ([sv-elab#282](https://github.com/povik/sv-elab/issues/282)) | MMCM real settings behind `` `ifndef SYN_YOSYS_BUG `` (b) |
| `IBUFDS_GTE2.CLKSWING_CFG` default is `"TRUE"`, not `2'b11` ([yosys#6322](https://github.com/YosysHQ/yosys/issues/6322)) | `gen_xilinx_bb.py` writes `2'b11` |

- (a) Yosys's blackboxes have no parameters, and its `cells_sim.v` fails slang's checks ([yosys#6323](https://github.com/YosysHQ/yosys/issues/6323)). So the script takes the declarations from Yosys's own library; the Makefile runs it. Yosys main (after 0.70) adds `read_slang --target xilinx`, which loads that library itself ([yosys#6262](https://github.com/YosysHQ/yosys/pull/6262), [sv-elab#396](https://github.com/povik/sv-elab/pull/396)). On our design it still trips twice: `FDCE`'s `specify` block (6 errors, yosys#6323) and `MMCME2_ADV`'s `real` defaults (sv-elab#282). Patch both out, and it builds the same hard blocks, but `CLKSWING_CFG` comes out `"TRUE"` (yosys#6322).
- (b) In `clk_rst_gen.sv`. The settings are all defaults, and this flow defines `SYN_YOSYS_BUG`.

**Versus the sv2v build**, the FASM differs in only 9 `GTPE2_CHANNEL` fields our RTL leaves unset. `read_slang` passes Xilinx's defaults; sv2v leaves them to nextpnr. So the slang build is the closer one to Vivado. Not on the board yet.

---

## ⚠ nextpnr's GT attribute defaults do not match Xilinx's

**This is why the design did not work on hardware, and the most generally useful finding here.**

For an RTL parameter you leave out, Vivado takes the `unisim` default. In openXC7 the parameter is missing from the netlist, so nextpnr uses **its own** default. That is nearly always `0`, and it comes without a warning. Silence is not consent.

We compared every `GTPE2_CHANNEL` attribute the RTL leaves unset: the `cells_xtra.v` default against the `*_or_default(...)` call in `xilinx/fasm.cc`. The **20** mismatches that matter here:

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

Symptom: the GT came up. PLL0 locked, every `resetdone` asserted. But TX phase alignment never started: `TXDLYSRESETDONE` never toggled, the sync FSM sat in `TX_START`, and the LTSSM never left `DETECT_QUIET`. Everything looked fine, and nothing worked.

`lane_xcvr.sv` now sets all 20 to the **library** values, the ones Vivado was using all along. It also explains why [regymm/pcie_7x](https://github.com/regymm/pcie_7x) works on openXC7, with the same GTP and TX-buffer-bypass mode. It sets every attribute, so nextpnr has nothing to guess.

**Rule of thumb:** with this toolchain, set every hard-block attribute explicitly.

---

## Design-side requirements

### `-nosrl` at synthesis

Required with pre-v1.0.0. Without it, the 96- and 128-bit shift registers of the PLL0 power-up delay (`gtp_wrapper.sv`) become `SRLC32E` chains, and nextpnr fails on the cascade output:

```
ERROR: No wire found for port Q31 on source cell ... fpga_srl_0
```

v1.0.0 handles the cascade, so the Makefile no longer passes `-nosrl`.

| v1.0.0, RC-direct | with `-nosrl` | without |
|---|---|---|
| Flip-flops | 1702 | 1486 |
| SRL cells | 0 | 7 `SRLC32E`, 2 `SRL16E` |
| LUTs | 1761 | 1740 |
| `pipe_clk` Fmax (250 MHz target) | 259 MHz | 280 MHz |

*(`-nocarry` and `--router router1` only worked around the broken master nextpnr; `45a986b` needs neither.)*

### `TXPI_SYNFREQ_PPM` forced to non-zero

`lane_xcvr.sv` sets `.TXPI_SYNFREQ_PPM(3'd1)`. With 0, nextpnr stops:

```
fasm.cc:3146  if (txpi_synfreq_ppm == 0) log_error("TXPI_SYNFREQ_PPM must not be zero!")
```

Yet 0 is Xilinx's default, and Xilinx's own PCIE IP uses it. We set 1 only to get past this check.

> ⚠ **This is a hack, and hacks like it are dangerous.** The value pleases the tool, not the silicon. So our RTL departs from Xilinx's default here, in the Vivado build too. It works on our board, but what `TXPI_SYNFREQ_PPM = 1` does to the TX phase interpolator is unverified. Never change a hard-block attribute just to silence a tool. Fix the tool, or check the value against Xilinx's documentation. We go back to 0 once nextpnr accepts it ([#27](https://github.com/chili-chips-ba/openPCIE/issues/27), upstream [nextpnr#88](https://github.com/openXC7/nextpnr/issues/88)).

### Unused GT refclk inputs left unconnected

`gtp_wrapper.sv` tied seven unused refclk inputs (`GTGREFCLK0/1`, `GTREFCLK1`, `GTEASTREFCLK0/1`, `GTWESTREFCLK0/1`) to `1'd0`. Vivado accepts that. nextpnr rejects any constant on a refclk input (`pack_gt_xc7.cc:184`). Now they float, unconnected.

### PLL0 power-up delay clocked from `clk125`

Xilinx's wrapper clocks the PLL0 power-up delay from:

```systemverilog
BUFG wake_refclk_bufg (.I (PIPE_CLK), .O (gt_cpllpdrefclk));
```

`PIPE_CLK` is `IBUFDS_GTE2.O`. In Vivado this works. **nextpnr routes the net without error, but the BUFG output does not toggle on the board.** A JTAG probe read a counter on `gt_cpllpdrefclk`: stuck at 0. Counters on the 62.5 MHz SOC clock (`clk62m5` then, `user_clk` now) and `clk_pclk` ran. A clock with no pulse.

```
gt_cpllpdrefclk dead -> power-up delay never finishes counting
                     -> cpllpd and cpllrst stay asserted
                     -> PLL0PD=1, PLL0RESET=1  (PLL0 powered down, not mistuned)
                     -> PLL0LOCK=0 -> GT reset FSM stuck at ST_GTPLL0_LOCK
                     -> LTSSM stuck in DETECT_QUIET forever
```

So no PLL0 *configuration* fix could help. You can't tune a PLL that is switched off.

Workaround: `gtp_wrapper` clocks the delay from `clk125`, the MMCM's 125 MHz output. It runs while PLL0 is still down. The MMCM is fed by `TXOUTCLK`, which follows the reference clock, lock or no lock. The delay only times startup, so 125 instead of 100 MHz makes it 20% shorter. Harmless.

All RTL changes were re-validated in Vivado end to end: synthesis, implementation, bitstream, 0 errors, 0 critical warnings, link up at Gen2.

---

## Prerequisites

Run [`../set-env.sh`](../set-env.sh) first. It finds these tools, checks their versions and lists what is missing ([4.build/README.md](../README.md#build-environment)).

### 1. openXC7 toolchain

`yosys`, nextpnr and the bitstream tools: see [Building with the new toolchain](#building-with-the-new-toolchain).

### 2. sv2v

Optional (`make FRONTEND=sv2v`). The pre-v1.0.0 Yosys 0.38 needed it: it does not understand SystemVerilog packages, interfaces or packed structs (`link_pkg`, `axis_if`, `pipe_if`). v1.0.0's Slang front end reads our sources as they are ([Native SV within Yosys, through Slang](#native-sv-within-yosys-through-slang)). sv2v is still the more mature path.

```bash
wget https://github.com/zachjs/sv2v/releases/latest/download/sv2v-Linux.zip
unzip sv2v-Linux.zip && install -Dm755 sv2v-Linux/sv2v /usr/local/bin/sv2v
```

### 3. firmware.hex

`riscv_pcie_soc.sv` loads its RAM with `$readmemh("firmware.hex", ram)`. So run sw_build first. The Makefile reads `../sw_build/firmware.hex`.

### 4. The generated CSR

`soc_csr.sv` wraps the register block PeakRDL generates from `../csr_build/csr.rdl`. So two RTL inputs come from `../csr_build/generated-files/`. They are checked in. Regenerate only after editing `csr.rdl`:

```bash
cd ..                     # 4.build/
make -f MakefileCSR       # -> csr_build/generated-files/{csr_pkg,csr}.sv
```

---

## Building

```bash
source ../set-env.sh                    # once per shell
make check-env                          # tools present
make check-sources                      # every RTL file and firmware.hex present
make                                    # x4 Gen1 (default)  -> build_artifacts/top.x4g1.direct.bit
make GEN=2                              # x4 Gen2            -> build_artifacts/top.x4g2.direct.bit
make LANES=1                            # x1 Gen2            -> build_artifacts/top.x1g2.direct.bit
make VARIANT=switched                   # RC-switched, x1    -> build_artifacts/top.x1g2.switched.bit
make CPU=picorv32                       # PicoRV32           -> build_artifacts/work/x4g1.direct.picorv32/top.x4g1.direct.bit
make FRONTEND=sv2v                      # sv2v, not slang    -> build_artifacts/work/x4g1.direct.sv2v/top.x4g1.direct.bit
```

All bitstreams sit side by side in `build_artifacts/`, named for the link and variant: `top.x4g1.direct.bit`, `top.x4g2.direct.bit`, `top.x1g2.direct.bit`, `top.x1g2.switched.bit`. These four are in git for convenience only: always rebuild from the current RTL. The board-tested pre-v1.0.0 ones are in `build_artifacts/pre-v1.0.0/`.

Everything else a build makes goes to `build_artifacts/work/<build>/`, not in git: `top.json`, `top_routed.json`, `top.fasm`, `top.frames`, the logs, and with sv2v the converted sources. Any build other than the default (another `CPU`, `FRONTEND=sv2v`, `ASSEMBLER=fpga-as` or another `SEED`) keeps its bitstream there too, in a folder named for it (e.g. `x4g1.direct.seed1/`), so it never replaces a committed one.

| Target | Purpose |
|---|---|
| `make convert` | only sv2v conversion + module extraction (`FRONTEND=sv2v`) |
| `make info` | print resolved configuration and tool paths |
| `make clean` | remove this build's `build_artifacts/work/<build>/` and the local copy of `firmware.hex` |
| `make clean-converted` | remove this build's sv2v output |
| `make clean-all` | remove all of `build_artifacts/work/`, the chipdb included; the bitstreams stay |

Each tool is called through a variable (`YOSYS`, `NEXTPNR_XILINX`, `FPGA_AS`, ...) that `set-env.sh` sets. Override one with e.g. `make YOSYS=/path/to/yosys`.

The chipdb is shared by all builds: it depends on the part, not the design. The firmware is: each build makes the one of its `VARIANT` into its work folder.

**Every `make` rebuilds from scratch**; only the chipdb is kept. Switching `LANES`, `GEN` or `CPU` changes only defines and the file list, no file, so a date-based make would keep the old bitstream. And dates on a network share can come from the future. Always rebuilding beats both, and `make clean` is never needed.

The first build generates the chipdb for `xc7a200tfbg484-3` (60 MB, several minutes) and caches it in `build_artifacts/work/chipdb/`. After that, a build takes about 2 minutes.

---

## Constraints

nextpnr's XDC parser takes only `[get_ports]` and `[get_nets]` targets, so the Vivado XDC won't do. `openxc7.x4.xdc` (RC-direct x4, default), `openxc7.x1.xdc` (RC-direct x1) and `openxc7.switched.xdc` (RC-switched, x1) are cut-down versions. The Vivado files (`2.rtl/0.common.opensource/xdc/` plus each variant's GT lane XDC) stay the reference for the AMD flow.

### GT channel

The GT channel `LOC` (x1: `GTPE2_CHANNEL_X0Y5`) is set **indirectly**, through the GT pad pins. In prjxray the `IPAD`, `OPAD` and `GTPE2_CHANNEL` sites share a hard-wired tile. So the pins choose the channel:

```tcl
set_property PACKAGE_PIN C5  [get_ports txn]   ;# MGTPTXN1_216
set_property PACKAGE_PIN D5  [get_ports txp]   ;# MGTPTXP1_216
set_property PACKAGE_PIN C11 [get_ports rxn]   ;# MGTPRXN1_216
set_property PACKAGE_PIN D11 [get_ports rxp]   ;# MGTPRXP1_216
```

Vivado is the other way round. The channel `LOC` decides the pads, and pin constraints alone do not move the lane.

Bank 216, from `prjxray-db/artix7/xc7a200tfbg484-3/package_pins.csv` (the `tile` column names the tile):

| Channel | Vivado LOC | RX pins | TX pins |
|---|---|---|---|
| 0 | `GTPE2_CHANNEL_X0Y4` | A8/B8 | A4/B4 |
| **1** | **`GTPE2_CHANNEL_X0Y5`** | **C11/D11** | **C5/D5** |
| 2 | `GTPE2_CHANNEL_X0Y6` | A10/B10 | A6/B6 |
| 3 | `GTPE2_CHANNEL_X0Y7` | C9/D9 | C7/D7 |

RC-switched uses channel **2** (`openxc7.switched.xdc`), the position its Vivado XDC locks. x4 (`openxc7.x4.xdc`) uses all four: board lanes 0, 1, 2, 3 on channels 2, 0, 1, 3. Channels are numbered as in prjxray. [`2.rtl/README.md`](../../2.rtl/README.md#common-physical-constraints-xdc) lists the same positions by board lane.

After every build, the FASM must contain `GTP_CHANNEL_1_MID_LEFT` at x1 (`GTP_CHANNEL_2_...` for RC-switched), and channels 0-3 at x4. The P&R step prints them:

```bash
grep -oE "GTP_CHANNEL[A-Z0-9_]*_X[0-9]+Y[0-9]+" build_artifacts/work/x4g1.direct/top.fasm | sort -u   # default x4 build
```

**Gotcha:** at `PCIE_LANES=1` the netlist port is `txn`, not `txn[0]`. `[get_ports {txn[0]}]` silently matches nothing. At x4 it is the reverse: `openxc7.x4.xdc` must use `{txn[0]}` ... `{txn[3]}`.

### Clocks

`create_clock` on `[get_nets]` **is** supported (`xilinx/xdc.cc:169`). `create_generated_clock`, `set_false_path` and `set_clock_groups` are not. Nor are they needed for the MMCM: nextpnr derives its outputs from `CLKIN1` and the divide settings, and carries them through `BUFG`. So `user_clk` (62.5 / 125 / 250 MHz) has no `create_clock` of its own.

An **unconstrained** clock gets nextpnr's default target of **12 MHz**. So it is never optimised, and never reported as failing. Three of our four domains were like that. The pipe clock reached 245 MHz against 250 MHz required, and nobody said a word.

The target must be the **exact** net name nextpnr reports (`u_pcie.pipe_clk`), not the RTL hierarchical name. On a miss (`getNetByAlias`), the constraint is dropped **silently** (v1.0.0 now warns). That is why the five `create_clock` lines in regymm/pcie_7x do nothing there. They use Vivado-style `a/b/c` names; the netlist has `a.b.c`.

---

## Shims

Vivado gets these from libraries openXC7 lacks. Here are open stand-ins. The Vivado build does not use them.

| File | Replaces | Evidence it is faithful |
|---|---|---|
| `unimacro_shim.v` | `BRAM_TDP_MACRO` (UNIMACRO) | yields **10 RAMB36E1**, same as Vivado |

## openXC7 compared with Vivado: the entire design

**Scope:** the entire RC-direct design (`RC_opensource`): PCIE stack, GTPs, SOC with the default CPU (eduBOS5 2-stage), x4 build of 2026-10-16, before the user clock scaled with the link: `user_clk` was 62.5 MHz (then named `clk62m5`). The SOC alone, with each of the three CPUs: [eduBOS5 README](../../2.rtl/0.common.opensource/src/CPU.eduBOS5/README.md#cpu-options-compared-the-soc-only).

| | openXC7 v1.0.0 | Vivado 2026.1 |
|---|---|---|
| LUT (incl. LUT-RAM) | 1604 | 1360 |
| LUT-RAM (in the LUT count) | 48 | 44 |
| FF | 2238 | 2183 |
| CARRY4 | 71 | 52 |
| RAMB36E1 / DSP48 | 10 / 0 | 10 / 0 |
| PCIE_2_1 / GTPE2_CHANNEL / GTPE2_COMMON / MMCME2 | 1 / 4 / 1 / 1 | 1 / 4 / 1 / 1 |
| Fmax `user_clk` (CPU, SOC), needs 62.5 MHz in that build | 138.6 MHz | 142.0 MHz |
| Fmax `clk125`, needs 125 MHz | 357.9 MHz | 181.6 MHz |
| Fmax pipe clock, needs 250 MHz | 311.0 MHz | 301.6 MHz |
| Bitstream | 9 730 756 B | 9 730 769 B |

- openXC7: area is Yosys `synth_xilinx` (`stat`), Fmax nextpnr's report. Vivado: area after implementation (`report_utilization`).
- Vivado reports no Fmax. Its figure here is 1 / (period - WNS). Vivado optimises only until each target is met, so it undersells what the design could reach. Compare with care.
- nextpnr's Fmax varies between builds. The same eduBOS5 2-stage SOC gave 158.4 MHz in another build.
- The committed x4 bitstreams are later builds (2026-10-25), assembled with the prjxray pair. `top.x4g1.direct.bit` (x4 Gen1, 2-stage eduBOS5): `user_clk` 157.2 MHz (needs 125), `clk125` 337.0 MHz, pipe clock 283.9 MHz. `top.x4g2.direct.bit` (x4 Gen2, 3-stage eduBOS5): `user_clk` **181.1 MHz, misses 250 MHz** ([nextpnr#110](https://github.com/openXC7/nextpnr/issues/110)), `clk125` 348.6 MHz, pipe clock 285.1 MHz. Neither is tested on hardware yet. The x1 builds pass: pipe clock 285.4 MHz (direct, 2026-10-25), 335.8 MHz (switched, 2026-10-21).
- Both bitstreams were uncompressed, so their size does not depend on the design. The 13 bytes of difference are header metadata. The Vivado build now compresses (`BITSTREAM.GENERAL.COMPRESS` in the common XDC). openXC7's assemblers cannot yet ([lromor/fpga-assembler#59](https://github.com/lromor/fpga-assembler/issues/59)); a smaller bitstream would also be easier to keep in the repo.

## CPU options compared

The SOC CPU is eduBOS5 2-stage (default), `make CPU=edubos5_3stg` or `make CPU=picorv32`. At x4 Gen2 (`make GEN=2`, `user_clk` 250 MHz) the 3-stage is the default. A non-default CPU builds in its own work folder (`build_artifacts/work/x4g1.direct.picorv32/`). nextpnr cannot apply the 3-stage's multicycle paths, so x4 Gen2 reaches 181 MHz here, 250 MHz in Vivado ([nextpnr#110](https://github.com/openXC7/nextpnr/issues/110)). The three compared on the SOC only (Fmax, area, IPC): [eduBOS5 README](../../2.rtl/0.common.opensource/src/CPU.eduBOS5/README.md#cpu-options-compared-the-soc-only).

## Lint and formal equivalence of RTL changes

`run-lint.sh` lints the RTL in phases: Verilator, Yosys `check`, slang (Yosys `read_slang`), Verible, and Vivado `report_cdc` for clock-domain crossings. A phase whose tool is missing is skipped. Usage is in the script header. Reviewed findings are waived inline: on an unused instance output, `.PIN (/*LINT:OK*/)` (flagged on an input). Where no line is ours (generated code), they go in `run-lint-waivers.txt`. Anything not waived fails the script.

`run-format.sh` applies the project style: `begin` ... `end` around every single-statement body, then `verible-verilog-format` with the project flags. `--check` changes nothing and exits 1 on an unformatted file. Rules: [2.rtl/README.md](../../2.rtl/README.md).

`run-leq.sh` proves, with the v1.0.0 Yosys, that two versions of the whole design (`RC_opensource`: PCIE stack, SOC, CPU, CSR) behave the same. We run it on RTL cleanups, before co-sim and the board. Usage is in the script header. Hard macros are black boxes whose pins are compared. Logic that is constant only after reset comes out unproven and needs a human look.

---

## Programming the board from WSL

WSL has no direct USB access. [usbipd-win](https://github.com/dorssel/usbipd-win) passes the JTAG cable through, across the border:

```powershell
winget install usbipd                   # Windows, once
usbipd list                             # find the cable's BUSID
usbipd bind --busid <BUSID>             # once per cable, admin shell
usbipd attach --wsl --busid <BUSID>     # after every replug or reboot
```

In WSL, `lsusb` now lists the cable. Load the bitstream with [openFPGALoader](https://github.com/trabucayre/openFPGALoader) (open source, v1.1.1+; Ubuntu's package is older, so build it from source, see [4.build](../README.md)):

```bash
openFPGALoader --detect                 # cable and FPGA found?
openFPGALoader build_artifacts/top.x4g1.direct.bit
```

Vivado's Hardware Manager works the same way, once its cable drivers are installed (`<Vivado>/data/xicom/cable_drivers/lin64/install_script/install_drivers/install_drivers`, as root). `usbipd detach --busid <BUSID>` hands the cable back to Windows.

---

## Debugging on the board without an ILA

openXC7 has no ILA. Bring-up was saved by a `BSCANE2` shift register, read over JTAG. It is a small module. Vivado reads it with `scan_ir_hw_jtag` / `scan_dr_hw_jtag` while the openXC7 bitstream is loaded.

Three probes sat on separate JTAG user chains. `BSCANE2` connects straight to JTAG, so each probe sits next to its signals. Nothing is routed up the hierarchy.

| Chain | IR | Location | Contents |
|---|---|---|---|
| USER2 | `0x03` | top | `user_lnk_up`, `user_reset`, `cfg_status`, heartbeat |
| USER3 | `0x22` | `pcie_core` | **LTSSM state**, phy link, rate, width |
| USER4 | `0x23` | `gtp_wrapper` | GT reset FSM, PLL0 lock, `resetdone`, TX sync FSM |

The probes are now removed from the RTL. Two lessons for reuse:

- **`(* keep *)` is mandatory** on the `BSCANE2`, the shift register and the probe instance. With no output ports, the module drives nothing. So Yosys silently deletes it, and JTAG reads return garbage.
- **Heartbeat counters on each clock** were the most useful signal. Two ran, a third flatlined at 0. That exposed the dead `IBUFDS_GTE2.O` BUFG, a net that static analysis showed as correctly routed.

The other decisive trick was an **A/B build**: the same RTL and probes, built once with Vivado and once with openXC7, on the same board. It settled at once whether a fault was in the design or the tool. It also killed one assumption: `TXDLYSRESETDONE` reads 0 in the *working* build too. It is a pulse, not a level.

---

## openXC7 findings

Every openXC7 issue this project hit, rechecked on v1.0.0 (nextpnr `3e5c2cdd`). The numbers are stable, so issues and commits can refer to them. Open items are tracked under the [post-release](https://github.com/chili-chips-ba/openPCIE/milestone/1) milestone, each linked to its upstream report. Board checks run once, for all fixes together, after upstream closes every open item.

### Issues we found: Still Open

| # | Finding | Status | openPCIE | Upstream |
|---|---|---|---|---|
| 1 | GT attribute defaults differ from Xilinx's | open | [#17](https://github.com/chili-chips-ba/openPCIE/issues/17) | [nextpnr#21](https://github.com/openXC7/nextpnr/issues/21) |
| 8 | `BEL` attribute on non-IO cells | partly fixed: malformed names give an error, not an abort (main, [nextpnr#123](https://github.com/openXC7/nextpnr/pull/123)); the rest still broken (a) | [#28](https://github.com/chili-chips-ba/openPCIE/issues/28) | [nextpnr#89](https://github.com/openXC7/nextpnr/issues/89) |
| 19 | Yosys: wrong `CLKSWING_CFG` default | new, Slang; still on main | [#19](https://github.com/chili-chips-ba/openPCIE/issues/19) | [yosys#6322](https://github.com/YosysHQ/yosys/issues/6322) |
| 20 | sv-elab: no `real` primitive parameters | new, Slang; blocks `read_slang --target xilinx` on main (`MMCME2_ADV`) | [#20](https://github.com/chili-chips-ba/openPCIE/issues/20) | [sv-elab#282](https://github.com/povik/sv-elab/issues/282) |
| 22 | `read_slang` fails on `xilinx/cells_sim.v` | new, Slang (b); with `--target xilinx` on main, only `FDCE` fails (6 errors) | [#29](https://github.com/chili-chips-ba/openPCIE/issues/29) | [yosys#6323](https://github.com/YosysHQ/yosys/issues/6323), [sv-elab#72](https://github.com/povik/sv-elab/issues/72) |
| 24 | No XPM / UNIMACRO libraries | open; [shims](#shims) stand in | - | - |
| 26 | `set_multicycle_path` cannot reach registers | new (c) | [#36](https://github.com/chili-chips-ba/openPCIE/issues/36) | [nextpnr#110](https://github.com/openXC7/nextpnr/issues/110) |
| 27 | `fpga-as` writes `RXCDR_CFG` wrong on every GTP lane | new (d); the Makefile uses `fasm2frames` + `xc7frames2bit` until the toolchain ships the fix | [#41](https://github.com/chili-chips-ba/openPCIE/issues/41) | [nextpnr#88](https://github.com/openXC7/nextpnr/issues/88), fixed in [fpga-assembler `282ef7c2`](https://github.com/lromor/fpga-assembler/commit/282ef7c2) |

- (a) The old error is gone, but the name nextpnr reports (`SLICE_X162Y177/A5FF`) is rejected, and an accepted one (`X250Y5/SLICE_X0Y0.AFF`) is ignored. Not used by openPCIE.
- (b) 106 errors in `specify` blocks; the reason for `gen_xilinx_bb.py`.
- (c) Only `-to [get_cells -hier -filter {NAME =~ <glob>}]` is read. It matches cell names, which flip-flops lose in synthesis. `-from` drops the whole constraint. So eduBOS5's 3-stage pipeline (`make CPU=edubos5_3stg`) showed no Fmax gain over the 2-stage (2026-10-16, before its jump refetch). Test case, proven safe by formal: [eduBOS5 3-stage multicycle paths](../../2.rtl/0.common.opensource/src/CPU.eduBOS5/README.md#3-stage-multicycle-paths).
- (d) For the 83-bit `RXCDR_CFG` (`83'h0_0001_07FE_4060_0104_1010`), `fpga-as` v1.0.0 keeps bits 0-23, drops 24 and 37-64, and sets 69 and 82. `fasm2frames` writes it exactly. We assembled our x4 FASM both ways: the only difference is `RXCDR_CFG`, in all four lanes. The v1.0.0 installer pins `hansfbaier/fpga-assembler` `cf0e3f08`, which lacks the fix. Upstream is moving toolchain-nix and toolchain-installer to lromor/fpga-assembler `main`.

#### Temp RTL Workarounds / FIXMEs

Each tool workaround in the sources carries a `FIXME` comment (`grep -rn FIXME`). It goes once its issue is fixed:

| Where | Workaround | Issue |
|---|---|---|
| `lane_xcvr.sv` | `TXPI_SYNFREQ_PPM = 3'd1` instead of Xilinx's 0 | [#27](https://github.com/chili-chips-ba/openPCIE/issues/27) |
| `gtp_wrapper.sv` | PLL0 power-up delay clocked from `clk125` instead of `BUFG(PIPE_CLK)` | [#22](https://github.com/chili-chips-ba/openPCIE/issues/22) |
| `gtp_wrapper.sv` | `PLL0_CFG`/`PLL1_CFG`: v1.0.0 ignores them and writes `0x1F03DC`, the value the board-proven bitstream runs on; test the RTL value on hardware once a nextpnr with the fix ships | [#18](https://github.com/chili-chips-ba/openPCIE/issues/18) |
| `Makefile` | `ASSEMBLER=prjxray` by default instead of `fpga-as` | row 27 |
| `clk_rst_gen.sv` | MMCM `real` parameters left out under `SYN_YOSYS_BUG` (slang flow) | [#20](https://github.com/chili-chips-ba/openPCIE/issues/20) |
| `gen_xilinx_bb.py` | whole script (blackbox stubs for slang), plus the `CLKSWING_CFG` fix | [#29](https://github.com/chili-chips-ba/openPCIE/issues/29), [#19](https://github.com/chili-chips-ba/openPCIE/issues/19) |

### Issues we found: Closed

These affected only the pre-v1.0.0 toolchain, which the Makefile no longer uses.

| # | Finding | Note | Tracked |
|---|---|---|---|
| 4 | Router regression after `45a986b` | nextpnr-xilinx only | not needed |
| 5 | Snap lacks `PCIE_2_1` metadata | the snap is gone | not needed |
| 9 | Yosys 0.38 `iopadmap -ignore` hangs | Yosys 0.38 only | not needed |
| 17 | `fasm2frames` KeyError on `IBUFDS_GTE2` | gone: v1.0.0's `fasm2frames` assembles our x4 FASM | [#14](https://github.com/chili-chips-ba/openPCIE/issues/14) (closed) |

#### Fixed upstream, after v1.0.0

| # | Finding | Note | Tracked |
|---|---|---|---|
| 2 | `IBUFDS_GTE2.O` -> `BUFG` dead clock | board check in the final run | [#22](https://github.com/chili-chips-ba/openPCIE/issues/22), [nextpnr-xilinx#100](https://github.com/openXC7/nextpnr-xilinx/issues/100) |
| 3 | `PLL0_CFG`/`PLL1_CFG` hardcoded | now read from the design | [#18](https://github.com/chili-chips-ba/openPCIE/issues/18), [nextpnr#84](https://github.com/openXC7/nextpnr/issues/84) |
| 6 | Unconstrained clock silently timed at 12 MHz | main `5ef14a40`; confirmed on main `46c25a91`: it warns, and `IBUFDS_GTE2` -> `BUFG` derives 100 MHz | [#23](https://github.com/chili-chips-ba/openPCIE/issues/23), [nextpnr#90](https://github.com/openXC7/nextpnr/issues/90) |
| 10 | `--placer sa` placement invalid | confirmed on the fix branch (`fddfed5`), seeds 1 and 3; the default placer still times much better | [#25](https://github.com/chili-chips-ba/openPCIE/issues/25), [nextpnr#92](https://github.com/openXC7/nextpnr/issues/92) |
| 11 | `TXPI_SYNFREQ_PPM` = 0 rejected | upstream: the GT and PCIe tiles now match our Vivado golden; board check in the final run; the `3'd1` workaround stays until then | [#27](https://github.com/chili-chips-ba/openPCIE/issues/27), [nextpnr#88](https://github.com/openXC7/nextpnr/issues/88) |
| 21 | Truncated FASM on error still assembles | main `f9e07df8`; confirmed on main `46c25a91`: on error the old FASM stays, and none is left when there was none; the Makefile also checks nextpnr's exit status | [#26](https://github.com/chili-chips-ba/openPCIE/issues/26), [nextpnr#93](https://github.com/openXC7/nextpnr/issues/93) |
| 23 | Contradicting GT `LOC` accepted silently | main `d3acad91`; confirmed on main `46c25a91` with the openPCIE netlist: it now errors (rc 125) | [#30](https://github.com/chili-chips-ba/openPCIE/issues/30), [nextpnr#94](https://github.com/openXC7/nextpnr/issues/94) |
| 14 | `IBUFDS_GTE2.ODIV2` unusable | main: the pin ([nextpnr-xilinx-meta#7](https://github.com/openXC7/nextpnr-xilinx-meta/pull/7)), the packer ([nextpnr#131](https://github.com/openXC7/nextpnr/pull/131)), the `ODIV2` select bit ([prjxray-db#41](https://github.com/openXC7/prjxray-db/pull/41)); bits match Vivado; artix7 chipdb must be regenerated; board check in the final run | [#24](https://github.com/chili-chips-ba/openPCIE/issues/24), [nextpnr#91](https://github.com/openXC7/nextpnr/issues/91) |
| 18 | Derived-constraint warning swaps its values | main `e313e46f` ([nextpnr#122](https://github.com/openXC7/nextpnr/pull/122)) | [#21](https://github.com/chili-chips-ba/openPCIE/issues/21), [nextpnr#85](https://github.com/openXC7/nextpnr/issues/85) |

#### Fixed in v1.0.0

None of these needed a tracker.

| # | Finding | Note |
|---|---|---|
| 7 | `create_clock` on an unknown net dropped silently | now warns |
| 12 | prjxray `bitread` segfaults on xc7a200t | |
| 13 | SRL32 cascade `Q31` missing | no `-nosrl`: 216 fewer FFs ([more](#-nosrl-at-synthesis)) |
| 15 | `PSEUDO_GND` rejected on unused `GTREFCLK` | |
| 16 | `CARRY4.CIN` ground not routable | no `-nocarry`; 384 carry cells pass timing |
| 25 | No `get_cells` in XDC, so no `LOC` on a hard block | `LOC` now pins `GTPE2_CHANNEL`; pad pins still required |

-----------
#### End-of-Document
