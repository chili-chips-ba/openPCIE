# _openpcie2-rc_ DUT stub, and other superseded originals

This folder keeps the pieces that came before the real DUT was wired in. None of
them is built any more; they are here so the earlier arrangement stays readable.

| File | What it was |
|---|---|
| `dut_stub.v`, `tb.STUB.sv`, `tb.STUB.prj` | the stub DUT and its test bench, described below. The live test bench is [`../tb.sv`](../tb.sv) with [`../tb.prj`](../tb.prj). |
| `VUserMain0.SANITY.cpp` | the original node-0 sanity program: a single write and read-back at `0x10001000`, an address this design does not have. Superseded by [`../usercode/VUserMain0.cpp`](../usercode/VUserMain0.cpp), which runs the real bring-up sequence for `make CPU=vproc`. |

To go back to the stub test bench, analyse with `tb.STUB.prj` in place of
`tb.prj`.

---

## The stub DUT

This was a stub in lieu of the DUT RTL, in order to get the top level test bench running.

It has the folloing features

  * Ports
    * A differential system clock input
    * A PCIe pipe clock input
    * An asynchronous active low reset
    * A UART input port
    * A 2 bit key input
    * A 2 bit LED output
    * PIPE data output (8-bit data, 1-bit K flag)
    * PIPE data input  (8-bit data, 1-bit K flag)
  * Internal components
    * An `soc_cpu.VPROC`
      * `imem_xxx` ports tied off
      * `soc_if` with inputs tied off
    * A `pcieVHostsPipex1` configured as RC at VProc node 2
      * Is the BFM wrapper for the `pcieVHost`
      * Ports connected to DUT PIPE ports
