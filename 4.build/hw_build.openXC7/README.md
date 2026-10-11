# opensource openXC7 build flow

Builds the opensource RC into an FPGA bitstream with **open-source tools only**, no Vivado. `make` builds [`RC-direct.opensource`](../../2.rtl/2.RC-direct.opensource); `make VARIANT=switched` builds [`RC-switched.opensource`](../../2.rtl/3.Bonus--RC-switched.opensource). Both come from the same RTL, [`2.rtl/0.common.opensource`](../../2.rtl/0.common.opensource) (top `RC_opensource`), and differ only in their firmware and GT pins (`openxc7.xdc` vs `openxc7.switched.xdc`, see [GT channel](#gt-channel)).

| Stage | Tool | Input -> Output |
|---|---|---|
| 1. SV conversion | `sv2v` | `.sv` -> `.v` |
| 2. Synthesis | `yosys` | `.v` -> `top.json` |
| 3. Place & route | `nextpnr-xilinx` | `.json` + chipdb + `.xdc` -> `top.fasm` |
| 4. FASM -> frames | `fasm2frames` (prjxray) | `.fasm` -> `top.frames` |
| 5. Bitstream | `xc7frames2bit` (prjxray) | `.frames` -> `top.bit` |

Target part is `xc7a200tfbg484-3` (Acorn CLE-215P), same as the Vivado build.

## Status: working on hardware

`make` produces `build_artifacts/top.bit`. On the board it brings the PCIE link **up at Gen2**, checked against a second Artix-7 board acting as endpoint:

```
user_lnk_up = 1
LTSSM       = 0x16
phy_lnk_up  = 1
rate        = Gen2
```

These are the same readings as with the Vivado bitstream built from the same RTL.

It took six fixes to get there: one latent bug in this design's RTL, and five workarounds for openXC7 defects. All are described below.

---

## ⚠ The nextpnr-xilinx version is critical

With the pre-v1.0.0 toolchain, the design builds **only** with nextpnr-xilinx at commit `45a986b` (`v0.8.2-79-g45a986b8`, 2026-04-18).

| Version | Result |
|---|---|
| nextpnr-xilinx 0.8.2 from the snap (Jun 2024 binary) | **too old** - its metadata lacks `site_type_PCIE_2_1.json`, so placement fails with `no Bels remaining of type 'PCIE_2_1'` |
| master `bab26c2` (Jul 2026) | **regression** - `router2` loops forever in `route_xilinx_const` (confirmed in gdb) |
| **`45a986b` (Apr 2026)** | **works** |

Yosys 0.38 from the snap is fine; no newer Yosys is needed.

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

If the tree is not in `/opt/openxc7_extra/npnr_45a986b`, point the Makefile at it with `NEXTPNR_SRC=`.

**Do not mix versions.** `prjxray-db`, the site metadata and `constids.inc` must come from the same tree as the nextpnr binary. Mixed, they give wrong wire indices and failures that look like router bugs. The Makefile takes all four from `$(NEXTPNR_SRC)` for this reason.

---

## Pre-v1.0.0 and new openXC7 toolchain

**This project was built and validated on hardware with the pre-v1.0.0 openXC7 toolchain:**

| Tool | Version used |
|---|---|
| nextpnr | `nextpnr-xilinx` at commit `45a986b` (Apr 2026), built from source as above |
| Yosys | 0.38, from the openXC7 snap |
| Bitstream | prjxray `fasm2frames` + `xc7frames2bit`, from the openXC7 snap |
| SV conversion | `sv2v` |

openXC7 has moved on since: `nextpnr-xilinx` is archived, the `openxc7` snap is no longer published, and the one-line installer is gone. The **new** toolchain is built from source with [`toolchain-sources-builder.sh`](https://github.com/openXC7/toolchain-installer), or installed through Nix or Apio (see that page):

| Tool | New toolchain (openXC7 v1.0.0, as of Sept 2026) |
|---|---|
| nextpnr | [`openXC7/nextpnr`](https://github.com/openXC7/nextpnr), the *himbaechel* Xilinx engine |
| Yosys | v0.69 |
| Bitstream | `fpga-as`, replacing `fasm2frames` + `xc7frames2bit` |

The Makefile supports both: `TOOLCHAIN=old` (the default) and `TOOLCHAIN=new`. **Only the pre-v1.0.0 toolchain is validated on hardware.** With v1.0.0 both variants build and their configuration checks out, but none of its bitstreams has been on the board yet.

To reproduce the validated result, use the pre-v1.0.0 toolchain; `45a986b` can still be fetched from the archived repository (see [Building the right version](#building-the-right-version)). The rest of this page is about the pre-v1.0.0 toolchain unless it says otherwise.

### Building with the new toolchain

**1. Build the toolchain.** On Ubuntu, into a user-owned prefix, so that only the package install needs `sudo`:

```bash
git clone https://github.com/openXC7/toolchain-installer && cd toolchain-installer
INSTALL_PREFIX=$HOME/opt/openxc7 ./toolchain-sources-builder.sh all
```

The script first installs any missing Ubuntu packages (asking for the `sudo` password), then builds Yosys, nextpnr, prjxray and `fpga-as`. That took about 14 minutes here (Ubuntu 24.04 in WSL2, 16 threads).

**2. sv2v**, same as before - see [Prerequisites](#2-sv2v). We used v0.0.13.

**3. Build:**

```bash
source $HOME/opt/openxc7/export.sh
cd 4.build/hw_build.openXC7
make TOOLCHAIN=new check-env
make TOOLCHAIN=new                      # -> build_artifacts.new/top.bit
make TOOLCHAIN=new VARIANT=switched     # -> build_artifacts.switched.new/top.bit
```

The new toolchain has its own `chipdb.new/` (the database format differs) and its own output folders, so it never overwrites the validated `build_artifacts*/top.bit`. Its bitstreams are not kept in git.

**What changed in the flow:** two steps. The chipdb comes from the new engine's `xilinx_gen.py` instead of `bbaexport.py`, and `fpga-as` turns the FASM into a bitstream in one step instead of `fasm2frames` + `xc7frames2bit`. Synthesis and place and route are called as before; the new `nextpnr-xilinx` is a small script that passes the same options on to `nextpnr-himbaechel`.

**What we measured** (RC-direct unless noted):

| | Pre-v1.0.0 toolchain | New toolchain |
|---|---|---|
| Build time, chipdb cached | about 2 min | 2 min 13 s (RC-switched 2 min 21 s), 16 threads |
| First build, incl. chipdb | several minutes | 6 min |
| GT channel, link speed | channel 1, Gen2 | channel 1 (RC-switched: channel 2), Gen2 |
| Flip-flops after synthesis | 1770 (Yosys 0.38, RTL of 2026-08-19) | 1486 + 9 SRLs (Yosys 0.69, no `-nosrl`, RTL of 2026-10-08) - different RTL, not comparable |
| Pipe clock (`clk_oobclk`, 250 MHz) | misses 250 MHz - expected and verified harmless (see [Clocks](#clocks)) | 280 MHz (RC-switched 274 MHz), passes |
| On hardware | **link up at Gen2** | not tested yet |

nextpnr also warns "Overriding derived constraint of 250.0 MHz on net pcie_inst.clk_oobclk with user-specified constraint of 125.0 MHz". This is harmless: the warning prints its two values swapped, and the 250 MHz from `openxc7.xdc` is what gets applied ([#21](https://github.com/chili-chips-ba/openPCIE/issues/21)).

[openXC7 findings](#openxc7-findings) lists which openXC7 defects still apply to v1.0.0. The design-side fixes are in the RTL, so v1.0.0 builds get them too.

## Native SV within Yosys, through Slang

Open-source Yosys has long read only a subset of SystemVerilog. This design uses packages, interfaces with modports and packed structs, which Yosys's own Verilog front end does not take; hence sv2v. Full SystemVerilog in Yosys came only with the commercial Verific front end, sold by YosysHQ in its Tabby CAD Suite.

Since **Yosys 0.67**, open-source Yosys has its own SystemVerilog front end: `read_slang`, built on the [slang](https://github.com/MikePopoloski/slang) compiler through [sv-elab](https://github.com/povik/sv-elab), and included in every Yosys build. With v1.0.0 this design builds without sv2v:

```bash
source $HOME/opt/openxc7/export.sh
make TOOLCHAIN=new FRONTEND=slang                     # -> build_artifacts.slang/top.bit
make TOOLCHAIN=new FRONTEND=slang VARIANT=switched    # -> build_artifacts.switched.slang/top.bit
```

**Our SystemVerilog goes in unchanged.** `read_slang` takes all 34 SystemVerilog files (packages, interfaces, structs, the SystemVerilog picorv32) without a single language error. Synthesis takes about 10 seconds, the whole build 2 min 26 s (2 min 13 s with sv2v).

**The Xilinx primitives needed three workarounds**, for upstream gaps:

| Problem | Workaround |
|---|---|
| Every primitive must be declared with its parameters; Yosys's usual blackboxes carry none ([sv-elab#367](https://github.com/povik/sv-elab/pull/367)), and its `cells_sim.v` does not pass slang's checks ([yosys#6323](https://github.com/YosysHQ/yosys/issues/6323)). | [`gen_xilinx_bb.py`](gen_xilinx_bb.py) writes them for the 8 primitives used, from Yosys's own library; the Makefile runs it. |
| sv-elab cannot pass a `real` parameter to a primitive ([sv-elab#282](https://github.com/povik/sv-elab/issues/282)). | The MMCM's real-valued settings (all defaults) sit behind `` `ifndef SYN_YOSYS_BUG `` in `clk_synth.sv`; this flow defines it. |
| Yosys's default for `IBUFDS_GTE2.CLKSWING_CFG` is `"TRUE"` instead of `2'b11`; nextpnr rejects it ([yosys#6322](https://github.com/YosysHQ/yosys/issues/6322)). | `gen_xilinx_bb.py` writes `2'b11`. |

**Compared with the sv2v build**, the FASM differs only in 9 `GTPE2_CHANNEL` fields our RTL leaves unset: `read_slang` passes Xilinx's defaults, while sv2v leaves them to nextpnr's. So the slang build is the closer one to Vivado. Not tested on hardware yet.

---

## ⚠ nextpnr's GT attribute defaults do not match Xilinx's

**This is why the design did not work on hardware, and it is the most generally useful finding here.**

When an RTL parameter is omitted, Vivado takes its default from the `unisim` model. In the openXC7 flow the parameter is simply missing from the netlist, so nextpnr uses **its own** default, nearly always `0`, without a warning.

Comparing every `GTPE2_CHANNEL` attribute the RTL leaves unset against the `cells_xtra.v` default and the `*_or_default(...)` call in `xilinx/fasm.cc` gives a list of mismatches. The **20** that matter for this design:

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
| `RXBUFRESET_TIME`, `RXCDRFREQRESET_TIME`, `RXCDRPHRESET_TIME`, `RXISCANRESET_TIME`, `RXLPMRESET_TIME` | `5'b00001` / `7'b0001111` | `0` | reset pulse widths |
| `SATA_BURST_SEQ_LEN`, `SATA_BURST_VAL`, `SATA_EIDLE_VAL` | non-zero | `0` | |

Symptom: the GT came up (QPLL locked, every `resetdone` asserted), but TX phase alignment never started. `TXDLYSRESETDONE` never toggled, so the sync FSM sat in `TX_START` and the LTSSM never left `DETECT_QUIET`.

`lane_xcvr.sv` now sets all 20 explicitly, to the **library** values. The Vivado flow is unaffected; these are the values it was already using.

That is why [regymm/pcie_7x](https://github.com/regymm/pcie_7x) works on openXC7 with the same GTP and the same TX-buffer-bypass mode: it sets every attribute explicitly, so nextpnr has nothing to guess.

**Rule of thumb:** with this toolchain, set every hard-block attribute explicitly. Do not rely on library defaults.

---

## Design-side requirements

### `-nosrl` at synthesis

Required with the pre-v1.0.0 toolchain. `wake_timer`'s 96- and 128-bit shift registers otherwise become `SRLC32E` chains, and nextpnr fails on the cascade output:

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

`lane_xcvr.sv` sets `.TXPI_SYNFREQ_PPM(3'd1)`. Without it, nextpnr reads 0 and stops:

```
fasm.cc:3146  if (txpi_synfreq_ppm == 0) log_error("TXPI_SYNFREQ_PPM must not be zero!")
```

Yet 0 is Xilinx's default, and Xilinx's own PCIE IP leaves it there. We set 1 only to get past this check.

> ⚠ **This is a hack, and hacks like it are dangerous.** The value was picked to satisfy the tool, not the silicon, so our RTL departs here from Xilinx's default and from Xilinx's own PCIE IP, in the Vivado build too. It works on our board, but we have not verified what `TXPI_SYNFREQ_PPM = 1` does to the TX phase interpolator. Never change a hard-block attribute just to silence a tool error: fix the tool, or check the value against Xilinx's documentation first. We go back to 0 once nextpnr accepts it ([#27](https://github.com/chili-chips-ba/openPCIE/issues/27), upstream [nextpnr#88](https://github.com/openXC7/nextpnr/issues/88)).

### Unused GT refclk inputs left unconnected

`pll_bank.sv` used to tie seven unused refclk inputs (`GTGREFCLK0/1`, `GTREFCLK1`, `GTEASTREFCLK0/1`, `GTWESTREFCLK0/1`) to `1'd0`. Vivado accepts that common practice, but nextpnr rejects any constant on a refclk input (`pack_gt_xc7.cc:184`), so they are now left unconnected.

### `wake_timer` clocked from `clk_dclk`

`serdes_ctrl.sv` originally had:

```systemverilog
BUFG wake_refclk_bufg (.I (PIPE_CLK), .O (gt_cpllpdrefclk));
```

`PIPE_CLK` is `IBUFDS_GTE2.O`. Vivado routes this reference clock through the clock backbone into a BUFG, and it works. **nextpnr routes the net without an error, but the BUFG output does not toggle on the board.** A JTAG probe showed it: a counter on `gt_cpllpdrefclk` stayed at 0 on every read, while counters on `user_clk` and `clk_pclk` ran normally.

Consequence chain:

```
gt_cpllpdrefclk dead -> wake_timer never finishes counting
                     -> cpllpd and cpllrst stay asserted
                     -> PLL0PD=1, PLL0RESET=1  (QPLL powered down, not mistuned)
                     -> QPLL_lock=0 -> GT reset FSM stuck at ST_PLL_LOCK
                     -> LTSSM stuck in DETECT_QUIET forever
```

So no amount of QPLL *configuration* fixes could help: the PLL was switched off, not misconfigured.

Workaround: `assign gt_cpllpdrefclk = clk_dclk;`, the MMCM's 125 MHz output. It runs even while the QPLL is still down, because the MMCM is fed by `TXOUTCLK`, which follows the reference clock independently of PLL lock. `wake_timer` only times a startup period, so running it at 125 instead of 100 MHz changes that period by 20%, which does no harm.

### `ST_MMCM_LOCK` is a trap for GTP - latent RTL bug

Not an openXC7 issue. In `pll_init_ctrl.sv`:

```systemverilog
wire mmcm_cpll = mmcm_r2 && (&cplllock_r2);
ST_MMCM_LOCK : state_nx = mmcm_cpll ? ST_DRP_NOM_REQ : ST_MMCM_LOCK;
```

GTP has no per-channel CPLL, and `lane_xcvr.sv` ties `GT_CPLLLOCK = 1'b0`, so `mmcm_cpll` is always 0 and the state has **no exit**. The FSM lands there as soon as it sees the QPLL unlocked while out of reset.

The Vivado build escapes only because its wake path locks the QPLL before reset release: a race it happens to win, not a guarantee. Fixed at the source, in `serdes_ctrl.sv`, by feeding the QPLL lock into that input:

```systemverilog
.QRST_CPLLLOCK ({PCIE_LANES{&qpll_qplllock}}),
```

For GTP, "channel PLL locked" *is* the QPLL lock.

All RTL changes were re-validated in Vivado end to end: synthesis, implementation and bitstream, 0 errors, 0 critical warnings, link up at Gen2.

---

## Prerequisites

### 1. openXC7 toolchain

Provides `yosys` and the prjxray tools. This project used the openXC7 snap of the time (Yosys 0.38, prjxray `fasm2frames` / `xc7frames2bit`) with nextpnr `45a986b` built as above; the snap's own nextpnr did not work for this design. The snap and its installer are gone. See [Pre-v1.0.0 and new openXC7 toolchain](#pre-v100-and-new-openxc7-toolchain) for what replaces them, and [Building with the new toolchain](#building-with-the-new-toolchain) for how to use it.

### 2. sv2v

**Required with the pre-v1.0.0 toolchain.** Yosys 0.38 does not understand SystemVerilog packages, interfaces or packed structs, and this design uses all three (`link_pkg`, `stream_if`, `phy_lanes_if`).

With v1.0.0 it is optional: Yosys 0.69's Slang front end reads our sources as they are (see [Native SV within Yosys, through Slang](#native-sv-within-yosys-through-slang)). sv2v is still the more mature path, just no longer a must.

```bash
wget https://github.com/zachjs/sv2v/releases/latest/download/sv2v-Linux.zip
unzip sv2v-Linux.zip && install -Dm755 sv2v-Linux/sv2v /usr/local/bin/sv2v
```

### 3. firmware.hex

`riscv_pcie_soc.sv` loads its RAM with `$readmemh("firmware.hex", ram)`, so sw_build must run first. The Makefile expects `../sw_build/firmware.hex`.

### 4. The generated CSR

By default the SOC uses `soc_csr.sv`, which wraps the register block PeakRDL generates from `../csr_build/csr.rdl`. So two of the sv2v inputs come from `../csr_build/generated-files/`:

```bash
cd ..                     # 4.build/
make -f MakefileCSR       # -> csr_build/generated-files/{csr_pkg,csr}.sv
```

They are checked in, so this is only needed after editing `csr.rdl`.

The register block is chosen once, in [`4.build/config.mk`](../config.mk), and read by this build, the Vivado project and the firmware alike, so hardware and software always agree:

```makefile
CSR ?= peakrdl        # or: legacy
```

With `legacy`, no generated file is needed. To override it for a single build:

```bash
make CSR=legacy
```

That passes `-DSOC_CSR_LEGACY` to sv2v and drops `csr_pkg.sv`, `csr.sv` and `soc_csr.sv` from the file list. The two register blocks are functionally identical, down to the byte offsets, so the same firmware runs on either.

---

## Building

```bash
make check-env         # confirms tools present AND warns if nextpnr is the wrong version
make check-sources     # confirms every RTL file and firmware.hex is present
make                   # full build -> build_artifacts/top.bit
make VARIANT=switched  # full build -> build_artifacts.switched/top.bit
```

| Target | Purpose |
|---|---|
| `make convert` | only sv2v conversion + module extraction |
| `make CSR=legacy` | build the hand-written CSR instead of the PeakRDL one |
| `make TOOLCHAIN=new` | build with the new openXC7 toolchain, into `build_artifacts.new/` - see [Building with the new toolchain](#building-with-the-new-toolchain) |
| `make TOOLCHAIN=new FRONTEND=slang` | the same without sv2v, into `build_artifacts.slang/` - see [Native SV within Yosys, through Slang](#native-sv-within-yosys-through-slang) |
| `make info` | print resolved configuration |
| `make clean` | remove `build_artifacts/` and the local copy of `firmware.hex` |
| `make clean-converted` | remove `converted/` |
| `make clean-all` | all of the above, plus `chipdb/` |

`VARIANT=switched` gets its own `converted.switched/` and `build_artifacts.switched/`, and the clean targets act on those. So the two variants never overwrite each other or pick up each other's stale intermediates. `chipdb/` is shared, since it depends on the part, not the design. `../sw_build/firmware.hex` is **not** separated, so build the matching firmware first (`make VARIANT=switched` in `sw_build/`).

**Every `make` rebuilds the design from scratch**, sv2v to bitstream; only the chipdb is kept. Switching `CSR` changes the **file list** but no file, so a date-based make would keep the previous bitstream. File dates are unreliable anyway: a tree on a network share, or copied off one, can carry timestamps from the future. Always rebuilding avoids both, and no `make clean` is ever needed.

The first build generates the nextpnr chipdb for `xc7a200tfbg484-3` (317 MB, several minutes) and caches it in `chipdb/`. After that, a build takes about 2 minutes.

---

## Constraints

nextpnr's XDC parser accepts only `[get_ports]` and `[get_nets]` targets, so the full Vivado XDC cannot be used. `openxc7.xdc` (RC-direct) and `openxc7.switched.xdc` (RC-switched) are cut-down versions. The Vivado files, `2.rtl/0.common.opensource/xdc/` plus the one-line GT lane XDC in each variant's `xdc/`, remain the reference for the AMD flow.

### GT channel

The constraint that really matters, `LOC GTPE2_CHANNEL_X0Y5` (the channel the Acorn board is wired to), is set **indirectly**, through the package pins of the GT pads. In prjxray the `IPAD`, `OPAD` and `GTPE2_CHANNEL` sites share a tile and are hard-wired, so choosing the pins chooses the channel:

```tcl
set_property PACKAGE_PIN C5  [get_ports TXN]   ;# MGTPTXN1_216
set_property PACKAGE_PIN D5  [get_ports TXP]   ;# MGTPTXP1_216
set_property PACKAGE_PIN C11 [get_ports RXN]   ;# MGTPRXN1_216
set_property PACKAGE_PIN D11 [get_ports RXP]   ;# MGTPRXP1_216
```

This works here but **not** in Vivado, where it is the other way round: `LOC` on the channel decides the pads, and pin constraints alone do not move the lane.

Channel map for bank 216, from `prjxray-db/artix7/xc7a200tfbg484-3/package_pins.csv` (the `tile` column names the tile directly):

| Channel | Vivado LOC | RX pins | TX pins |
|---|---|---|---|
| 0 | `GTPE2_CHANNEL_X0Y4` | A8/B8 | A4/B4 |
| **1** | **`GTPE2_CHANNEL_X0Y5`** | **C11/D11** | **C5/D5** |
| 2 | `GTPE2_CHANNEL_X0Y6` | A10/B10 | A6/B6 |
| 3 | `GTPE2_CHANNEL_X0Y7` | C9/D9 | C7/D7 |

RC-switched uses channel **2** (`GTPE2_CHANNEL_X0Y6`, pins A10/B10 and A6/B6, in `openxc7.switched.xdc`), the same position its Vivado XDC locks. This table numbers channels as prjxray does; [`2.rtl/README.md`](../../2.rtl/README.md#common-physical-constraints-xdc) lists the same four positions by board lane.

Check after every build that the FASM contains `GTP_CHANNEL_1_MID_LEFT` (`GTP_CHANNEL_2_...` for RC-switched). The P&R step prints this for you:

```bash
grep -oE "GTP_CHANNEL[A-Z0-9_]*_X[0-9]+Y[0-9]+" build_artifacts/top.fasm | sort -u
```

**Gotcha:** at `PCIE_LANES=1` the netlist port is plain `TXN`, not `TXN[0]`. A constraint written as `[get_ports {TXN[0]}]` silently matches nothing.

### Clocks

`create_clock` on `[get_nets]` **is** supported (`xilinx/xdc.cc:169`). `create_generated_clock`, `set_false_path` and `set_clock_groups` are not.

This matters: an **unconstrained** clock gets nextpnr's default target of **12 MHz**, so that domain is never optimised and never reported as failing. Three of the four domains here were like that, and the pipe clock came out at 245 MHz against a 250 MHz requirement, without a word.

The target must be the **exact** net name nextpnr prints in its report (`pcie_inst.clk_oobclk`), not the RTL hierarchical name. Matching uses `getNetByAlias`, and on a miss the constraint is dropped **silently** (v1.0.0 now warns). That is why the five `create_clock` lines in regymm/pcie_7x do nothing there: they use Vivado-style `a/b/c` names, while the netlist has `a.b.c`.

---

## Shims

Vivado supplies these from its own libraries, which openXC7 lacks. Open replacements live here and do not affect the Vivado build:

| File | Replaces | Evidence it is faithful |
|---|---|---|
| `xpm_shim.v` | `xpm_cdc_single` (XPM) | 2-FF synchroniser, `ASYNC_REG` preserved |
| `unimacro_shim.v` | `BRAM_TDP_MACRO` (UNIMACRO) | yields **10 RAMB36E1**, same as Vivado |

## Synthesis compared with Vivado

| | Vivado | Yosys |
|---|---|---|
| RAMB36E1 | 10 | 10 |
| PCIE_2_1 / GTPE2_CHANNEL / GTPE2_COMMON | 1 / 1 / 1 | 1 / 1 / 1 |
| Registers | 1663 | 1491 |
| LUTs | 1675 | ~1586 |

Taken in July 2026, on the RTL of that time. The RTL has grown since, so these do not match the later counts in [Building with the new toolchain](#building-with-the-new-toolchain).

Bitstream size: Vivado 9 730 769 B, openXC7 9 730 777 B. The difference is header metadata.

---

## Debugging on the board without an ILA

openXC7 has no ILA, so the board is otherwise a black box. What made this bring-up possible was a `BSCANE2` shift register read over JTAG: a small module that Vivado can read with `scan_ir_hw_jtag` / `scan_dr_hw_jtag` while the openXC7 bitstream is loaded.

Three probes sat on separate JTAG user chains. `BSCANE2` connects straight to JTAG, so each probe can sit where its signals already are, and nothing has to be routed up the hierarchy.

| Chain | IR | Location | Contents |
|---|---|---|---|
| USER2 | `0x03` | top | `user_lnk_up`, `user_reset`, `cfg_status`, heartbeat |
| USER3 | `0x22` | `silicon_core` | **LTSSM state**, phy link, rate, width |
| USER4 | `0x23` | `serdes_ctrl` | GT reset FSM, QPLL lock, `resetdone`, TX sync FSM |

The probes have since been removed from the RTL. Two lessons for whoever needs them again:

- **`(* keep *)` is mandatory** on the `BSCANE2`, the shift register and the probe instance. The module has no output ports, so to synthesis it drives nothing, and Yosys silently deletes it. The bitstream then has no probe, and JTAG reads return garbage.
- **Heartbeat counters on each clock** were the most useful signal. Two counters running while a third stayed at 0 is what exposed the dead `IBUFDS_GTE2.O` BUFG, a net that static analysis showed as correctly routed.

The other decisive technique was an **A/B build**: the same RTL with the same probes, built once with Vivado and once with openXC7, loaded onto the same board. That settled at once whether a fault was in the design or in the tool. It also corrected one wrong assumption: `TXDLYSRESETDONE` reads 0 in the *working* build too, because it is a pulse, not a level.

---

## openXC7 findings

Every openXC7 issue this project ran into, rechecked on v1.0.0 (nextpnr `3e5c2cdd`). The numbers are stable, so issues and commits can refer to them. Open items are tracked in this repository under the [post-release](https://github.com/chili-chips-ba/openPCIE/milestone/1) milestone, each linked to its upstream report.

### Open Issues (as of Oct. 10, 2026) we found

| # | Finding | Status | Tracked (openPCIE, upstream) |
|---|---|---|---|
| 1 | GT attribute defaults differ from Xilinx's | still present | [#17](https://github.com/chili-chips-ba/openPCIE/issues/17), upstream [nextpnr#21](https://github.com/openXC7/nextpnr/issues/21) |
| 2 | `IBUFDS_GTE2.O` -> `BUFG` dead clock | fixed upstream; hardware check pending | [#22](https://github.com/chili-chips-ba/openPCIE/issues/22), upstream [nextpnr-xilinx#100](https://github.com/openXC7/nextpnr-xilinx/issues/100) |
| 3 | `PLL0_CFG`/`PLL1_CFG` hardcoded | still present | [#18](https://github.com/chili-chips-ba/openPCIE/issues/18), upstream [nextpnr#84](https://github.com/openXC7/nextpnr/issues/84) |
| 6 | Unconstrained clock silently timed at 12 MHz | still present; also no constraint derived through `IBUFDS_GTE2` | [#23](https://github.com/chili-chips-ba/openPCIE/issues/23), upstream [nextpnr#90](https://github.com/openXC7/nextpnr/issues/90) |
| 8 | `BEL` attribute on non-IO cells rejected | that error is gone, but `BEL` is still broken: the name nextpnr reports (`SLICE_X162Y177/A5FF`) is rejected, an accepted one (`X250Y5/SLICE_X0Y0.AFF`) is ignored, and a malformed one aborts nextpnr. Not used by openPCIE | [#28](https://github.com/chili-chips-ba/openPCIE/issues/28), upstream [nextpnr#89](https://github.com/openXC7/nextpnr/issues/89) |
| 10 | `--placer sa` placement invalid | still present on our design ("post-placement validity check failed"); the default placer is not affected | [#25](https://github.com/chili-chips-ba/openPCIE/issues/25), upstream [nextpnr#92](https://github.com/openXC7/nextpnr/issues/92) |
| 11 | `TXPI_SYNFREQ_PPM` = 0 rejected | still present; 0 is Xilinx's default and what Xilinx's PCIE IP uses | [#27](https://github.com/chili-chips-ba/openPCIE/issues/27), upstream [nextpnr#88](https://github.com/openXC7/nextpnr/issues/88) |
| 14 | `IBUFDS_GTE2.ODIV2` unusable | still present | [#24](https://github.com/chili-chips-ba/openPCIE/issues/24), upstream [nextpnr#91](https://github.com/openXC7/nextpnr/issues/91) |
| 18 | "Overriding derived constraint" warning prints its values swapped | new in v1.0.0 | [#21](https://github.com/chili-chips-ba/openPCIE/issues/21), upstream [nextpnr#85](https://github.com/openXC7/nextpnr/issues/85) |
| 19 | Yosys: wrong `IBUFDS_GTE2.CLKSWING_CFG` default | new, Slang front end | [#19](https://github.com/chili-chips-ba/openPCIE/issues/19), upstream [yosys#6322](https://github.com/YosysHQ/yosys/issues/6322) |
| 20 | sv-elab: no `real` primitive parameters | new, Slang front end | [#20](https://github.com/chili-chips-ba/openPCIE/issues/20), upstream [sv-elab#282](https://github.com/povik/sv-elab/issues/282) |
| 21 | nextpnr leaves a truncated FASM on error, which `fpga-as` still assembles | new; the Makefile checks nextpnr's exit status | [#26](https://github.com/chili-chips-ba/openPCIE/issues/26), upstream [nextpnr#93](https://github.com/openXC7/nextpnr/issues/93) |
| 22 | Yosys: `read_slang` cannot read Yosys's own `xilinx/cells_sim.v` (106 errors in `specify` blocks) | new, Slang front end; the reason for `gen_xilinx_bb.py` | [#29](https://github.com/chili-chips-ba/openPCIE/issues/29), upstream [yosys#6323](https://github.com/YosysHQ/yosys/issues/6323), [sv-elab#72](https://github.com/povik/sv-elab/issues/72) |
| 23 | `LOC` on a `GTPE2_CHANNEL` that contradicts its pad pins is accepted silently | new: `LOC GTPE2_CHANNEL_X0Y6` with channel-1 pins builds with channel 2 | [#30](https://github.com/chili-chips-ba/openPCIE/issues/30), upstream [nextpnr#94](https://github.com/openXC7/nextpnr/issues/94) |
| 24 | No XPM / UNIMACRO libraries | still absent in v1.0.0; [shims](#shims) stand in | not needed |

#### Temp RTL Workarounds / FIXMEs

Each tool workaround still in the sources carries a `FIXME` comment (`grep -rn FIXME`). The plan is to remove it once the original issue is fixed:

| Where | Workaround | Issue |
|---|---|---|
| `lane_xcvr.sv` | `TXPI_SYNFREQ_PPM = 3'd1` instead of Xilinx's 0 | [#27](https://github.com/chili-chips-ba/openPCIE/issues/27) |
| `serdes_ctrl.sv` | `wake_timer` clocked from `clk_dclk` instead of `BUFG(PIPE_CLK)` | [#22](https://github.com/chili-chips-ba/openPCIE/issues/22) |
| `pll_bank.sv` | none, but nextpnr ignores `PLL0_CFG`/`PLL1_CFG` here | [#18](https://github.com/chili-chips-ba/openPCIE/issues/18) |
| `clk_synth.sv` | MMCM `real` parameters left out under `SYN_YOSYS_BUG` (slang flow) | [#20](https://github.com/chili-chips-ba/openPCIE/issues/20) |
| `gen_xilinx_bb.py` | whole script (blackbox stubs for slang), plus the `CLKSWING_CFG` fix | [#29](https://github.com/chili-chips-ba/openPCIE/issues/29), [#19](https://github.com/chili-chips-ba/openPCIE/issues/19) |

### Issues we found in the pre-v1.0.0 openXC7

These affect only the pre-v1.0.0 tool chain; The v1.0.0 no longer suffers from them.

| # | Finding | Note | Tracked |
|---|---|---|---|
| 4 | Router regression after `45a986b` | nextpnr-xilinx only | not needed |
| 5 | Snap lacks `PCIE_2_1` metadata | the snap is gone | not needed |
| 9 | Yosys 0.38 `iopadmap -ignore` hangs | Yosys 0.38 only | not needed |
| 17 | `fasm2frames` KeyError on `IBUFDS_GTE2` | v1.0.0 uses `fpga-as` | [#14](https://github.com/chili-chips-ba/openPCIE/issues/14) (closed) |

#### Fixed in v1.0.0

| # | Finding | Note | Tracked |
|---|---|---|---|
| 7 | `create_clock` on an unknown net dropped silently | now warns | not needed |
| 12 | prjxray `bitread` segfaults on xc7a200t | | not needed |
| 13 | SRL32 cascade `Q31` missing | `TOOLCHAIN=new` builds without `-nosrl`: 216 fewer flip-flops, see [`-nosrl` at synthesis](#-nosrl-at-synthesis) | not needed |
| 15 | `PSEUDO_GND` rejected on unused `GTREFCLK` | | not needed |
| 16 | `CARRY4.CIN` ground not routable | no `-nocarry`; 384 carry cells pack and pass timing | not needed |
| 25 | XDC had no `get_cells`, so no `LOC` on a hard block | `set_property LOC ... [get_cells ...]` now pins `GTPE2_CHANNEL`; the pad pins are still required | not needed |

-----------
#### End-of-Document
