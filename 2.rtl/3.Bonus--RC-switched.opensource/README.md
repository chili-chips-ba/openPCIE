# Opensource RC-switched core (bonus)

This is an opensource variant of what was first tested with the
[AMD-proprietary RC-switched IP stack](../../2.amd-rtl-with-Vivado-build/3.Bonus--RC-switched.amd).
It is an extra / bonus deliverable, above and beyond our original plans.

- [x] ✔️ Hardware FSM replaced with an opensource RISC-V based SOC
- [x] ✔️ PCIe IP core replaced with opensource RTL
- [x] ✔️ Builds with a **fully opensource toolchain**
- [x] ✔️ Enumerates an ASM1184e switch and the endpoints behind it
- [x] ✔️ SOC uses PeakRDL for CSR generation, from the same `csr.rdl` as RC-direct

The objectives of this dev track were to:
 - first design an opensource _RC-switched_ core, based on the already tested
   and familiarized with proprietary core
 - then validate and showcase its operation in a Switched PCIe context,
   repeating the test procedure used for the AMD solution.

With both this indirect/switched and [RC-direct](../2.RC-direct.opensource)
use-cases tried and proven, we have a nicely rounded set of opensource cores
and examples -- a solid foundation for the makers to build their future
applications upon...

---

## Status

| | |
|---|---|
| Target device | `xc7a200tfbg484-3`, Acorn CLE-215P |
| Switch | ASM1184e, 1 upstream + 4 downstream ports |
| Link | PCIe Gen2 x1 |
| Vivado build | works |
| Opensource build | works - see [`4.build/hw_build.openXC7`](../../4.build/hw_build.openXC7) |

Link width and speed come from a single place, `src/pcie/link_pkg.sv`:

```systemverilog
localparam int PCIE_LANES = 1;   // 1, 2, 4 or 8
localparam int PCIE_GEN   = 2;   // 1 = Gen1, 2 = Gen2
```

