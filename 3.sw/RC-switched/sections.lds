MEMORY {
    mem : ORIGIN = 0x00000000, LENGTH = 0x00002000
}
SECTIONS {
    .text : {
        *(.vectors)
        *(.text)
    } > mem
}