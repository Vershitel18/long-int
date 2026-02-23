section         .text

                cpu             x64

                global          long_int_read
                global          long_int_write

                extern          long_int_set_zero
                extern          long_int_is_zero
                extern          long_int_add_short
                extern          long_int_mul_short
                extern          long_int_div_short


SYS_READ:       equ             0
SYS_WRITE:      equ             1
SYS_EXIT:       equ             60

FD_STDIN:       equ             0
FD_STDOUT:      equ             1
FD_STDERR:      equ             2

EXIT_FAILURE:   equ             1


; reads one char from stdin
; result:
;    rax == -1 if error occurs
;    rax \in [0; 255] if OK
read_char:
                mov             rax, SYS_READ
                mov             rdi, FD_STDIN
                lea             rsi, [rsp - 1]
                mov             rdx, 1
                syscall

                cmp             rax, 1
                jne             .error
                xor             rax, rax
                mov             al, [rsi]
                ret

.error:
                mov             rax, -1
                ret


; writes a string to stdout, errors are ignored
;    rdi -- string
;    rsi -- size
write_string:
                mov             rdx, rsi
                mov             rsi, rdi
                mov             rax, SYS_WRITE
                mov             rdi, FD_STDOUT
                syscall

                ret


; writes one char to stdout, errors are ignored
;    dl -- char
write_char:
                lea             rdi, [rsp - 1]
                mov             [rdi], dl

                mov             rsi, 1
                jmp             write_string


; exits the process with code EXIT_FAILURE
exit_on_error:
                mov             rax, SYS_EXIT
                mov             rdi, EXIT_FAILURE
                syscall


; reads a long number from stdin
;    rdi -- location for input (long number)
;    rsi -- length of long number in qwords
long_int_read:
                push            rbx
                push            r12
                push            r13
                mov             rbx, rdi        ; input
                mov             r12, rsi        ; length in qwords

                call            long_int_set_zero
.loop:
                call            read_char
                test            rax, rax
                js              exit_on_error

                cmp             al, `\n`
                je              .done
                sub             al, '0'
                cmp             al, 9
                ja              .invalid_char
                mov             r13, rax        ; remember current digit

                mov             rdi, rbx
                mov             rsi, 10
                mov             rdx, r12
                call            long_int_mul_short

                mov             rdi, rbx
                mov             rsi, r13
                mov             rdx, r12
                call            long_int_add_short

                jmp             .loop

.done:
                pop            r13
                pop            r12
                pop            rbx
                ret

.invalid_char:
                mov             bl, al
                mov             rdi, invalid_char_msg
                mov             rsi, INVALID_CHAR_MSG_LEN
                call            write_string
                mov             dl, bl
                call            write_char
                mov             dl, `\n`
                call            write_char
                jmp             exit_on_error


; writes a long number to stdout
;    rdi -- argument (long number)
;    rsi -- length of long number in qwords
long_int_write:
                push            rbp
                push            rbx
                push            r12
                push            r13

                ; reserve space for up to 20*N characters, where 20 is ceil(log10(2^64))
                lea             rax, [rsi * 4 + rsi]
                lea             rax, [rax * 4]
                mov             rbp, rsp        ; remember rsp
                sub             rsp, rax
                and             rsp, -16        ; ensuring stack alignment

                mov             r12, rdi        ; argument
                mov             r13, rsi        ; length in qwords

                lea             rbx, [rbp - 1]  ; string iterator
                mov             [rbx], BYTE `\n`

.loop:
                mov             rdi, r12
                mov             rsi, 10
                mov             rdx, r13
                call            long_int_div_short
                add             al, '0'
                dec             rbx
                mov             [rbx], al

                mov             rdi, r12
                mov             rsi, r13
                call            long_int_is_zero
                test            al, al
                jz             .loop

                mov             rdi, rbx
                mov             rsi, rbp
                sub             rsi, rbx
                call            write_string

                mov             rsp, rbp

                pop             r13
                pop             r12
                pop             rbx
                pop             rbp
                ret


                section         .rodata
invalid_char_msg:
                db              "Invalid character: "
INVALID_CHAR_MSG_LEN: \
                equ             $ - invalid_char_msg
