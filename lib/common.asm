section         .text

                cpu             x64

                global          long_int_set_zero
                global          long_int_is_zero
                global          long_int_add_short
                global          long_int_mul_short
                global          long_int_div_short


; assigns zero to a long number
;    rdi -- argument (long number)
;    rsi -- length of long number in qwords
long_int_set_zero:
                mov             rcx, rsi
                xor             rax, rax
                rep stosq
                ret


; checks if a long number is zero
;    rdi -- argument (long number)
;    rsi -- length of long number in qwords
; result:
;    rax == 1 if zero, rax == 0 otherwise
long_int_is_zero:
                mov             rcx, rsi
                xor             rax, rax
                rep scasq
                sete            al
                ret


; adds a short number to a long number
;    rdi -- address of summand #1 (long number)
;    rsi -- summand #2 (64-bit unsigned)
;    rdx -- length of long number in qwords
; result:
;    sum is written to rdi
long_int_add_short:
.loop:
                add             [rdi], rsi
                setc            sil
                movzx           esi, sil
                add             rdi, 8
                dec             rdx
                jnz             .loop

                ret


; multiplies a long number by a short number
;    rdi -- address of multiplier #1 (long number)
;    rsi -- multiplier #2 (64-bit unsigned)
;    rdx -- length of long number in qwords
; result:
;    product is written to rdi, carry is written to rax
long_int_mul_short:
                mov             rcx, rdx        ; countdown
                xor             r11, r11        ; carry
.loop:
                mov             rax, [rdi]
                mul             rsi
                add             rax, r11
                adc             rdx, 0
                mov             r11, rdx
                mov             [rdi], rax
                add             rdi, 8
                dec             rcx
                jnz             .loop

                mov             rax, r11
                ret


; divides a long number by a short number
;    rdi -- address of dividend (long number)
;    rsi -- divisor (64-bit unsigned)
;    rdx -- length of long number in qwords
; result:
;    quotient is written to rdi
;    remainder is returned in rax
long_int_div_short:
                mov             rcx, rdx

                lea             rdi, [rdi + 8 * rcx - 8]
                xor             rdx, rdx

.loop:
                mov             rax, [rdi]
                div             rsi
                mov             [rdi], rax
                sub             rdi, 8
                dec             rcx
                jnz             .loop

                mov             rax, rdx
                ret
