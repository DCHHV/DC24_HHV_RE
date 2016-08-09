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


; Delay functions for the RE chalenge, tuned to a 4 MHz OSC.  These are all
; blocking delays because we don't care in this application.


EXTERN  TMP, TMP2

GLOBAL _delay_Wx10us, _delay_Wx1ms

CODE


; Clobbers global TMP and W register.
; Remains in same bank since TMP is in the Common RAM block
;
; Delays W*10us + 5us (call in, overhead, return)
;

_delay_Wx10us
    MOVWF   TMP

    GOTO    $+1
    GOTO    $+1
    GOTO    $+1
    NOP
    DECFSZ  TMP, F
    GOTO    $-5

    RETURN
    
; Clobbers global TMP and W register.
; Remains in same bank since TMP is in the Common RAM block
;
; Delays ((W*(1 ms + 5 us)) + 5 us) (call in, overhead, return)
;

_delay_Wx1ms
    MOVWF   TMP2
    
    MOVLW   .100
    CALL    _delay_Wx10us
    DECFSZ  TMP2, F
    GOTO    $-3

    RETURN

END

