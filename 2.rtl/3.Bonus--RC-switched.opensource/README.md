# Opensource RC-switched core (bonus)

This is an opensource variant of what was first tested with the
[AMD-proprietary RC-switched IP stack](../../2.amd-rtl-with-Vivado-build/3.Bonus--RC-switched.amd).
It is an extra / bonus deliverable, above and beyond our original plans.

- ✅ Hardware FSM replaced with an opensource RISC-V based SOC
- ✅ PCIE IP core replaced with opensource RTL
- ✅ Builds with a **fully opensource toolchain**
- ✅ Enumerates an ASM1184e switch and the endpoints behind it
- ✅ SOC uses PeakRDL for CSR generation, from the same `csr.rdl` as RC-direct

The objectives of this dev track were to:
 - first design an opensource _RC-switched_ core, based on the already tested
   and familiarized with proprietary core
 - then validate and showcase its operation in a Switched PCIE context,
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
| Link | PCIE Gen2 x1 (x1 only: the switch ports are x1; x4 is RC-direct only) |
| Vivado build | works |
| Opensource build | works - see [`4.build/hw_build.openXC7`](../../4.build/hw_build.openXC7) |

Link width comes from the `PCIE_LANES` define read by [`link_pkg.sv`](../0.common.opensource/src/pcie/link_pkg.sv) (shared with [RC-direct](../2.RC-direct.opensource), where 4 is the default). The RC-switched builds always set it to 1: `make VARIANT=switched` and the Vivado wrapper refuse x4.

