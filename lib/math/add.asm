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
                clc
.loop:
                mov             r9, [rsi]
                adc             [rdi], r9
                lea             rdi, [rdi + 8]
                lea             rsi, [rsi + 8]
                dec             rdx
                jnz             .loop
                ret
