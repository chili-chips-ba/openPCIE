This is a bonus deliverable, above and beyond our original plan. [Here](https://github.com/chili-chips-ba/openPCIE/tree/main/1.pcb#usecase-2-switched-fpga_rc-to-fpga_ep-gen1-x1) is the corresponding hardware setup. 

In order to make it possible, we had to get to the root of what looked like ASM1184e overheating problem, see slide 17 [here](https://github.com/chili-chips-ba/openPCIE/blob/main/1.pcb/0.doc/OpenPCIE%20backplane%20presentation.pptx), but turned out to be an undersized LDO. We are replacing with a DC/DC buck on the RevB openBackplane.

----
End-of-Document
