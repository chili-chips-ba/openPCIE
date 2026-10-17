.section .vectors
.global _start
_start:
    li sp, 0x2000    
    call main       
loop:
    j loop           

// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
