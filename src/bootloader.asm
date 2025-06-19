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


;
; Main function to run
; We use this function to jump into start.asm
;
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

    MOV si, file_kernel_bin      ; filename to search
    CALL load_file

    MOV dl, [ebr_drive_number]

    MOV ax, FILE_LOAD_SEGMENT
    MOV ds, ax
    MOV es, ax

    jmp FILE_LOAD_SEGMENT:FILE_LOAD_OFFSET

    CLI
    HLT


;
; Functions for reading fat12 files
;

; Function to load a file from a FAT12
; We first read the root directory into a buffer. 
; We then calculate if the file we are looking for can be found.
; If it is found we load the FAT table and read the file into memory at FILE_LOAD_SEGMENT:FILE_LOAD_OFFSET
; Inputs:
;   si - contains the name of the file. Cannot be bigger than 11 characters
; Outputs:
;   loads the file into memory at FILE_LOAD_SEGMENT:FILE_LOAD_OFFSET
load_file:
    PUSH si
    CALL read_root_dir
    POP si

    XOR bx, bx
    MOV di, buffer
    MOV cx, 11                   ; FAT name is 11 bytes

.loop_entries:
    PUSH di
    PUSH si
    PUSH cx

    REPE cmpsb

    POP cx
    POP si
    POP di
    JZ .file_found                  ; If file has been found (Zero flag set)

    ADD di, 32
    INC bx
    CMP bx, [bpb_root_dir_count]     ; Have we reached the end?
    JL .loop_entries                 ; If no, loop back

    JMP .file_not_found              ; If yes, then file not founded

.file_found:
    ; di should have the address to the entry
    MOV ax, [di + 26]                   ; first logical cluster field (offset 26)
    MOV [file_cluster], ax

    CALL read_fat_table

    ; read file and process FAT chain
    MOV bx, FILE_LOAD_SEGMENT
    MOV es, bx
    MOV bx, FILE_LOAD_OFFSET

    CALL load_file_into_memory
    RET

.file_not_found:
    mov si, msg_file_not_found
    call print_string
    RET


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
    MOV [root_dir_start], ax

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
    MOV [root_dir_size], al
    MOV cl, al                             ; Define how many sectors to load
    POP ax                                 ; Define which sector to load
    MOV bx, buffer                 ; Disk contents will be saved to 0x7E00
    CALL read_sector
    RET

; Read FAT table from disk
read_fat_table:
    ; load FAT from disk into memory in buffer
    MOV ax, [bpb_reserved_sectors]
    MOV bx, buffer
    MOV cl, [bpb_sectors_per_fat]
    MOV dl, [ebr_drive_number]
    call read_sector

    RET

; Loop to load file through cluster chaining
load_file_into_memory:
.load_loop:
    MOV ax, [file_cluster]

    CALL convert_cluster_to_lba         ; Loads the sector number to load into AX

    MOV cl, 1
    MOV dl, [ebr_drive_number]
    CALL read_sector

    ADD bx, [bpb_bytes_per_sector]

    ; compute location of next cluster
    MOV ax, [file_cluster]
    MOV cx, 3
    MUL cx                              ; AX = [file_cluster] * 3
    MOV cx, 2
    DIV cx                              ; AX = [file_cluster] * (3 / 2) since each cluster is 1.5 bytes
                                        ; DX = [file_cluster] % 2

    MOV si, buffer
    ADD si, ax
    MOV ax, [si]                        ; Read entry from FAT table at index AX

    OR dx, dx                           ; We need to check if odd or even because each cluster entry is 12 bits (1.5 bytes)
                                        ; So if even, it is only the first 12 bits out of the 16
                                        ; If odd, it is the upper 12 bits out of 16
    JZ .even

.odd:
    SHR ax, 4                           ; Keep upper 12-bits
    JMP .next_cluster

.even:
    AND ax, 0x0FFF                      ; Keep lower 12-bits

.next_cluster:
    CMP ax, 0x0FF8                      ; Check if end. If AX is >= 0x0FF8 then no more to read
    JAE .read_finish

    MOV [file_cluster], ax
    JMP .load_loop

.read_finish:
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

; This converts a cluster into its specified LBA (sectors).
; The formula to calculate is given as:
;   LBA = (cluster - 2) * sectors_per_cluster + start_sector
;   start_sector = reserved + fats + root_dir_size
; Inputs:
;   AX = Cluster
convert_cluster_to_lba:
    MOV cx, 2
    SUB ax, cx                              ; AX = cluster - 2
    MOV cx, [bpb_sectors_per_cluster]
    MUL cx                                  ; AX = (cluster - 2) * sectors_per_cluster
    ADD ax, [root_dir_start]                ; root_dir_start = reserved + fats
    ADD ax, [root_dir_size]                 ; AX = (cluster - 2) * sectors_per_cluster + start_sector

    RET

message:                   db 'Inside the bootloader...', 0x0D, 0x0A, 0
disk_error_message:        db 'Error reading disk', 0x0D, 0x0A, 0
file_kernel_bin:           db 'START   BIN'
msg_file_found:            db 'File found',  0x0D, 0x0A, 0
msg_file_not_found:        db 'File not found!!',  0x0D, 0x0A, 0

file_cluster:              dw 0
root_dir_start             dw 0
root_dir_size              db 0

FILE_LOAD_SEGMENT          equ 0x2000
FILE_LOAD_OFFSET           equ 0


times 510 - ($ - $$) db 0  ; pad to 510 bytes
dw 0xAA55                  ; boot signature

buffer:


