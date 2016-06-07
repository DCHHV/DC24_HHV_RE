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

__CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_ON & _MCLRE_OFF & _CP_OFF & _BOREN_OFF & _CLKOUTEN_OFF
__CONFIG _CONFIG2, _WRT_OFF & _PLLEN_OFF & _STVREN_OFF & _LPBOREN_OFF & _LVP_OFF

#DEFINE ROMFIXUP        0 ; State flag: ROM address
#DEFINE JUMPER          1 ; State flag: PCB jumper
#DEFINE CIPHER          2 ; State flag: Cipher, OTHER pin to TX
#DEFINE UART            3 ; State flag: UART, I2C pins short

EXTERN  _delay_Wx10us, _tx_uart_byte
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
    BANKSEL PORTA
    CLRF    PORTA
    BANKSEL LATA
    MOVLW   B'00110010'     ; Set LED and I2C high
    MOVWF   LATA
    BANKSEL ANSELA
    CLRF    ANSELA
    BANKSEL OPTION_REG
    BCF     OPTION_REG, 7
    BANKSEL ODCONA
    MOVLW   B'00100010'     ; Enable OD outputs on I2C pins
    MOVWF   ODCONA

    CLRF    STATE
    MOVLW   .4
    MOVWF   COUNT

    ; Set OSC to 4 MHz
    BANKSEL OSCCON
    MOVLW   B'01101000'
    MOVWF   OSCCON

    ; Delay 100 us to let everything stabilize
    MOVLW   .100
    CALL    _delay_Wx10us

_check_pins

_check_cipher
    BANKSEL PORTA
    BTFSS   PORTA, 3
    GOTO    _check_i2c

    ; Drive TX and see if OTHER follows.
    ; We drive TX because this way it looks like a programing glitch and its
    ; misdirection from OTHER being a vital pin.
    BANKSEL TRISA
    BCF     TRISA, 0         ; Set TX to an output, which is now low

    ; Delay 100 us
    MOVLW   .100
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
    SUBWF   COUNT, F        ; Update count number, should be 2 here
    GOTO    _check_rom      ; We don't even worry about I2C because its surely
                            ; completed.

_check_i2c
    ; Set I2C pins to output, already as OD, and LATA has them high
    BANKSEL TRISA
    BCF     TRISA, 5
    BCF     TRISA, 1

    ; Delay 100 us
    MOVLW   .100
    CALL    _delay_Wx10us

    ; Verify I2C bus state before continuing
    BANKSEL PORTA
    BTFSS   PORTA, 5
    GOTO    _check_rom

    BTFSS   PORTA, 1
    GOTO    _check_rom

    BANKSEL LATA
    BCF     LATA, 5         ; I2C OD clock to go low, invalid bus state

    ; Delay 100 us
    MOVLW   .100
    CALL    _delay_Wx10us

    ; Save PORTA status, set CLK back high
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



_check_rom
    ; Test for address set at ROM location
    ; XXX

_check_jumper
    ; Test for JUMPER
    BANKSEL PORTA
    BTFSC   PORTA, 2
    GOTO    _uart_stage

    ; Check if the point has already been counted
    BTFSC   STATE, JUMPER
    GOTO    _uart_stage

    ; If not, then score it
    BSF     STATE, JUMPER
    DECF    COUNT

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
    ; Insert de-obfuscation here
    CALL    _tx_uart_byte
    DECFSZ  OFFS
    GOTO    _uart_plain_loop

    GOTO    _blink_LED

_uart_cipherkey
    CLRW
    CALL    UART_PLAIN
    MOVWF   OFFS

_uart_cipherkey_loop
    MOVF    OFFS, W
    CALL    UART_CIPHERKEY
    ; Insert de-obfuscation here
    CALL    _tx_uart_byte
    DECFSZ  OFFS
    GOTO    _uart_cipherkey_loop

_i2c_stage

    CLRW
    CALL    I2C_CIPHERTEXT
    MOVWF   OFFS

    CALL    _tx_i2c_start
_i2c_ciphertext_loop
    MOVF    OFFS, W
    CALL    I2C_CIPHERTEXT
    ; Insert de-obfuscation here
    CALL    _tx_i2c_byte
    DECFSZ  OFFS
    GOTO    _i2c_ciphertext
    

_blink_LED

    ; Blink LED a number of times based on COUNT

    ; Reset here


MEGA_SECRET
    BRW
    DT  .23, "\n\rTell l33tbunni that you found the 'mega secret'"

UART_PLAIN
    BRW
    DT  .23, "\n\rgnirts gnol a gnitseT"

UART_CIPHERKEY
    BRW
    DT  .28, "\n\rABCDEFGHIJKLMNOPQRSTUVWXYZ"

I2C_CIPHERTEXT
    BRW
    DT  .26, "\n\rdetpyrcne eb dluow sihT", 0x0

END