#include <stdint.h>
#include "vga.h"

uint16_t column = 0;
uint16_t row = 0;
uint16_t* vga_pointer = (uint16_t*) 0xB8000;
uint16_t default_colour = (COLOUR_WHITE << 8) | (COLOUR_BLACK << 12);

void clear_screen(void) 
{
    column = 0;
    row = 0;

    for (uint16_t y = 0; y < HEIGHT; y++)
    {
        for (uint16_t x = 0; x < WIDTH; x++)
        {
            vga_pointer[y * WIDTH + x] = ' ' | default_colour;
        }
    }
}

void new_line(void) 
{
    if (row < HEIGHT - 1)
    {
        row++;
        column = 0;
    } else
    {
        scroll();
        column = 0;
    }
}

void scroll(void) 
{
    for (uint16_t y = 1; y < HEIGHT; y++)
    {
        for (uint16_t x = 0; x < WIDTH; x++)
        {
            vga_pointer[(y-1) * WIDTH + x] = vga_pointer[y * WIDTH + x];
        }
    }

    for (uint16_t x = 0; x < WIDTH; x++)
    {
        vga_pointer[(HEIGHT - 1) * WIDTH + x]  = ' ' | default_colour;
    }
}

void print(const char* s)
{
    while (*s)
    {
        switch (*s)
        {
            case '\n':
                new_line();
                break;
            default:
                if (column == WIDTH)
                {
                    new_line();
                }
                vga_pointer[row * WIDTH + (column++)] = *s | default_colour;
                break;
        }
        s++;   
    }
}


