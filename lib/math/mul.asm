section         .text

                cpu             x64

                global          long_int_mul


; multiplies two long numbers
;    rdi -- address of multiplier #1 (long number)
;    rsi -- address of multiplier #2 (long number)
;    rdx -- location for product (2x long number)
;    rcx -- length of long numbers in qwords
; result:
;    product is written to rdx
long_int_mul:
                ret
