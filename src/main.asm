BITS 16
ORG 0x5000

main:
    MOV si, message             ; Load the address of the string into SI
    CALL print_string

    MOV si, message             ; Load the address of the string into SI
    CALL print_string

    CLI
    HLT

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

message db 'Inside sector 1...', 0x0D, 0x0A, 0
times 510 - ($ - $$) db 0  ; pad to 510 bytes
