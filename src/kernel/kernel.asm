;kernel
[BITS 16]
[ORG 0x7C00]

_start:
    ;寄存器初始化
    CLI
    MOV SP, 0x7C00
    XOR AX, AX
    MOV SS, AX
    MOV ES, AX
    MOV DS, AX
    STI

    MOV AX, 0x0003
    INT 0x10                               ; 清屏

    CLI
    CALL SET_INTERRUPT                     ; 设置中断向量表
    CALL SET_TIMER                         ; 设置定时器
    STI

LOADPROGRAMME:                             ; 加载C程序
    PUSHA
    MOV AX,CS                              ; 段地址
    MOV ES,AX                              ; 设置段地址
    MOV BX, 0x8000                         ; 偏移地址
    MOV AH,2                               ; 功能号
    MOV AL,10                              ; 扇区数
    MOV DL,0x80                            ; 驱动器号
    MOV DH,0                               ; 磁头号
    MOV CH,0                               ; 柱面号
    MOV CL,2                               ; 起始扇区号
    INT 0x13
    POPA

    ; 模仿硬件中断，先将后续执行代码的CS:IP以及标志寄存器（PSW）的值保存到栈上
    PUSHF
    PUSH CS
    PUSH KERNEL_LOOP

    MOV WORD [PCB_KERNEL_SP],SP            ;  保存当前内核进程SP
    MOV WORD [PCB_KERNEL_SS],SS            ;  保存当前内核进程SS
    MOV WORD SP,[PCB_APP_SP]               ;  跳转到用户进程栈
    MOV WORD SS,[PCB_APP_SS]

    JMP 0x8000                             ; 跳转到C程序执行

KERNEL_LOOP:
    JMP KERNEL_LOOP                        ; 无限循环

CLOCK_INTERRUPT:                           ; 时钟中断处理例程
    PUSHA
    DEC WORD [TIMES_COUNTER]               ; 减少计数器的值
    MOV AL, 0x20
    OUT 0x20, AL                           ; 发送EOI命令给8259A中断控制器
    CMP WORD [TIMES_COUNTER],0
    JE SLEEP_WAKE                          ; 若计数器为0，跳回应用进程
    POPA
    IRET

SLEEP_WAKE:
    POPA
    MOV WORD [PCB_KERNEL_SP],SP            ;  保存当前内核进程SP
    MOV WORD [PCB_KERNEL_SS],SS            ;  保存当前内核进程SS
    MOV WORD SP,[PCB_APP_SP]               ;  跳转到用户进程栈
    MOV WORD SS,[PCB_APP_SS]
    IRET

INTERUPT_HANDLER:                          ; INT 0x80中断处理
    CMP AX,1
    JE KERNEL_WRITE
    CMP AX,2
    JE KERNEL_SLEEP
    IRET

KERNEL_WRITE:
    MOV	AX, CS                             ; 置其他段寄存器值与CS相同
    MOV	DS, AX                             ; 数据段
    MOV	BP, [SI]                           ; BP=当前字符串的偏移地址
    MOV	AX, DS                             ; ES:BP = 串地址
    MOV	ES, AX                             ; ES=DS
    MOV	CX, [SI+4]                         ; CX = 字符串长度
    MOV	AX, 0x1301
    MOV	BX, 0x0007
    MOV DH,[LINE]
    MOV DL, 0x0
    INT 0x10

    MOV AL, 0x0A                           ; 换行符的ASCII码
    MOV AH, 0x0E
    INT 0x10

    INC WORD [LINE]
    MOV AH, 0x02                           ; 功能号2表示设置光标位置
    MOV BH, 0x00                           ; 页号
    MOV DH,[LINE]
    MOV DL, 0x00                           ; 列号（0表示最左侧）
    INT 0x10

    IRET

KERNEL_SLEEP:
    MOV AX, [SI]
    MOV CX, 100                            ; 将乘数100加载到CX中
    MUL CX                                 ; 乘法运算
    MOV WORD [TIMES_COUNTER], AX           ; 设置计数器

    MOV WORD [PCB_APP_SP],SP               ;  保存当前用户进程SP
    MOV WORD [PCB_APP_SS],SS               ;  保存当前用户进程SS
    MOV WORD SP,[PCB_KERNEL_SP]            ;  跳转到内核进程
    MOV WORD SS,[PCB_KERNEL_SS]

    IRET

SET_INTERRUPT:
    MOV AX, 0        
    MOV ES, AX
    MOV WORD [ES:4*0x08], CLOCK_INTERRUPT  ; 将时钟中断处理例程写入中断向量表
    MOV WORD [ES:4*0x08+2], CS
    MOV WORD [ES:4*0x80], INTERUPT_HANDLER ; 将INT 0x80中断处理例程写入中断向量表
    MOV WORD [ES:4*0x80+2], CS
    RET

SET_TIMER:                                 ; 设置8253/4定时器芯片
    MOV AL, 0x36 
    OUT 0x43, AL
    MOV AX, 0x2E9C                         ; 每隔10ms产生一次时钟中断
    OUT 0x40, AL
    MOV AL, AH
    OUT 0x40, AL
    RET

LINE DW 0                                  ; 存储当前输出的行数
TIMES_COUNTER DW 0                         ; 计数器

PCB_KERNEL_SP DW 0x7c00                    ;  内核进程的栈指针SP
PCB_KERNEL_SS DW 0x0000                    ;  内核进程的栈寄存器SS
PCB_APP_SP DW 0x7000                       ;  用户进程的栈指针SP
PCB_APP_SS DW 0x0000                       ;  用户进程的栈寄存器SS

CURRENT_PCB DW 0                           ; 当前进程PCB指针

TIMES 510-($-$$) DB 0
DW 0xaa55