The corresponding hardware setup is
[here](../../1.pcb#usecase-2-switched-fpga_rc-to-fpga_ep-gen2-x1). Note that the
ASM1184e on the RevA backplane is fed by an undersized LDO - see slide 17 of the
[presentation](../../1.pcb/0.doc). RevB replaces it with a DC/DC buck.

---

## What differs from RC-direct

In the RTL: nothing. RC-direct and RC-switched are built from the very same
sources in [`0.common.opensource`](../0.common.opensource) - one top
(`RC_opensource`), one SOC, one PCIE stack. A switch changes nothing at
the physical or link layer; the root port still trains a plain Gen2 x1 link, and
what it talks to on the far end happens to be a switch upstream port instead of
an endpoint. Everything that changes is one level up, in how Configuration TLPs
are addressed - which the shared SOC handles for both, and the firmware drives.

### 1. RTL: Type 0 / Type 1 selection (`riscv_pcie_soc.sv`)

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
assign tx_dw0     = csr_out.tx.header0.hdr.value;
assign tx_cfg_dw2 = csr_out.tx.header2.hdr.value;
assign pkt_is_cfg = (tx_dw0.tlp_type[4:1] == TLP_TYPE_CFG);

always_comb begin
  tx_dw0_routed = tx_dw0;
  if (pkt_is_cfg) begin
    tx_dw0_routed.tlp_type[0] = (tx_cfg_dw2.bus > 8'd1);
  end
end
```

`tlp_type[4:1]` marks a Configuration request and `tlp_type[0]` is the Type 0 /
Type 1 selector (structs `pcie_tlp_dw0_t`, `pcie_cfg_dw2_t` in `pcie_pkg.sv`).
Memory and Completion TLPs pass through untouched.

This logic is in the shared SOC, so RC-direct carries it too. There it never
acts: the direct firmware addresses its endpoint on bus 1, which is a Type 0
request either way. What does differ between the two projects:

* The GT lane. This folder's XDC holds one line, locking the transceiver to
  `GTPE2_CHANNEL_X0Y6` (RC-direct: `X0Y5` at x1; at x4, the default, `X0Y6`,
  `X0Y4`, `X0Y5`, `X0Y7` for lanes 0-3); all other constraints are shared -
  see the lane table in [`2.rtl/README.md`](../README.md#common-physical-constraints-xdc).
* The firmware, below.

### 2. Firmware: the bring-up sequence

The AMD design drives the sequence from a 46-entry ROM
(`cgator_cfg_rom.data`). Here it is plain C, in
[`3.sw/RC-switched/main.c`](../../3.sw/RC-switched/main.c) on top of the PCIE
request layer both firmwares share ([`3.sw/common`](../../3.sw/common)), and it walks the same
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

The co-simulation runs this firmware against a switch model with two endpoints and two empty slots: `make run VARIANT=switched` in [5.sim](../../5.sim/README.md#rc-switched-a-switch-behind-the-link).

* **Step 1 - switch upstream port.** Bus numbers (primary 1, secondary 2,
  subordinate 6), one memory window `0x10000000 - 0x103FFFFF` covering
  everything behind the switch, then Memory Space + Bus Master.
* **Step 2 - the four downstream ports** on the internal bus 2. Each is a
  virtual bridge, gets its own secondary bus and its own 1 MB slice of the
  upstream window.
* **Step 3 - the endpoints**, device 0 on buses 3..6. Every BAR is sized
  (write all ones, read back, decode the 32/64-bit type) and placed, aligned to
  its size, inside the 1 MB window its port forwards - put it anywhere else and
  the port drops every memory request aimed at it. BAR0 therefore lands at the
  window base. A BAR0 larger than the window is reported, not squeezed in; any
  other BAR that does not fit is parked out of the way (64-bit above 4 GB,
  32-bit at 0).
* **Step 4 - self test.** Memory write and readback through the switch for each
  populated slot, then `0x0000FACE` / `0x0000DEAD` to `PCIE_RESULT`, as in the
  direct build.

Two things worth knowing when comparing the C against the AMD ROM dump:

* Configuration payloads travel **big-endian** - byte 0 of the register ends up
  in bits `[31:24]` of the data dword. Both firmwares make the swap explicit in
  `bswap32()`, so the register values are written the way the spec prints them
  (BAR `0x10000000`, not `0x00000010`).
* The ROM writes `0x103F` into a memory-limit field where this firmware writes
  `0x1030`. Bits `[3:0]` of the Memory Limit register are read-only, so the two
  land the same value in the switch.

Unlike the ROM, the firmware **probes each slot** before configuring it and
skips the empty ones, so a partially populated backplane is fine. It reports its result in `PCIE_RESULT` (`status.result`, `0x3000_0024`), a register that sends no TLP. PASS also lights `led_link_up[3]`, and every marker can be watched with an ILA ([RTL Debug with ILA](../README.md#rtl-debug-with-ila)):

| Marker | Meaning |
|---|---|
| `0x0000FACE` | every endpoint that was found passed its readback |
| `0x0000DEAD` | an endpoint failed its readback |
| `0xBAD00000` | the switch upstream port did not answer at all |
| `0xBAD00001` | the switch is up, but no endpoint was found behind it |
| `0xBAD00002` | a config request to a device that had answered failed (UR, CA, timeout, or CRS after 100 retries) |
| `0xBAD00003` | an endpoint's BAR0 is not implemented, is I/O, or is larger than its 1 MB port window |

Every request's Completion Status is checked; config reads **and** writes
answered with CRS are re-issued up to 100 times.

---

## Structure

```
2.rtl/0.common.opensource/        shared by both root complexes
  src/
    RC_opensource.sv              top level: PCIE stack, SOC, LEDs
    riscv_pcie_soc.sv             RISC-V SOC (eduBOS5 or picorv32) + the Type 0/Type 1 routing above
    soc_csr.sv                    wrapper for the PeakRDL-generated CSR block
    picorv32.CHILI.sv             the alternative RISC-V core (Chili.CHIPS-improved picorv32)
    CPU.eduBOS5/                  the default RISC-V core
    pcie/                         the opensource PCIE stack
  xdc/
    RC.common.xdc                 constraints, all but the GT lane (source of truth)
  RC.opensource.tcl               the Vivado project script behind both wrappers

2.rtl/3.Bonus--RC-switched.opensource/   this folder
  xdc/
    RC-switched.x1g2.AcornCLE-215P.xdc  GT lane: GTPE2_CHANNEL_X0Y6
  RC-switched.opensource.tcl      regenerates the Vivado project from scratch
```

For a file-by-file walk through the PCIE stack, see the
[RC-direct README](../2.RC-direct.opensource/README.md), which applies here
unchanged.

### The CSR

The register window the firmware drives (`0x3000_0000` in the SOC address map)
is **generated**, not hand-written. The source of truth is a SystemRDL file,
[`4.build/csr_build/csr.rdl`](../../4.build/csr_build/csr.rdl), out of which
`peakrdl` produces the register block RTL (`csr_pkg.sv`, `csr.sv`) and the
software header (`csr.h`) in
`4.build/csr_build/generated-files/`. `soc_csr.sv` is the only hand-written
piece: it bridges the picorv32 native memory interface to the "passthrough" CPU
interface of the generated block.

Regenerate after every edit of `csr.rdl`:

```bash
cd ../../4.build && make -f MakefileCSR
```

Nothing about the CSR differs between this variant and RC-direct - the same `csr.rdl` feeds both.
Details: [`4.build/README.md`](../../4.build/README.md#csr-hal-compilation).

---

## Building

Build the firmware first - `firmware.hex` is a hard dependency of both flows,
and it has to be the **switched** one:

```sh
cd 4.build/sw_build
make VARIANT=switched
```

No `make clean` is needed to switch variants - every `make` there rebuilds the
firmware from scratch (about a second).

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

Output goes to `4.build/hw_build.openXC7/build_artifacts/top.x1g2.switched.bit`, next to the direct
builds. See [`4.build/hw_build.openXC7`](../../4.build/hw_build.openXC7) for the
toolchain requirements.

----
End-of-Document
