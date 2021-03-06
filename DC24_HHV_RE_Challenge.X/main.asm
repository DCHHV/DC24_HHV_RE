;The MIT License (MIT)
;
;Copyright (c) 2016 KBEmbedded
;
;This project is intended for use in the DEF CON 24 Hardware Hacking Village.
;The combined software and hardware creates a simple and basic reverse
;engineering challenge.
;
;Permission is hereby granted, free of charge, to any person obtaining a copy of
;this software and associated documentation files (the "Software"), to deal in
;the Software without restriction, including without limitation the rights to
;use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
;of the Software, and to permit persons to whom the Software is furnished to do
;so, subject to the following conditions:
;
;The above copyright notice and this permission notice shall be included in all
;copies or substantial portions of the Software.
;
;THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;SOFTWARE.

#include "p12f1571.inc"

__CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _BOREN_OFF & _CLKOUTEN_OFF
__CONFIG _CONFIG2, _WRT_OFF & _PLLEN_OFF & _STVREN_OFF & _LPBOREN_OFF & _LVP_OFF

#DEFINE ROMFIXUP        0 ; State flag: ROM address
#DEFINE JUMPER          1 ; State flag: PCB jumper
#DEFINE CIPHER          2 ; State flag: Cipher, OTHER pin to TX
#DEFINE UART            3 ; State flag: UART, I2C pins short

EXTERN  _delay_Wx10us, _tx_uart_byte, _tx_i2c_start, _tx_i2c_stop, _tx_i2c_byte, _delay_Wx1ms
GLOBAL  TMP, TMP2, ITR

; Global RAM locations
GLOB    UDATA_SHR   0x70
    TMP         RES .1
    TMP2        RES .1
    STATE       RES .1
    COUNT       RES .1
    ITR         RES .1
    OFFS        RES .1


RST_VECTOR CODE 0x0000

    GOTO _start

INT_VECTOR CODE 0x0004

    RETFIE


_start
; Start off by testing all of the point possibilities. The order of testing is
; important for the sequenced steps.
;
; Drive RA0 (TX) low and see if RA3 (OTHER) follows
;   If so, then thats 2 points completed
;   Now on radio silence for main loop
; Otherwise, drive RA5 (I2C_CLK) low, and see if RA1 (I2C_DAT) follows
;   If not, then thats 1 point completed
;   Now outputting key on UART, and ciphertext on I2C
; Check 0xZZZZ for correct value
;   If so, then one point completed
; Check RA2 (JUMPER)
;   If so, then one point completed

_pin_init
    BANKSEL LATA
    MOVLW   B'00110011'     ; Set LED, I2C, and TX high
    MOVWF   LATA
    BANKSEL TRISA
    BCF	    TRISA, 0	    ; Let TX be low so we get a 0
    BANKSEL ANSELA
    CLRF    ANSELA
    BANKSEL OPTION_REG
    BCF     OPTION_REG, 7
    
    ; Set OSC to 4 MHz
    BANKSEL OSCCON
    MOVLW   B'01101000'
    MOVWF   OSCCON
    
    BANKSEL LATA
    BCF	    LATA, 0
    
    ; Delay 220 us to let everything stabilize, appears as UART NULL
    MOVLW   .22
    CALL    _delay_Wx10us
    BANKSEL LATA
    BSF	    LATA, 0
    
    BANKSEL ODCONA
    MOVLW   B'00100010'     ; Enable OD outputs on I2C pins
    MOVWF   ODCONA

    CLRF    STATE
    MOVLW   .4
    MOVWF   COUNT
    MOVLW   0x42
    MOVWF   ITR

    ; Delay 1 ms to let everything stabilize
    MOVLW   .100
    CALL    _delay_Wx10us

; First, check to see if the cipher has been decoded.
; This would result in RA0 and RA3 tied together.
; Here, we drive TX and leave OTHER alone, since OTHER is the "secret" part
; Like this, it just looks like bad programming on the TX line ;)
; If this is complete, we skip past I2C checks since surely thats done.

