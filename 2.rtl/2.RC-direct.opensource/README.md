# Opensource RC-direct core 

This is an opensource variant of what was first tested with [AMD-proprietary RC-direct IP stack](../../2.amd-rtl-with-Vivado-build/2.RC-direct.amd). It is still **WIP**:
- [x] ✔️ Hardware FSM is replaced with opensource RISC-V based SOC 
- [ ] Replacement of the PCIE IP core is ongoing
- [ ] we also plan to upgrade the current simple SOC with version that uses PeakRDL for CSR generation 

Together with our [openPCIE backplane](../../1.pcb) and Simon's unique [end-to-end PCIE sim](../../5.sim) setup, this is **`one of the three pillars`**, i.e. primary deliverables of this project.

The objectives of this dev track are to:
 - first design the opensource RC-direct core
 - then validate and showcase its operation in a direct RC-to-EP configuration.

With both this direct and [RC-switched](../3.Bonus--RC-switched.opensource) use-cases thus tried and proven to be true, we will have established a nicely rounded set of opensource cores and examples -- A solid foundation for the makers to build their future applications upon...

----
End-of-Document
