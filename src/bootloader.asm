BITS 16
org 0x7C00              ; BIOS loads bootloader here

main:
    ; Initialise stack
    mov ax, 0x7C00
    mov sp, ax

    ; Initialise other ds, ss and es segments to 0
    XOR ax, ax          
    MOV ds, ax
    MOV ss, ax
    MOV es, ax

    ; Save drive 
    mov [drive_number], dl

    ; Print a message to show you are inside the bootloader
    MOV si, message             ; Load the address of the string into SI
    CALL print_string

    ; Load sector 1 from disk
    MOV ax, 1                   ; Define which sector to load
    MOV bx, 0x7E00              ; Disk contents will be saved to 0x7E00
    CALL disk_read

    CLI
    HLT

    

; Function to convert LBA to CHS addresses using the following formulas:
; Cylinder = LBA / (HPC × SPT)
; Head     = (LBA / SPT) % HPC
; Sector   = (LBA % SPT) + 1
; 
; Inputs:
;   ax = LBA
; Outputs:
;   ch = cylinder
;   dh = head
;   cl = sector
convert_lba_to_chs:
    PUSH ax
    PUSH bx
    PUSH dx

    MOV bx, 18      ; Sectors Per Track = 18 (Hardcoded for now)
    XOR dx, dx      
    DIV bx          ; AX = LBA / SPT, DX =  LBA % SPT
    MOV cl, dl
    INC cl

    MOV bx, 2       ; Heads Per Cylinder = 2 (Hardcoded for now)
    XOR dx, dx
    DIV bx          ; AX = LBA / (SPT X HPC) DX = (LBA / SPT) % HPC

    MOV ch, al      ; Cylinder
    MOV dh, dl      ; Head

    POP dx
    POP bx
    POP ax
    RET

; Function to read from disk.
; Inputs:
;   ax - saves which sector to load in LBA addressing
;   es:bx - defines where to store the read in memory
disk_read:
    CALL convert_lba_to_chs
    MOV dl, [drive_number]
    mov si, 3   ; Iterator to try at most 3 times

.try_read:
    ; Setup BIOS disk read
    MOV ah, 0x02
    MOV al, 1                   ; Read 1 sector

    pusha
    INT 0x13                    ; Call bios to read disk

    JNC .success                ; If read was successful

    popa
    DEC si                      
    JNZ .try_read               ; Try again if read fails

    JMP .disk_error

.success:
    ; Sector loaded successfully
    popa
    JMP 0x0000:0x7E00       ; Or continue to next logic

.disk_error:
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
drive_number db 0

times 510 - ($ - $$) db 0  ; pad to 510 bytes
dw 0xAA55                  ; boot signature
