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

; These routines are tuned specifically to run with a 4 MHz clock, and output
; at UART settings of 38400 8n1, there is no RX to be found here, TX only.
;
; 38400 baud ends up with ~26.04166 us bit times.  4 MHz clock means instruction
; clock is 1 Mhz, which yields 1 us resolution.  26 us bit time is within 1%
; error rate and should work perfectly.

#include "p12f1571.inc"

EXTERN  TMP, TMP2, ITR

GLOBAL  _tx_uart_byte

CODE

; This requires the byte to be sent stored in W.
; W and global TMP, TMP2, IRT will be clobbered
;
; No IO is set up here, expected state is TX as a high output
; TX pin is at RA0, no ifs ands or butts
_tx_uart_byte
    MOVWF   TMP
    MOVLW   .8
    MOVWF   ITR
    ; Transmit start bit
    BANKSEL LATA
    BCF     LATA, 0
    CALL    _bit_delay
    CALL    $+1
    NOP

_byte_loop
    ; Start sending data, LSB first
    RRF     LATA, W
    MOVWF   TMP2
    RRF     TMP, F
    RLF     TMP2, W         ; Carry bit contains next TX bit
    MOVWF   LATA
    CALL    _bit_delay

    DECFSZ  ITR
    CALL    _byte_loop

    GOTO    $+1
    GOTO    $+1
    NOP
    ; Send stop bit
    BCF     LATA, 0
    CALL    _bit_delay
    GOTO    $+1
    GOTO    $+1
    GOTO    $+1
    GOTO    $+1
    NOP
    BSF     LATA, 0

    RETURN
    

; A non-clever delay just to add more code because why not
; We wait a total of 18 instructions, including the call and return.
; At the end of the 26th instruction the new line state is set
_bit_delay
    GOTO    $+1
    GOTO    $+1
    GOTO    $+1
    GOTO    $+1
    GOTO    $+1
    GOTO    $+1
    GOTO    $+1

    RETURN
    

END