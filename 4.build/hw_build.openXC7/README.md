# opensource openXC7 build flow

Builds the opensource RC into an FPGA bitstream using **only open-source tools** -
no Vivado anywhere in the chain. `make` builds
[`RC-direct.opensource`](../../2.rtl/2.RC-direct.opensource);
`make VARIANT=switched` builds
[`RC-switched.opensource`](../../2.rtl/3.Bonus--RC-switched.opensource) instead.
Everything below applies to both - the two differ by one `assign` in
`riscv_pcie_soc.sv` and by the firmware they carry, and not at all in the
toolchain or the constraints.

| Stage | Tool | Input -> Output |
|---|---|---|
| 1. SV conversion | `sv2v` | `.sv` -> `.v` |
| 2. Synthesis | `yosys` | `.v` -> `top.json` |
| 3. Place & route | `nextpnr-xilinx` | `.json` + chipdb + `.xdc` -> `top.fasm` |
| 4. FASM -> frames | `fasm2frames` (prjxray) | `.fasm` -> `top.frames` |
| 5. Bitstream | `xc7frames2bit` (prjxray) | `.frames` -> `top.bit` |

Target part is `xc7a200tfbg484-3` (Acorn CLE-215P), same as the Vivado build.

## Status: working on hardware

`make` produces `build_artifacts/top.bit`, and on the board it brings the PCIe
link **up at Gen2**, verified against a second Artix-7 board acting as endpoint:

```
user_lnk_up = 1
LTSSM       = 0x16
phy_lnk_up  = 1
rate        = Gen2
```

The same readings as the Vivado bitstream built from identical RTL.

Getting there required four fixes. One is a genuine latent bug in this design's
RTL; three are workarounds for openXC7 defects. All are documented below.

---

## ⚠ The nextpnr-xilinx version is critical

This is the single most important thing on this page. The design builds **only**
with nextpnr-xilinx around commit `45a986b` (`v0.8.2-79-g45a986b8`, 2026-04-18).

| Version | Result |
|---|---|
| snap 0.8.2 (Jun 2024 binary) | **too old** - ships metadata without `site_type_PCIE_2_1.json`, so the `PCIE_2_1` site gets 0 BELs and placement fails with `no Bels remaining of type 'PCIE_2_1'` |
| master `bab26c2` (Jul 2026) | **regression** - `router2` enters an infinite loop in `route_xilinx_const` (gdb-confirmed) |
| **`45a986b` (Apr 2026)** | **works** |

Yosys 0.38 from the snap is fine - a newer Yosys is *not* required.

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

Point the Makefile at that tree with `NPNR_SRC=` if it is not in
`/opt/openxc7_extra/npnr_45a986b`.

**Do not mix versions.** `prjxray-db`, the site metadata and `constids.inc` must
all come from the same tree as the nextpnr binary - mixing them yields wrong wire
indices and failures that look like router bugs. The Makefile takes all four from
`$(NPNR_SRC)` for exactly this reason.

---

## ⚠ nextpnr's GT attribute defaults do not match Xilinx's

**This was the root cause of the design not working on hardware, and it is the
most generally useful finding here.**

When an RTL parameter is omitted, Vivado fills it in from the `unisim` model. In
the openXC7 flow the parameter simply does not exist in the netlist, so nextpnr
substitutes **its own** default - almost always `0`. Silently, with no warning.

Comparing every `GTPE2_CHANNEL` attribute the RTL does not set, against the
`cells_xtra.v` library default and the `*_or_default(...)` call in
`xilinx/fasm.cc`, gives **17 mismatches**. The damaging ones:

| Attribute | Xilinx library | nextpnr | Consequence |
|---|---|---|---|
| `TX_CLKMUX_EN` | `1'b1` | `0` | **GT-internal TX clock mux off** |
| `RX_CLKMUX_EN` | `1'b1` | `0` | **GT-internal RX clock mux off** |
| `PMA_RSV` | `32'h00000333` | `0` | TX PMA analog config wrecked |
| `TXPI_PPMCLK_SEL` | `"TXUSRCLK2"` | `"TXUSRCLK"` | wrong TX phase-interpolator clock |
| `PD_TRANS_TIME_FROM_P2` | `12'h03C` | `0` | PCIe P-state transition timing |
| `PD_TRANS_TIME_TO_P2` | `8'h64` | `0` | same |
| `OUTREFCLK_SEL_INV` | `2'b11` | `0` | |
| `TRANS_TIME_RATE` | `8'h0E` | `0` | |
| `RXOOB_CFG` | `7'b0000110` | `0` | OOB detection |
| `RXLPM_HF_CFG` / `RXLPM_LF_CFG` | non-zero | `0` | RX equaliser |
| `RXBUFRESET_TIME`, `RXCDRFREQRESET_TIME`, `RXCDRPHRESET_TIME`, `RXISCANRESET_TIME`, `RXLPMRESET_TIME` | `5'b00001` / `7'b0001111` | `0` | reset pulse widths |
| `SATA_BURST_SEQ_LEN`, `SATA_BURST_VAL`, `SATA_EIDLE_VAL` | non-zero | `0` | |

