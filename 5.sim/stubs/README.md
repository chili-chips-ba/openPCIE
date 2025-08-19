# _openpcie2-rc_ DUT stub

This folder contains a stub in lie of the DUT RTL in order to get the top level test bench running. Once the DUT is available this mdel may be discarded.

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
