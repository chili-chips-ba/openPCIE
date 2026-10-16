# eduBOS5

[eduBOS5](https://github.com/tarik-ibrahimovic/eduBOS5) is Chili.CHIPS' compact RV32I RISC-V core, now open source under BSD-3-Clause. The openPCIE SOC uses eduBOS5 (default) or PicoRV32:

| | eduBOS5 (default) | PicoRV32 |
|---|---|---|
| openXC7 build | `make` | `make CPU=picorv32` → `build_artifacts.*picorv32*/` |
| co-simulation | `make run` | `make CORE=picorv32 run` |
| ISS timing model | `make CPU=iss run` | `make CPU=iss CORE=picorv32 run` |
| lint, LEQ | `bash run-lint.sh` | `CPU=picorv32 bash run-lint.sh` |
| x0 = 0, FPGA (default) | `TARGET_IS_ASIC=0`: register file RAM starts at 0 | `TARGET_IS_ASIC=0`: register file RAM starts at 0 |
| x0 = 0, ASIC | `TARGET_IS_ASIC=1`: read mux | `TARGET_IS_ASIC=1`: read mux |

x0 is never written, so it must read 0 from the start. An FPGA RAM has a power-up value (its INIT); an ASIC does not, hence the mux.

`riscv_pcie_soc.sv` connects it to the dual-port SOC RAM without a mux between instruction and data: instruction fetch on port B (read-only), loads and stores on port A through the SOC memory bus, which it shares with the CSR. PicoRV32 has one bus for both, on port A.

| File | |
|---|---|
| `edubos5.sv` | the core: control FSM, decode, load/store |
| `edubos5_alu.sv` | ALU, registered output |
| `edubos5_rf.sv` | register file: 2 asynchronous read ports, 1 synchronous write port |
| `edubos5_pkg.sv` | common types and opcodes |

Cycles per instruction, from the control FSM (`EN_WAIT4REGS` selects the pipeline):

| | 2-stage (`EN_WAIT4REGS=0`, default) | 3-stage (`EN_WAIT4REGS=1`) |
|---|---|---|
| ALU, branch, `jal`, `jalr`, store | 2 | 3 |
| load | 3 | 4 |

The rv32 ISS models both (`-V EDUBOS5STG2`, `-V EDUBOS5STG3`, see [5.sim](../../../../5.sim/README.md)).
