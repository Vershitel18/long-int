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
                clc
.loop:
                mov             r9, [rsi]
                sbb             [rdi], r9
                lea             rdi, [rdi + 8]
                lea             rsi, [rsi + 8]
                dec             rdx
                jnz             .loop
ret
