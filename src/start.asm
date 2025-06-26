BITS 16

section .text

global start
extern kernel_main


start:
    MOV si, message_hello             ; Load the address of the string into SI
    CALL print_string
    CLI
    CALL enable_A20
    CALL load_gdt
   

    ; Switch to protected mode by switching CR0 to 1
    MOV eax, cr0 
    OR al, 1       ; set PE (Protection Enable) bit in CR0 (Control Register 0)
    MOV cr0, eax

    ; Perform far jump to selector 08h (offset into GDT, pointing at a 32bit PM code segment descriptor) 
    ; to load CS with proper PM32 descriptor)
    jmp 0x08:PModeMain
    HLT  
    

PModeMain:
    [BITS 32]
    ; setup segment registers
    MOV eax, 0x10
    MOV ds, eax
    MOV ss, eax

    MOV esp, 0x90000     ; Setup stack
    CALL kernel_main

.hang:
    HLT
    JMP .hang


enable_A20:
    [BITS 16]
    ; Disable keyboard
    CALL a20_wait_input
    MOV al, 0xAD
    OUT 0x64, al

    ; Tells keyboard to put its current output port state on 0x60
    CALL a20_wait_input
    MOV al, 0xD0
    OUT 0x64, al

    ; Reads current output port state from 0x60
    CALL a20_wait_output
    IN al, 0x60
    PUSH ax

    ; Tells keyboard we want to set its output port flags
    CALL a20_wait_input
    MOV al, 0xD1
    OUT 0x64, al

    ; Sets output port flags: set A20=1 (bit 1 in the keyboard controller)
    CALL a20_wait_input
    POP ax
    OR al, 2
    OUT 0x60, al

    ; Enable keyboard
    CALL a20_wait_input
    MOV al, 0xAE
    OUT 0x64, al

    CALL a20_wait_input
    RET

; wait until status bit 2 is 0 so which means it is free and we can send commands
a20_wait_input:
    [BITS 16]
    IN al, 0x64
    TEST al, 2
    JNZ a20_wait_input
    RET


; wait until status bit 1 is 1 so that it means it is free and we can read from it
a20_wait_output:
    [BITS 16]
    IN al, 0x64
    TEST al, 1
    JZ a20_wait_output
    RET

load_gdt:
    [BITS 16]
    LGDT [gdt_descriptor]
    RET


print_string:
    [BITS 16]
    MOV al, [si]        ; Load character in SI to AL and increments SI
    INC si

    CMP al, 0           ; Is the character NULL? Sets zero flag
    JE .done            ; If zero flag is set go to done
    
    MOV bh, 0           ; Tells you what page to print to
    MOV ah, 0x0E        ; Tells bios to give a teletype output
    INT 0x10            ; Interrupt prints the charcter stored in AL
    JMP print_string    ; Go to next character

.done:
    [BITS 16]
    RET                 ; Return back to caller

section .data
message_hello db 'Inside starter...', 0x0D, 0x0A, 0
gdt_table:
            dq 0

            ; 32-bit code segment
            dw 0FFFFh                   ; limit (bits 0-15) = 0xFFFFF for full 32-bit range
            dw 0                        ; base (bits 0-15) = 0x0
            db 0                        ; base (bits 16-23)
            db 10011010b                ; access (present, ring 0, code segment, executable, direction 0, readable)
            db 11001111b                ; granularity (4k pages, 32-bit pmode) + limit (bits 16-19)
            db 0                        ; base high

            ; 32-bit data segment
            dw 0FFFFh                   ; limit (bits 0-15) = 0xFFFFF for full 32-bit range
            dw 0                        ; base (bits 0-15) = 0x0
            db 0                        ; base (bits 16-23)
            db 10010010b                ; access (present, ring 0, data segment, executable, direction 0, writable)
            db 11001111b                ; granularity (4k pages, 32-bit pmode) + limit (bits 16-19)
            db 0                        ; base high


gdt_descriptor: 
    dw gdt_descriptor - gdt_table - 1   ; Size of gdt_table (-1 because lgdt expects size - 1)
    dd gdt_table                        ; Address of gdt_table
