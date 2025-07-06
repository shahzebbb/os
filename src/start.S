.code16

.section .text
.globl start
.extern kernel_main

start:
    cli
    call enable_A20
    call load_gdt

    mov %cr0, %eax
    or $1, %al
    mov %eax, %cr0

    data32 ljmp $0x08, $1f
    hlt

.code32
1:
    mov $0x10, %eax
    mov %eax, %ds
    mov %eax, %ss

    mov $0x90000, %esp
    call kernel_main

.hang:
    hlt
    jmp .hang

.code16
enable_A20:
    call a20_wait_input
    mov $0xAD, %al
    out %al, $0x64

    call a20_wait_input
    mov $0xD0, %al
    out %al, $0x64

    call a20_wait_output
    in $0x60, %al
    push %ax

    call a20_wait_input
    mov $0xD1, %al
    out %al, $0x64

    call a20_wait_input
    pop %ax
    or $2, %al
    out %al, $0x60

    call a20_wait_input
    mov $0xAE, %al
    out %al, $0x64

    call a20_wait_input
    ret

.code16
a20_wait_input:
    in $0x64, %al
    test $2, %al
    jnz a20_wait_input
    ret

a20_wait_output:
    in $0x64, %al
    test $1, %al
    jz a20_wait_output
    ret

.code16
load_gdt:
    data32 addr32 lgdt gdtdesc - 0x20000
    ret

.section .data
.align 8
gdt:
	.quad 0x0000000000000000	# Null segment.  Not used by CPU.
	.quad 0x00cf9a000000ffff	# System code, base 0, limit 4 GB.
	.quad 0x00cf92000000ffff        # System data, base 0, limit 4 GB.

gdtdesc:
	.word	gdtdesc - gdt - 1	# Size of the GDT, minus 1 byte.
	.long	gdt			# Address of the GDT.
