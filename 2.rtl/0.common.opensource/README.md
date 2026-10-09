# Opensource RC: shared RTL

The two opensource Root Complex designs,
[RC-direct](../2.RC-direct.opensource) and
[RC-switched](../3.Bonus--RC-switched.opensource), are built from the very same
RTL. It lives here, once.

```
src/
  RC_opensource.sv              top level: refclk buffer, PCIE bridge, SOC, LEDs
  riscv_pcie_soc.sv             picorv32 SOC, drives the AXI-Stream TLP interface
  soc_csr.sv                    wrapper for the PeakRDL-generated CSR block
  picorv32.CHILI.sv             the RISC-V core (Chili.CHIPS-improved picorv32)
  pcie/                         the opensource PCIE stack
xdc/
  RC.sv.x1g2.AcornCLE-215P.xdc  constraints, all but the GT lane (source of truth)
RC.opensource.tcl               the Vivado project script behind both wrappers
```

What stays in each variant's own folder is only what really differs:

| | RC-direct | RC-switched |
|---|---|---|
| GT lane (one-line XDC) | `GTPE2_CHANNEL_X0Y5` | `GTPE2_CHANNEL_X0Y6` |
| Vivado project | `RC-direct.opensource.tcl` -> `xbuild.Vivado-v2024.2/` | `RC-switched.opensource.tcl` -> `xbuild.Vivado-v2024.2/` |
| Firmware | [`3.sw/RC-direct`](../../3.sw/RC-direct) | [`3.sw/RC-switched`](../../3.sw/RC-switched) |

`riscv_pcie_soc.sv` picks Type 0 or Type 1 for every Configuration TLP from the
target bus number - Type 1 beyond bus 1, as a switch needs. The RC-direct
firmware addresses its endpoint on bus 1, so for it every request stays Type 0.

The PCIE stack is described file by file in the
[RC-direct README](../2.RC-direct.opensource/README.md#the-pcie-stack-by-layer),
the switch handling in the
[RC-switched README](../3.Bonus--RC-switched.opensource/README.md#what-differs-from-rc-direct).
The same sources also feed the [openXC7 build](../../4.build/hw_build.openXC7)
and the [co-simulation](../../5.sim).
