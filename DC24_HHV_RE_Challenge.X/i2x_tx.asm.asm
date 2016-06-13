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

EXTERN  TMP, TMP2, ITR

GLOBAL  _tx_i2c_byte, _tx_i2c_start, _tx_i2c_stop

CODE

; Send I2C start bit, using RA5 and RA1 as clk and dat
;
; Expects the port to be set up already in OD mode as outputs
_tx_i2c_start
    BANKSEL LATA
    BCF     LATA, 1
    GOTO    $+1
    NOP
    BCF     LATA, 5
    RETURN

; Send I2C stop bit, using RA5 and RA1 as clk and dat
;
; Expects the port to be set up already in OD mode as outputs
; Expects clock and data to be low
_tx_i2c_stop
    BANKSEL LATA
    BSF     LATA, 5
    GOTO    $+1
    NOP
    BSF     LATA, 1
    RETURN

; Send a byte of I2C data, includes ACK clock, but we dont read it
; W, global TMP, ITR will be clobbered
;
; Expects clk and dat to be low here
_tx_i2c_byte
    BANKSEL LATA
    MOVWF   TMP
    MOVLW   .8
    MOVWF   ITR

    RLF     TMP, F          ; Mov MSB, through carry, to bit 0
    RLF     TMP, F
_byte_loop
    RLF     TMP, F          ; Next bit is in correct position
    MOVF    TMP, W
    ANDLW   B'00000010'
    IORWF   LATA, F
    BSF     LATA, 5
    GOTO    $+1
    BCF     LATA, 5
    BCF     LATA, 1

    DECFSZ  ITR
    GOTO    _byte_loop

    ; Send ACK
    BSF     LATA, 5
    GOTO    $+1
    NOP
    BCF     LATA, 5

    RETURN


END
