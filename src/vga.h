#pragma once

#define COLOUR_BLACK 0
#define COLOUR_WHITE 15
#define COLOUR_LIGHT_GREY 7

#define WIDTH 80
#define HEIGHT 25

void print(const char* s);
void scroll(void);
void clear_screen(void);
void new_line(void);
void vga_putchar(char c);


