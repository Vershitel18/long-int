section         .text

                cpu             x64

                global          long_int_add


; adds two long numbers
;    rdi -- address of summand #1 (long number)
;    rsi -- address of summand #2 (long number)
;    rdx -- length of long numbers in qwords
; result:
;    sum is written to rdi
long_int_add:
                ret
