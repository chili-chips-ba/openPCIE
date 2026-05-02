# Root Complex (Switched Connection) - AMD IP Implementation

This is a bonus deliverable, above and beyond our original plan. 

[Here](https://github.com/chili-chips-ba/openPCIE/tree/main/1.pcb#usecase-2-switched-fpga_rc-to-fpga_ep-gen1-x1) is the corresponding hardware setup. 

In order to make it work, we had to get to the root of what looked like ASM1184e overheating problem, see slide 17 of [presentation](https://github.com/chili-chips-ba/openPCIE/blob/main/1.pcb/0.doc/OpenPCIE%20backplane%20presentation.pptx). This turned out to be an undersized LDO (which is to be replaced with a DC/DC buck on the RevB openPCIE backplane).

Once that was taken out of the way, the test procedure was very similar to what was done to validate the [direct](../2.RC-direct.amd) topology.

----
End-of-Document