_check_cipher
    BANKSEL PORTA
    BTFSS   PORTA, 3
    GOTO    _check_i2c

    ; Set TX to an output, which is now low
    BANKSEL LATA
    BCF     LATA, 0

    ; Delay 220 us, should register as UART NULL
    MOVLW   .22
    CALL    _delay_Wx10us

    ; Save PORTA, and set TX back high since thats UART idle
    BANKSEL PORTA
    MOVF    PORTA, W
    MOVWF   TMP
    BANKSEL LATA
    BSF     LATA, 0
    BTFSC   TMP, 3
    GOTO    _check_i2c

    ; Score points and mark the state bits as completed
    BSF     STATE, UART
    BSF     STATE, CIPHER
    MOVLW   .2
    SUBWF   COUNT, F
    GOTO    _check_rom

; If cipher has not been completed, lets see if the plain UART has been.
; Cutting the trace between I2C CLK and DAT marks plain UART complete.
; If the pins are shorted, there is only a blip seen on the output on each pin.
_check_i2c
    ; Set I2C pins to output, already as OD, and LATA has them high
    BANKSEL TRISA
    BCF     TRISA, 5
    BCF     TRISA, 1

    ; Delay 100 us
    MOVLW   .10
    CALL    _delay_Wx10us

    ; Verify I2C bus state before continuing
    BANKSEL PORTA
    BTFSS   PORTA, 5
    GOTO    _check_rom

    BTFSS   PORTA, 1
    GOTO    _check_rom

    ; I2C clock to go low, invalid bus state
    BANKSEL LATA
    BCF     LATA, 5

    ; Delay 100 us
    MOVLW   .10
    CALL    _delay_Wx10us

    ; Save PORTA status, set CLK back high, and check saved DAT status
    BANKSEL PORTA
    MOVF    PORTA, W
    MOVWF   TMP
    BANKSEL LATA
    BSF     LATA, 5
    BTFSS   TMP, 1
    GOTO    _check_rom

    ; Score points and mark state bits as completed
    BSF     STATE, UART
    DECF    COUNT, F
    
    GOTO    _check_rom

; The secret byte is just a marker, the default value of 0xAA is pretty obvious
; This placeholder is checked to see if its changed.
SECRET_BYTE  
    BRW
    DT	0xAA

; Mega secret is printed nowhere by anything and just sits in ROM.
; The decode process must the followed via other means to reveal what it says.
; This is not a part of the main challenge, and is just a side quest.
; It just says "Tell l33tbunni that you found the 'mega secret'"
MEGA_SECRET
    BRW
    DT	0x31, 0xB, 0xF, 0x24, 0x70, 0x60, 0x74, 0x64, 0x6D, 0x7A, 0x2A, 0x6A
    DT	0x6B, 0x68, 0x63, 0x28, 0x30, 0x74, 0x7A, 0x67, 0x34, 0x71, 0x78, 0x62
    DT	0x77, 0x7F, 0x3A, 0x6E, 0x73, 0x64, 0x3E, 0x6B, 0x41, 0x49, 0x56, 0x3
    DT	0x4D, 0x4B, 0x48, 0x52, 0x4A, 0x5D, 0x19, 0x18, 0x40, 0xD, 0x42, 0x43
    DT	0x55, 0x65

; The following three are all printed via UART or I2C at various times.
; This just uses a simple BRW jump table.  The first byte has the number of
; bytes to follow. The next X bytes are the string in reverse order.
; The printing functions start at byte[X], then byte[X-1], etc.
; All of the bytes are also XORed against X.
; Final printed byte is (byte[X]^X)

; "Cut the short between pins 2 and 6"
UART_PLAIN
    BRW
    DT	0x24, 0xB, 0xF, 0x35, 0x24, 0x61, 0x68, 0x66, 0x28, 0x3B, 0x2A, 0x78
    DT	0x62, 0x64, 0x7E, 0x2F, 0x7E, 0x74, 0x77, 0x64, 0x60, 0x70, 0x74, 0x37
    DT	0x6C, 0x6B, 0x75, 0x73, 0x6F, 0x3D, 0x7B, 0x77, 0x54, 0x1, 0x56, 0x56
    DT	0x67

; "AWXJDQVLTORGIBUYEPKNMZFSHC"
UART_CIPHERKEY
    BRW
    DT	0x1C, 0xB, 0xF, 0x40, 0x4C, 0x56, 0x40, 0x5D, 0x45, 0x47, 0x41, 0x5B
    DT	0x49, 0x54, 0x5B, 0x4D, 0x59, 0x56, 0x40, 0x5C, 0x40, 0x59, 0x40, 0x46
    DT	0x5C, 0x53, 0x42, 0x4C, 0x5D

