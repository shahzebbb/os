ENTRY(start)
OUTPUT_FORMAT("binary")


SECTIONS
{
    . = 0x20000;

    .text : {
        *(.text)
    }

    .rodata : {
        *(.rodata*)
    }

    .data : {
        *(.data)
    }

    .bss : {
    __bss_start = .;
    *(.bss)
    __bss_end = .;
    }
}
