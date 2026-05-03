# opensource openXC7 build flow

## openXC7 Installation

The **`openXC7`** toolchain is an open-source build flow for Xilinx 7-series FPGAs.

It includes:
- **Yosys** - RTL synthesis
- **nextpnr-xilinx** - Place and route
- **Project X-Ray** - FPGA bitstream generation tools

Once the openXC7 tools are installed, such as by following our instructions [here](https://github.com/chili-chips-ba/openeye-CamSI/blob/main/3.build/openXC7/README.md), or per the [openXC7](https://github.com/openxc7) home page, also make sure to source the environment setup script before building:

```bash
% source /opt/openxc7/setup_env.sh
```

Provided you use openXC7 version that includes all bug fixes we've identified in the course of this project (see [openXC7 issues](https://github.com/chili-chips-ba/openPCIE/issues?q=is%3Aissue%20label%3AopenXC7)), the build is then as simple as:
```bash
% make
```

#### End-of-Document
