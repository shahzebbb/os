
#include <stdint.h>

void kernel_main(void) {
    volatile char* video = (volatile char*) 0xB8000;

    const char* msg = "Hello from kernel!";
    for (int i = 0; msg[i] != '\0'; ++i) {
        video[i * 2] = msg[i];       // Character byte
        video[i * 2 + 1] = 0x07;     // Attribute byte (light grey on black)
    }

    while (1);
}
