# Opensource RC: shared RTL

The two opensource Root Complex designs,
[RC-direct](../2.RC-direct.opensource) and
[RC-switched](../3.Bonus--RC-switched.opensource), are built from the very same
RTL. It lives here, once.

```
src/
  RC_opensource.sv              top level: PCIE stack, SOC, LEDs
  riscv_pcie_soc.sv             RISC-V SOC (eduBOS5 or picorv32), drives the AXI-Stream TLP interface
  soc_csr.sv                    wrapper for the PeakRDL-generated CSR block
  picorv32.CHILI.sv             the alternative RISC-V core (Chili.CHIPS-improved picorv32)
  CPU.eduBOS5/                  the default RISC-V core
  pcie/                         the opensource PCIE stack
xdc/
  RC.common.xdc                 constraints, all but the GT lane (source of truth)
RC.opensource.tcl               the Vivado project script behind both wrappers
```

What stays in each variant's own folder is only what really differs:

| | RC-direct | RC-switched |
|---|---|---|
| GT lanes (XDC) | x4 (default): `GTPE2_CHANNEL_X0Y6`, `X0Y4`, `X0Y5`, `X0Y7`; x1: `X0Y5` | x1: `GTPE2_CHANNEL_X0Y6` |
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

-----------
#### End-of-Document
