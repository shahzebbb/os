BITS 16
ORG 0x0000

start:
    MOV si, message_hello             ; Load the address of the string into SI
    CALL print_string
    CLI
    CALL enable_A20
    HLT

enable_A20:
    ; Disable keyboard
    CALL a20_wait_input
    MOV al, 0xAD
    OUT 0x64, al

    ; Read from input
    CALL a20_wait_input
    MOV al, 0xD0
    OUT 0x64, al

    CALL a20_wait_output
    IN al, 0x60
    PUSH eax

    ; Write to output
    CALL a20_wait_input
    MOV al, 0xD1
    OUT 0x64, al

    CALL a20_wait_input
    POP eax
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
    IN al, 0x64
    TEST al, 2
    JNZ a20_wait_input
    RET


; wait until status bit 1 is 1 so that it means it is free and we can read from it
a20_wait_output:
    IN al, 0x64
    TEST al, 1
    JZ a20_wait_output
    RET



print_string:
    MOV al, [si]        ; Load character in SI to AL and increments SI
    INC si

    CMP al, 0           ; Is the character NULL? Sets zero flag
    JE .done            ; If zero flag is set go to done
    
    MOV bh, 0           ; Tells you what page to print to
    MOV ah, 0x0E        ; Tells bios to give a teletype output
    INT 0x10            ; Interrupt prints the charcter stored in AL
    JMP print_string    ; Go to next character

.done:
    RET                 ; Return back to caller

message_hello db 'Inside starter...', 0x0D, 0x0A, 0
