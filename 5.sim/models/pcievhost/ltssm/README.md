# LTSSM support code for _pcieVHost_

This source code in this directory is a _partial_ implementation model of the PCIE LTSSM link training state machine. It is incomplete but can power up from electrically idle to the link up L0 state.

It is not part of the _pcievhost_ proper and sits on top of the API provided by the model. It can be used by the user code and, for _openPCIE_ is compiled into the `libuser.a` library built in the `5.sim` directory, along with the user-provided source code.