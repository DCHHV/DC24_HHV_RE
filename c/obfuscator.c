/*
*The MIT License (MIT)
*
*Copyright (c) 2016 KBEmbedded
*
*This project is intended for use in the DEF CON 24 Hardware Hacking Village.
*The combined software and hardware creates a simple and basic reverse
*engineering challenge.
*
*Permission is hereby granted, free of charge, to any person obtaining a copy of
*this software and associated documentation files (the "Software"), to deal in
*the Software without restriction, including without limitation the rights to
*use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
*of the Software, and to permit persons to whom the Software is furnished to do
*so, subject to the following conditions:
*
*The above copyright notice and this permission notice shall be included in all
*copies or substantial portions of the Software.
*
*THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
*IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
*FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
*AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
*LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
*OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*SOFTWARE.
*/

/*
*Usage:
*
*./obfuscator <string>
*
*Outputs a formatted series of bytes that can be used as part of the PIC code
*/ 
#define MAXLEN 512
#include <stdio.h>
#include <string.h>

int main(int argc, char** argv)
{
	unsigned int cnt, i;

	cnt = strlen(argv[1]);

	printf("0x%X, 0x%X, 0x%X", cnt+2, (0xA^1), (0xD^2));
	for(i = 3; cnt ; cnt--) {
		printf(", 0x%X", (argv[1][cnt-1] ^ i++));
	}
	printf("\n");

	return 0;
}
