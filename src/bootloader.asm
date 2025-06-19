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

    CALL read_root_dir

    MOV si, file_kernel_bin      ; filename to search
    MOV cx, 11                   ; FAT name is 11 bytes
    CALL read_file
    ; Load sector 1 from disk
    ; MOV ax, 1                   ; Define which sector to load
    ; MOV cl, 1                   ; Define how many sectors to load
    ; MOV bx, 0x7E00              ; Disk contents will be saved to 0x7E00
    ; CALL read_sector
    ; JMP 0x0000:0x7E00

    CLI
    HLT

; Function to read the root directory on FAT12.
; The root directory stores information on each file on the disk
; This functions loads all bpb_root_dir_count entries into memory.
; The formula to calculate LBA of root dir is:
;   LBA = reserved_sector + fat_count * sectors_per_fat
; The formula to calculate the size of root_dir in sectors is:
;   size = (root_dir_count * 32) / bytes_per_sector
; Outputs:
read_root_dir:
    ; First we will calculate the LBA of the root_dir
    MOV ax, [bpb_sectors_per_fat] 
    MOV bl, [bpb_fat_count]
    XOR bh, bh 

    MUL bx                               ; AX = fat_count * sectors_per_fat
    ADD ax, [bpb_reserved_sectors]       ; AX = LBA = reserved_sector + fat_count * sectors_per_fat

    PUSH ax

    ; Now we will calulate the number of sectors the root_dir holds
    MOV ax, [bpb_root_dir_count]
    SHL ax, 5                              ; AX *= 32, AX = root_dir_count * 32
    XOR dx, dx
    DIV word [bpb_bytes_per_sector]

    TEST dx, dx                            ; if dx != 0, add 1
    JZ .read
    INC ax                                 ; Meaning we have a sector partially filled which is why need to add 1

.read:
    ; Now we finally call read_sector to read the root_dir into memory
    MOV cl, al                             ; Define how many sectors to load
    POP ax                                 ; Define which sector to load
    MOV bx, root_dir_start                 ; Disk contents will be saved to 0x7E00
    CALL read_sector
    RET


; Function to read the root directory on FAT12.
; The root directory stores information on each file on the disk
; This functions loads all bpb_root_dir_count entries into memory.
; The formula to calculate LBA of root dir is:
;   LBA = reserved_sector + fat_count * sectors_per_fat
; The formula to calculate the size of root_dir in sectors is:
;   size = (root_dir_count * 32) / bytes_per_sector
; Outputs:
read_file:
    MOV ax, [bpb_root_dir_count]
    SHL ax, 5                              ; AX *= 32, AX = root_dir_count * 32
    XOR dx, dx
    DIV word [bpb_bytes_per_sector]
    TEST dx, dx                            ; if dx != 0, add 1
    JZ .calculate_root_dir_end
    INC ax    

.calculate_root_dir_end:
    SHL ax, 9                              ; AX *= 512
    ADD ax, root_dir_start
    MOV di, root_dir_start

.loop_entries:
    CMP di, ax     ; have we reached the end?
    JAE .file_not_found     ; if so, exit

    PUSH di
    PUSH si
    PUSH cx

    REPE cmpsb

    POP cx
    POP si
    POP di
    JZ .file_found

    PUSH si
    mov si, message
    call print_string
    POP si

    ADD di, 32
    JMP .loop_entries

.file_found:
    mov si, msg_file_found
    call print_string
    RET

.file_not_found:
    mov si, msg_file_not_found
    call print_string
    RET




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
    PUSH bx
    PUSH dx

    XOR dx, dx      
    DIV word [bpb_sectors_per_track]     ; AX = LBA / SPT, DX =  LBA % SPT
    MOV cl, dl
    INC cl                               ; Sector

    XOR dx, dx
    DIV word [bpb_heads_count]           ; AX = LBA / (SPT X HPC) DX = (LBA / SPT) % HPC

    MOV ch, al                          ; Cylinder
    SHL ah, 6
    OR cl, ah                           ; put upper 2 bits of cylinder in CL

    MOV dh, dl                          ; Head

    POP ax
    MOV dl, al
    POP bx
    RET

; Function to read a sector from FAT12 disk.
; Inputs:
;   ax - saves which sector to load in LBA addressing
;   cl - saves number of sectors to load
;   es:bx - defines where to store the read in memory
read_sector:
    PUSH cx
    CALL convert_lba_to_chs
    POP ax                  ; Now AL = Number of sectors to read
    MOV dl, [ebr_drive_number]
    mov si, 3   ; Iterator to try at most 3 times

.try_read:
    ; Setup BIOS disk read
    MOV ah, 0x02

    pusha
    INT 0x13                    ; Call bios to read disk

    JNC .success                ; If read was successful

    POPA
    DEC si                      
    JNZ .try_read               ; Try again if read fails

    JMP .disk_error

.success:
    ; Sector loaded successfully
    POPA
    RET     

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

message:                   db 'Inside the bootloader...', 0x0D, 0x0A, 0
disk_error_message:        db  'Error reading disk', 0x0D, 0x0A, 0
file_kernel_bin:           db 'KERNEL  BIN'
msg_file_found:            db 'File found',  0x0D, 0x0A, 0
msg_file_not_found:        db 'File not found!!',  0x0D, 0x0A, 0

times 510 - ($ - $$) db 0  ; pad to 510 bytes
dw 0xAA55                  ; boot signature
root_dir_start:
