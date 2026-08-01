.section .vectors
.global _start
_start:
    li sp, 0x2000    
    call main       
loop:
    j loop           