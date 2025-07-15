
#include <stdint.h>
#include "vga.h"

void kernel_main(void) {
    clear_screen();
    print("Asalam O Aliekum, Dunya!\n");
    while (1);
}
