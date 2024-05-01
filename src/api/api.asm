; C库函数
[BITS 16]
[global write]
[global sleep]


write:
    PUSHA
    MOV AX,1
    MOV SI,SP                 ; 由于PUSHA会使SP增加16，因此字符串位置为16+4
    ADD SI,20
    INT 0x80
    POPA
    RETF

sleep:
    PUSHA
    MOV AX,2
    MOV SI,SP
    ADD SI,20
    INT 0x80
    POPA
    RETF