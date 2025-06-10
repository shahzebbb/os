; bootloader.asm - 512 bytes boot sector

[org 0x7C00]      ; BIOS loads bootloader here

start:
    mov ah, 0x0E  ; teletype output function
    mov al, 'A'   ; character to print
    int 0x10      ; BIOS interrupt
    jmp $         ; infinite loop

times 510 - ($ - $$) db 0  ; pad to 510 bytes
dw 0xAA55                  ; boot signature
