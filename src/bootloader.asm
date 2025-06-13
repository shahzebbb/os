BITS 16
org 0x7C00              ; BIOS loads bootloader here


;
; FAT12 header
; 
jmp short start
nop

bpb_oem:                         db 'MSWIN4.1'
bpb_bytes_per_sector:            dw 512
bpb_sectors_per_cluster:         db 1
bpb_reserved_sectors:            dw 1
bpb_fat_count:                   db 2
bpb_root_dir_count:              dw 0x0E0
bpb_total_sectors:               dw 2880
bpb_media_descriptor_type:       db 0x0F0
bpb_sectors_per_fat:             dw 9       
bpb_sectors_per_track:           dw 18          
bpb_heads_count:                 dw 2           ; Heads per cylinder
bpb_hidden_sectors:              dd 0
bpb_large_sector_count:          dd 0

; Extended Boot Record
ebr_drive_number:                db 0
                                 db 0
ebr_signature:                   db 0
ebr_volume_id:                   db 0x12, 0x34, 0x56, 0x78
ebr_volume_label:                db 'TOY OS     '
ebr_system_id:                   db 'FAT12   '



start:
    ; Initialise stack
    mov ax, 0x7C00
    mov sp, ax

    ; Initialise other ds, ss and es segments to 0
    XOR ax, ax          
    MOV ds, ax
    MOV ss, ax
    MOV es, ax

    ; Save drive 
    mov [ebr_drive_number], dl

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

    MOV bx, [bpb_sectors_per_track] 
    XOR dx, dx      
    DIV bx                               ; AX = LBA / SPT, DX =  LBA % SPT
    MOV cl, dl
    INC cl                               ; Sector

    MOV bx, [bpb_heads_count] 
    XOR dx, dx
    DIV bx                              ; AX = LBA / (SPT X HPC) DX = (LBA / SPT) % HPC

    MOV ch, al                          ; Cylinder
    MOV dh, dl                          ; Head

    POP ax
    MOV dl, al
    POP bx
    POP ax
    RET

; Function to read from disk.
; Inputs:
;   ax - saves which sector to load in LBA addressing
;   es:bx - defines where to store the read in memory
disk_read:
    CALL convert_lba_to_chs
    MOV dl, [ebr_drive_number]
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

message:            db 'Inside the bootloader...', 0x0D, 0x0A, 0
disk_error_message: db  'Error reading disk', 0x0D, 0x0A, 0

times 510 - ($ - $$) db 0  ; pad to 510 bytes
dw 0xAA55                  ; boot signature