Symptom: the GT came up (QPLL locked, all `resetdone` asserted) but TX phase
alignment never started - `TXDLYSRESETDONE` never produced an edge, so the sync
FSM sat in `TX_START` forever and the LTSSM never left `DETECT_QUIET`.

`lane_xcvr.sv` now sets all 17 explicitly, to the **library** values. The Vivado
flow is unaffected - the numbers are what Vivado was already using.

This is why [regymm/pcie_7x](https://github.com/regymm/pcie_7x) works on openXC7
with the same GTP and the same TX-buffer-bypass mode: that design sets every
attribute explicitly, so nextpnr has nothing to guess.

**Generalisation:** on this toolchain, do not rely on library defaults for any
hard-block attribute. Set them explicitly.

---

## Design-side requirements

### `-nosrl` at synthesis

The only Yosys flag required. `wake_timer`'s 96- and 128-bit shift registers
otherwise become `SRLC32E` chains, and nextpnr fails on the cascade output:

```
ERROR: No wire found for port Q31 on source cell ... fpga_srl_0
```

Without SRLs they are plain flip-flops - 224 extra FFs on a device with 269200.

*(`-nocarry` and `--router router1` were needed only to work around the broken
master nextpnr. With `45a986b` neither is necessary.)*

### `TXPI_SYNFREQ_PPM` must be non-zero

`lane_xcvr.sv` sets `.TXPI_SYNFREQ_PPM(3'd1)`. nextpnr reads it with a default of
0 and refuses to continue:

```
fasm.cc:3146  if (txpi_synfreq_ppm == 0) log_error("TXPI_SYNFREQ_PPM must not be zero!")
```

The same class of problem as the 17 defaults above, but this one at least fails
loudly.

### Unused GT refclk inputs left unconnected

`pll_bank.sv` used to tie seven unused refclk inputs (`GTGREFCLK0/1`,
`GTREFCLK1`, `GTEASTREFCLK0/1`, `GTWESTREFCLK0/1`) to `1'd0`. That is ordinary
practice and Vivado accepts it, but nextpnr rejects any constant on a refclk input
(`pack_gt_xc7.cc:184`). They are now left unconnected.

### `wake_timer` clocked from `clk_dclk`

`serdes_ctrl.sv` originally had:

```systemverilog
BUFG wake_refclk_bufg (.I (PIPE_CLK), .O (gt_cpllpdrefclk));
```

`PIPE_CLK` is `IBUFDS_GTE2.O`. Vivado routes that reference clock through the
clock backbone into a BUFG and it works. **nextpnr routes the net without a single
error, but the BUFG output does not toggle on the board.** Measured with a JTAG
probe: a counter on `gt_cpllpdrefclk` stayed at 0 across every read while
counters on `user_clk` and `clk_pclk` incremented normally.

Consequence chain:

```
gt_cpllpdrefclk dead -> wake_timer never finishes counting
                     -> cpllpd and cpllrst stay asserted
                     -> PLL0PD=1, PLL0RESET=1  (QPLL powered down, not mistuned)
                     -> QPLL_lock=0 -> GT reset FSM stuck at ST_PLL_LOCK
                     -> LTSSM stuck in DETECT_QUIET forever
```

This is why no amount of QPLL *configuration* fixing helped - the PLL was switched
off, not misconfigured.

Workaround: `assign gt_cpllpdrefclk = clk_dclk;` - the MMCM's 125 MHz output,
which runs even while the QPLL is still down (the MMCM is fed by `TXOUTCLK`, which
follows the reference clock path independently of PLL lock). `wake_timer` only
counts out a startup period, so 125 MHz instead of 100 MHz changes its duration by
20%, which is harmless.

### `ST_MMCM_LOCK` is a trap for GTP - latent RTL bug

Not an openXC7 issue. In `pll_init_ctrl.sv`:

```systemverilog
wire mmcm_cpll = mmcm_r2 && (&cplllock_r2);
ST_MMCM_LOCK : state_nx = mmcm_cpll ? ST_DRP_NOM_REQ : ST_MMCM_LOCK;
```

GTP has no per-channel CPLL, and `lane_xcvr.sv` hard-ties `GT_CPLLLOCK = 1'b0`,
so `mmcm_cpll` is permanently 0 and the state has **no exit**. The FSM enters it
the moment it ever sees the QPLL unlocked while out of reset.

The Vivado build escapes only because its wake path locks the QPLL before reset
release - a race it happens to win, not a guarantee. Fixed at the source, in
`serdes_ctrl.sv`, by feeding the QPLL lock into that input:

```systemverilog
.QRST_CPLLLOCK ({PCIE_LANES{&qpll_qplllock}}),
```

For GTP, "channel PLL locked" *is* the QPLL lock.

All RTL changes were re-validated in Vivado end-to-end - synthesis,
implementation and bitstream, 0 errors, 0 critical warnings, link up at Gen2.

---

## Prerequisites

### 1. openXC7 toolchain

Provides `yosys` and the prjxray tools. On Ubuntu 22.04:

```bash
wget -qO - https://raw.githubusercontent.com/openXC7/toolchain-installer/main/toolchain-installer.sh | bash
```

Then build nextpnr `45a986b` as above - the snap's nextpnr is not usable for this
design.

### 2. sv2v

**Not optional.** Yosys does not understand SystemVerilog packages, interfaces or
packed structs, and this design uses all three (`link_pkg`, `stream_if`,
`phy_lanes_if`).

```bash
wget https://github.com/zachjs/sv2v/releases/latest/download/sv2v-Linux.zip
unzip sv2v-Linux.zip && install -Dm755 sv2v-Linux/sv2v /usr/local/bin/sv2v
```

### 3. firmware.hex

`riscv_pcie_soc.sv` initialises its RAM with `$readmemh("firmware.hex", ram)`, so
the sw_build stage must have run first. The Makefile expects
`../sw_build/firmware.hex`.

### 4. The generated CSR

By default the SOC instantiates `soc_csr.sv`, which wraps the register block
PeakRDL generates from `../csr_build/csr.rdl`. Two of the files that go into
sv2v therefore come out of `../csr_build/generated-files/`:

```bash
cd ..                     # 4.build/
make -f MakefileCSR       # -> csr_build/generated-files/{csr_pkg,csr}.sv
```

They are checked in, so this is only needed after editing `csr.rdl`.

Which register block gets built is set once, in
[`4.build/config.mk`](../config.mk), and read by this build, the Vivado project
and the firmware alike, so hardware and software are never built different ways:

```makefile
CSR ?= peakrdl        # or: legacy
```

With `legacy` no generated file is needed at all. To override the file for a
single build:

```bash
make CSR=legacy
```

That passes `-DSOC_CSR_LEGACY` to sv2v and drops `csr_pkg.sv`, `csr.sv` and
`soc_csr.sv` from the file list. The two register blocks are functionally
identical, down to the byte offsets, so the same firmware runs on either.

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
| `make info` | print resolved configuration |
| `make clean` | remove `build_artifacts/` |
| `make clean-all` | also remove `converted/` and `chipdb/` |

`VARIANT=switched` gives the switched build its own `converted.switched/` and
`build_artifacts.switched/`, so the two never overwrite each other and neither
picks up the other one's stale intermediates. The `chipdb/` is shared - it
depends on the part, not on the design. What is **not** separated is
`../sw_build/firmware.hex`, so build the matching firmware first
(`make VARIANT=switched` over in `sw_build/`).

Switching `CSR` is different: it changes only the **file list**, not any file,
so make on its own would see unchanged sources, decide the conversion is up to
date and leave the previous bitstream in place. The configuration is therefore
recorded in `.build-config`, which is a prerequisite of the sv2v step along with
`../config.mk` - so a change to either rebuilds by itself, with no `make clean`
needed.

The first build generates the nextpnr chipdb for `xc7a200tfbg484-3` (317 MB,
several minutes). It is cached in `chipdb/`.

Build time with a cached chipdb is about 2 minutes.

---

## Constraints

nextpnr's XDC parser accepts only `[get_ports]` and `[get_nets]` targets, so the
full Vivado XDC cannot be used. `openxc7.xdc` is a reduced version; the Vivado file
in `2.rtl/` remains the source of truth for the AMD flow.

### GT channel

The constraint that genuinely matters - `LOC GTPE2_CHANNEL_X0Y5`, pinning the
transceiver to the channel the Acorn board is wired to - is recovered
**indirectly**, by constraining the GT pads by package pin. In prjxray the
`IPAD`, `OPAD` and `GTPE2_CHANNEL` sites live in the *same tile* and are
hard-wired, so choosing the pins chooses the channel:

```tcl
set_property PACKAGE_PIN C5  [get_ports TXN]   ;# MGTPTXN1_216
set_property PACKAGE_PIN D5  [get_ports TXP]   ;# MGTPTXP1_216
set_property PACKAGE_PIN C11 [get_ports RXN]   ;# MGTPRXN1_216
set_property PACKAGE_PIN D11 [get_ports RXP]   ;# MGTPRXP1_216
```

This works here but **not** in Vivado, where the relationship is reversed: `LOC`
on the channel determines the pads, so constraining pins alone does not move the
lane.

Channel map for bank 216, from
`prjxray-db/artix7/xc7a200tfbg484-3/package_pins.csv` (the `tile` column states
the tile directly):

| Channel | Vivado LOC | RX pins | TX pins |
|---|---|---|---|
| 0 | `GTPE2_CHANNEL_X0Y4` | A8/B8 | A4/B4 |
| **1** | **`GTPE2_CHANNEL_X0Y5`** | **C11/D11** | **C5/D5** |
| 2 | `GTPE2_CHANNEL_X0Y6` | A10/B10 | A6/B6 |
| 3 | `GTPE2_CHANNEL_X0Y7` | C9/D9 | C7/D7 |

Verify after every build - the FASM must contain `GTP_CHANNEL_1_MID_LEFT`:

```bash
grep -oE "GTP_CHANNEL[A-Z0-9_]*_X[0-9]+Y[0-9]+" build_artifacts/top.fasm | sort -u
```

The P&R step prints this automatically.

**Gotcha:** at `PCIE_LANES=1` the netlist port is plain `TXN`, not `TXN[0]`. A
constraint written as `[get_ports {TXN[0]}]` matches nothing, silently.

### Clocks

`create_clock` via `[get_nets]` **is** supported (`xilinx/xdc.cc:169`). Only
`create_generated_clock`, `set_false_path` and `set_clock_groups` are not.

This matters: an **unconstrained** clock gets nextpnr's default target of
**12 MHz**, so the placer and router never optimise that domain and no failure is
ever reported. Three of the four domains here were in that state, and the pipe
clock was coming out at 245 MHz against a 250 MHz requirement - silently short.

The target must be the **exact** net name nextpnr prints in its report
(`pcie_inst.clk_oobclk`), not the RTL hierarchical name. Matching is
`getNetByAlias`; on a miss the constraint is dropped **silently**. This is why the
five `create_clock` lines in regymm/pcie_7x have no effect there - they use
Vivado-style `a/b/c` names while the netlist has `a.b.c`.

---

## Shims

Vivado supplies these from its own libraries; openXC7 has neither. Open
replacements live here and do not affect the Vivado build:

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

Bitstream size: Vivado 9 730 769 B, openXC7 9 730 777 B - the difference is header
metadata.

---

## Debugging on the board without an ILA

openXC7 has no ILA, so the board is otherwise a black box. What made this bring-up
possible was a `BSCANE2` shift register read over JTAG - a small module that
Vivado can read with `scan_ir_hw_jtag` / `scan_dr_hw_jtag` while the openXC7
bitstream is loaded.

Three probes were used, on separate JTAG user chains, so no signals had to be
routed up the hierarchy: `BSCANE2` connects straight to JTAG, so a probe can sit
wherever the signals already are.

| Chain | IR | Location | Contents |
|---|---|---|---|
| USER2 | `0x03` | top | `user_lnk_up`, `user_reset`, `cfg_status`, heartbeat |
| USER3 | `0x22` | `silicon_core` | **LTSSM state**, phy link, rate, width |
| USER4 | `0x23` | `serdes_ctrl` | GT reset FSM, QPLL lock, `resetdone`, TX sync FSM |

The probes have been removed from the RTL now that the work is done. Two things
are worth recording for whoever needs them again:

- **`(* keep *)` is mandatory** on the `BSCANE2`, the shift register and the probe
  instance. The module has no output ports, so from synthesis' point of view it
  drives nothing and yosys deletes the whole thing - silently, leaving a bitstream
  where the probe simply is not there and JTAG reads return garbage.
- **Heartbeat counters on each clock** were the single most useful signal. Seeing
  two counters increment while a third stayed at 0 is what exposed the dead
  `IBUFDS_GTE2.O` BUFG. Static analysis had shown that net as correctly routed.

The other decisive technique was an **A/B build**: the same RTL with the same
probes, built once with Vivado and once with openXC7, programmed onto the same
board. That immediately settled whether a fault was in the design or in the tool,
and it corrected one wrong assumption - `TXDLYSRESETDONE` reads 0 in the *working*
build too, because it is a pulse, not a level.

---

## Issues worth filing against openXC7

| # | Finding |
|---|---|
| 1 | **GT attribute defaults do not match the Xilinx library** - **80 mismatches** on `GTPE2_CHANNEL`, `TX_CLKMUX_EN`/`RX_CLKMUX_EN`/`PMA_RSV`/`RX_XCLK_SEL` among them (17 of those affected this design). Any design relying on library defaults gets a silently broken transceiver |
| 2 | **`IBUFDS_GTE2.O` -> `BUFG` yields a dead clock in fabric.** The net routes without error and the FASM looks correct, but the BUFG output does not toggle on hardware |
| 3 | **`fasm.cc:2118` hardcodes `PLL0_CFG`/`PLL1_CFG`** to `0x1F03DC` instead of reading the cell parameter (this design asks for `0x1F024C`), and writes only bits [20:0] of a 27-bit attribute |
| 4 | **Regression between `45a986b` and `bab26c2`** - master cannot route `CARRY4_Ox` -> `xFFMUX_OUT` inside a slice, so any design with a counter fails; reproduced with a 4-line testcase. `common/router2.cc` is byte-identical between the two commits, so the change is in the xilinx packing code. On larger designs the same area instead runs for hours in `route_xilinx_const` |
| 5 | snap 0.8.2 ships metadata missing `site_type_PCIE_2_1.json`, so PCIe designs cannot place at all |
| 6 | An unconstrained clock silently gets a 12 MHz target, so timing failures on that domain are never reported |
| 7 | `create_clock [get_nets ...]` drops the constraint **silently** when the net name does not match - no warning |
| 8 | `pack_io_xc7.cc:474` treats **any** cell carrying a `BEL` attribute as IO and errors on anything that is not IOB18/IOB33, so `BEL` cannot be used to pin non-IO cells (the type check sits above the `rules.count(ci->type)` guard) |
| 9 | Yosys 0.38 `iopadmap -ignore` hangs indefinitely; same command without `-ignore` finishes in ~25 s |
| 10 | `--placer sa` produces a placement that fails nextpnr's own post-placement validity check |
| 11 | `TXPI_SYNFREQ_PPM` defaulting to 0 makes any design that omits the attribute fail |
| 12 | prjxray `bitread` segfaults on `xc7a200t`, so `bit2fasm` cannot be used to inspect a bitstream for this part |
| 13 | **SRL32 cascade `Q31` port missing in nextpnr** - `ERROR: No wire found for port Q31 on source cell ... fpga_srl_0` when synthesizing shift registers, requiring `-nosrl` workaround |
| 14 | **`IBUFDS_GTE2` primitive model missing `ODIV2` pin** - `ERROR: No wire found for port ODIV2 on source cell ...` because nextpnr BEL definition only contains `['CEB', 'I', 'IB', 'O']` |
| 15 | `pack_gt_xc7.cc:184` rejects constant zero (`PSEUDO_GND`) on `GTREFCLK` - `GTP_COMMON GTREFCLK connected to unsupported cell type PSEUDO_GND` when unused refclk inputs are tied to `1'd0` |
| 16 | **`router2` fails to route `$PACKER_GND_NET` to `CARRY4.CIN`** - `ERROR: Unrouteable $PACKER_GND_NET sink ... genblk1.carry4.CIN` when carry chains are enabled, requiring `-nocarry` |

-----------
#### End-of-Document
