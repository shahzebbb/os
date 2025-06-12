BITS 16
org 0x7C00              ; BIOS loads bootloader here

main:
    ; Initialise ds and es segments to 0
    mov ax, 0x7C00
    mov sp, ax

    XOR ax, ax          
    MOV ds, ax
    MOV ss, ax

   

    MOV si, message             ; Load the address of the string into SI
    CALL print_string


    MOV ch, 0
    MOV dh, 0
    MOV cl, 2

    ; Set disk read destination memory to ES:BX = 0x0500:0000
    MOV bx, 0x0000

    MOV ah, 0x02
    MOV al, 1                   ; Read 1 sector

    pusha
    INT 0x13                    ; Call bios to read disk

    JNC success                ; If read was successful

    popa          

    JMP disk_error

    HLT


success:
    ; Sector loaded successfully
    popa
    JMP 0x0500:0000        ; Or continue to next logic

disk_error:
    MOV si, disk_error_message
    CALL print_string
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

message db 'Inside the bootloader...', 0x0D, 0x0A, 0
disk_error_message db  'Error reading disk', 0x0D, 0x0A, 0

times 510 - ($ - $$) db 0  ; pad to 510 bytes
dw 0xAA55                  ; boot signature