The corresponding hardware setup is
[here](../../1.pcb#usecase-2-switched-fpga_rc-to-fpga_ep-gen1-x1). Note that the
ASM1184e on the RevA backplane is fed by an undersized LDO - see slide 17 of the
[presentation](../../1.pcb/0.doc). RevB replaces it with a DC/DC buck.

---

## What differs from RC-direct

The PCIe stack itself is untouched - `src/pcie/` is byte-identical to
[RC-direct.opensource](../2.RC-direct.opensource). A switch changes nothing at
the physical or link layer; the root port still trains a plain Gen2 x1 link, and
what it talks to on the far end happens to be a switch upstream port instead of
an endpoint. Everything that changes is one level up, in how Configuration TLPs
are addressed.

### 1. RTL: Type 0 / Type 1 selection (`src/riscv_pcie_soc.sv`)

In a direct connection the endpoint always sits on bus 1, so every Configuration
request is a **Type 0** one. Behind a switch the requests have to cross virtual
PCI-to-PCI bridges, and those only forward **Type 1** requests.

The AMD design solves this inside `cgator_pkt_generator.v`:

```verilog
wire [7:0] pkt_bus_num;
wire [4:0] pkt_dev_num;
assign cfg_type_code = (pkt_bus_num > 8'd1) ? 5'b00101 : 5'b00100;
```

`pkt_bus_num` / `pkt_dev_num` had to be introduced there because in the AMD
stack the packet generator builds the header itself and the target was
hardcoded; the controller now feeds it the bus and device number of every single
transaction out of the configuration ROM.

Here the SOC bridge in `riscv_pcie_soc.sv` **is** the packet generator, and the
device number already travels in the address dword the firmware wrote. So only
the bus number is picked back out of the header, and only the Type bit is
overridden:

```systemverilog
assign pkt_bus_num       = tx_header2[31:24];
assign pkt_is_cfg        = (tx_header0[28:25] == 4'b0010);
assign tx_header0_routed = pkt_is_cfg
                         ? {tx_header0[31:25], (pkt_bus_num > 8'd1), tx_header0[23:0]}
                         : tx_header0;
```

`Fmt`/`Type` sits in `tx_header0[31:24]`; `[28:25] == 4'b0010` marks a
Configuration request and bit `[24]` is the Type 0 / Type 1 selector. Memory and
Completion TLPs pass through untouched. That, plus the top module name, is the
whole RTL delta between the two projects.

### 2. Firmware: the bring-up sequence

The AMD design drives the sequence from a 46-entry ROM
(`cgator_cfg_rom.data`). Here it is plain C, in
[`3.sw/RC-switched/main.c`](../../3.sw/RC-switched/main.c), and it walks the same
steps in the same order, producing the same bus map:

```
bus 0 .............. Root Complex
 |
bus 1  dev 0 ....... ASM1184e upstream port      (pri 1, sec 2, sub 6)
 |
bus 2  dev 1 ....... downstream port 1 --> bus 3, window 0x10000000
       dev 3 ....... downstream port 2 --> bus 4, window 0x10100000
       dev 5 ....... downstream port 3 --> bus 5, window 0x10200000
       dev 7 ....... downstream port 4 --> bus 6, window 0x10300000
 |
bus 3..6  dev 0 .... the endpoint cards, BAR0 at the window base
```

* **Step 1 - switch upstream port.** Bus numbers (primary 1, secondary 2,
  subordinate 6), one memory window `0x10000000 - 0x103FFFFF` covering
  everything behind the switch, then Memory Space + Bus Master.
* **Step 2 - the four downstream ports** on the internal bus 2. Each is a
  virtual bridge, gets its own secondary bus and its own 1 MB slice of the
  upstream window.
* **Step 3 - the endpoints**, device 0 on buses 3..6. BAR0 is placed at the base
  of the window its port forwards - put it anywhere else and the port drops
  every memory request aimed at it.
* **Step 4 - self test.** Memory write and readback through the switch for each
  populated slot, then `0x0000FACE` / `0x0000DEAD` to `PCIE_TX_DATA`, as in the
  direct build.

Two things worth knowing when comparing the C against the AMD ROM dump:

* Configuration payloads travel **big-endian** - byte 0 of the register ends up
  in bits `[31:24]` of the data dword. The direct firmware hides this by writing
  pre-swapped constants (BAR `0x80000000` written as `0x00000080`); with four
  bridges to set up that gets unreadable, so here the swap is explicit in
  `bswap32()` and the register values are written the way the spec prints them.
* The ROM writes `0x103F` into a memory-limit field where this firmware writes
  `0x1030`. Bits `[3:0]` of the Memory Limit register are read-only, so the two
  land the same value in the switch.

Unlike the ROM, the firmware **probes each slot** before configuring it and
skips the empty ones, so a partially populated backplane is fine. It reports

| Marker | Meaning |
|---|---|
| `0x0000FACE` | every endpoint that was found passed its readback |
| `0x0000DEAD` | an endpoint failed its readback |
| `0xBAD00000` | the switch upstream port did not answer at all |
| `0xBAD00001` | the switch is up, but no endpoint was found behind it |

---

## Structure

```
src/
  RC_switched_opensource.sv  top level: refclk buffer, PCIe bridge, SOC, LEDs
  riscv_pcie_soc.sv          picorv32 SOC + the Type 0/Type 1 routing above
  soc_csr.sv                 wrapper for the PeakRDL-generated CSR block
  picorv32.v                 the RISC-V core itself
  pcie/                      the opensource PCIe stack (identical to RC-direct)
xdc/
  RC-switched.sv.x1g2.AcornCLE-215P.xdc   full constraints (source of truth)
RC-switched.opensource.tcl   regenerates the Vivado project from scratch
```

For a file-by-file walk through the PCIe stack itself, see the
[RC-direct README](../2.RC-direct.opensource/README.md), which applies here
unchanged.

### The CSR

The register window the firmware drives (`0x3000_0000` in the SOC address map)
is **generated**, not hand-written. The source of truth is a SystemRDL file,
[`4.build/csr_build/csr.rdl`](../../4.build/csr_build/csr.rdl), out of which
`peakrdl` produces the register block RTL (`csr_pkg.sv`, `csr.sv`) and the
software headers (`csr.h`, `csr_hw.h`, `csr_cosim.h`) in
`4.build/csr_build/generated-files/`. `src/soc_csr.sv` is the only hand-written
piece: it bridges the picorv32 native memory interface to the "passthrough" CPU
interface of the generated block.

Regenerate after every edit of `csr.rdl`:

```bash
cd ../../4.build && make -f MakefileCSR
```

The original hand-written register block is still in `riscv_pcie_soc.sv`, behind
`` `ifdef SOC_CSR_LEGACY ``. Which one gets built is set once, in
[`4.build/config.mk`](../../4.build/config.mk), and read by every build step, so
hardware and software are never built different ways. Override it for a single
run with `make CSR=legacy` (openXC7 or firmware) or `set ::use_legacy_csr 1`
before sourcing the tcl (Vivado).

The two are functionally identical, down to the byte offsets. Nothing about the
CSR differs between this variant and RC-direct - the same `csr.rdl` feeds both.
Details: [`4.build/README.md`](../../4.build/README.md#csr-hal-compilation).

---

## Building

Build the firmware first - `firmware.hex` is a hard dependency of both flows,
and it has to be the **switched** one:

```sh
cd 4.build/sw_build
make clean && make VARIANT=switched
```

### Vivado

```tcl
source RC-switched.opensource.tcl
```

The generated project lands in `xbuild.Vivado-v2024.2/`.

### Opensource

```sh
cd 4.build/hw_build.openXC7
make VARIANT=switched
```

Output goes to `build_artifacts.switched/top.bit`, kept separate from the direct
build. See [`4.build/hw_build.openXC7`](../../4.build/hw_build.openXC7) for the
toolchain requirements - in particular, the nextpnr-xilinx version is critical.

----
End-of-Document
