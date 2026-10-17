MEMORY {
    mem : ORIGIN = 0x00000000, LENGTH = 0x00002000
}
SECTIONS {
    .text : {
        *(.vectors)
        *(.text)
    } > mem
}

/* -----------------------------------------------------------------------------
   Project:     openPCIE
   Description: NLnet-sponsored open-source implementation
   Version:     1.0
   Date:        May 24, 2024
   ----------------------------------------------------------------------------- */
