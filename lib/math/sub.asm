section         .text

                cpu             x64

                global          long_int_sub


; subtracts two long numbers
;    rdi -- address of minuend (long number)
;    rsi -- address of subtrahend (long number)
;    rdx -- length of long numbers in qwords
; result:
;    difference is written to rdi
long_int_sub:
                ret