; "Klupn ytbk qump abj kdzdb"
I2C_CIPHERTEXT
    BRW
    DT	0x1C, 0xB, 0xF, 0x61, 0x60, 0x7F, 0x62, 0x6C, 0x28, 0x63, 0x68, 0x6A
    DT	0x2C, 0x7D, 0x63, 0x7A, 0x61, 0x31, 0x79, 0x71, 0x60, 0x6C, 0x36, 0x79
    DT	0x68, 0x6C, 0x76, 0x50, 0x1C
    
; This string is just a clue as to the secret_byte puzzle above.
PLAIN_STRING
    BRW
    DT	"Change ROM byte 0x9B from 0xAA to 0x42"

; Actually check the ROM location secret byte, and see if the value is 0x42
; The compare is against ITR, unused up to this point, loaded earlier in code.
_check_rom
    CLRW
    CALL    SECRET_BYTE
    SUBWF   ITR, W
    
    BTFSS   STATUS, Z
    GOTO    _check_jumper
    
    BSF	    STATE, ROMFIXUP
    DECF    COUNT, F

; Check that the jumper has been opened
_check_jumper
    BANKSEL PORTA
    BTFSS   PORTA, 2
    GOTO    _uart_stage

    ; Check if the point has already been counted
    BTFSC   STATE, JUMPER
    GOTO    _uart_stage

    ; If not, then score it
    BSF     STATE, JUMPER
    DECF    COUNT

; Here we print out either the plaintext clue, or the ciphertext key
_uart_stage
    ; See if CIPHER has been completed
    BTFSC   STATE, CIPHER
    GOTO    _blink_LED

    ; See if UART has been completed
    BTFSC   STATE, UART
    GOTO    _uart_cipherkey

    CLRW
    CALL    UART_PLAIN
    MOVWF   OFFS
    
_uart_plain_loop
    MOVF    OFFS, W
    CALL    UART_PLAIN
    XORWF   OFFS, W
    CALL    _tx_uart_byte
    DECFSZ  OFFS
    GOTO    _uart_plain_loop

    GOTO    _blink_LED

_uart_cipherkey
    CLRW
    CALL    UART_CIPHERKEY
    MOVWF   OFFS

_uart_cipherkey_loop
    MOVF    OFFS, W
    CALL    UART_CIPHERKEY
    XORWF   OFFS, W
    CALL    _tx_uart_byte
    DECFSZ  OFFS
    GOTO    _uart_cipherkey_loop

; If the plain UART has been solved, and hte I2C pins are not shorted,
; output the cihphertext on them.
; Accomplished by an I2C write to address 0x0. ACK is ignored, and actually
; driven here by us as the master to simplify programming.
_i2c_stage
    CLRW
    CALL    I2C_CIPHERTEXT
    MOVWF   OFFS
    CALL    _tx_i2c_start
    
_i2c_ciphertext_loop
    MOVF    OFFS, W
    CALL    I2C_CIPHERTEXT
    XORWF   OFFS, W
    CALL    _tx_i2c_byte
    DECFSZ  OFFS
    GOTO    _i2c_ciphertext_loop
    
    CALL    _tx_i2c_stop

; Blink the led a number of times indicating the number of challenges left, 
; then pause and reboot running the whole process all over again.
; If all completed, turn the LED on and go to sleep.
_blink_LED
    BANKSEL TRISA
    BCF	    TRISA, 4
    MOVLW   .0
    SUBWF   COUNT, W
    BTFSS   STATUS, Z
    GOTO    _blink_loop
    
    BANKSEL LATA
    BCF	    LATA, 4
    
    SLEEP
    
_blink_loop
    BANKSEL LATA
    BCF	    LATA, 4
    MOVLW   .255
    CALL    _delay_Wx1ms
    BSF	    LATA, 4
    MOVLw   .255
    CALL    _delay_Wx1ms
    DECFSZ  COUNT
    GOTO    _blink_loop
    
    MOVLW   .255
    CALL    _delay_Wx1ms
    MOVLW   .255
    CALL    _delay_Wx1ms
    MOVLW   .255
    CALL    _delay_Wx1ms
    MOVLW   .255
    CALL    _delay_Wx1ms
    
    RESET

END
