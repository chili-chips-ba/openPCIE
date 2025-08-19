# LTSSM support code for _pcieVHost_

This source code in this directory is a _partial_ implementation model of the PCIe LTSSM link training state machine. It is incomplete but can power up from electrically idel to the link up L0 state.

It is not part of the _pcievhost_ proper and sits on top of the API provide by the model. It can be used by the user code and, for _openpcie2-rxc_ is compiled into the `libuser.a` library built in the `5.sim` directory, along with the user provide source code.