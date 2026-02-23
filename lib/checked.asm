                section         .text

                cpu             x64

                global          long_int_add_checked
                global          long_int_sub_checked
                global          long_int_mul_checked

                extern          long_int_add
                extern          long_int_sub
                extern          long_int_mul


POISON:         equ             0xDEADBEEFDEADBEEF


%macro          verify_reg      3

                mov             rcx, %2
                cmp             %1, rcx
                je              %%skip
                or              rax, %3
%%skip:

%endmacro


; checks ABI conformance:
;    r8 -- function address
;    rdi, rsi, rdx, rcx -- function arguments
; result returned in rax:
;    0  -- ok
;    1  -- rbx clobbered
;    2  -- rbp clobbered
;    4  -- r12 clobbered
;    8  -- r13 clobbered
;    16 -- r14 clobbered
;    32 -- r15 clobbered
;    64 -- stack misaligned at call site
call_with_abi_check:
                push            rsp

                ; check rsp alignment
                test            rsp, 0xF
                jnz             .misaligned

                ; save non-volatile registers on stack
                push            rbx
                push            rbp
                push            r12
                push            r13
                push            r14
                push            r15

                ; save function address
                push            r8

                ; poison unused volatile registers
                mov             rax, POISON
                mov             r8,  POISON + 2
                mov             r9,  POISON + 3
                mov             r10, POISON + 5
                mov             r11, POISON + 8

                ; poison non-volatile registers
                mov             rbx, POISON + 10
                mov             rbp, POISON + 20
                mov             r12, POISON + 30
                mov             r13, POISON + 40
                mov             r14, POISON + 50
                mov             r15, POISON + 60

                ; call function
                call            [rsp]

                ; pop function address
                add             rsp, 8

                ; initialize outcome
                xor             rax, rax

                ; verify that non-volatile registers have not been clobbered
                verify_reg      rbx, POISON + 10, 1
                verify_reg      rbp, POISON + 20, 2
                verify_reg      r12, POISON + 30, 4
                verify_reg      r13, POISON + 40, 8
                verify_reg      r14, POISON + 50, 16
                verify_reg      r15, POISON + 60, 32

                ; recover original values of non-volatile registers
                pop             r15
                pop             r14
                pop             r13
                pop             r12
                pop             rbp
                pop             rbx

                jmp             .exit

.misaligned:
                or              rax, 64

.exit:
                pop             rsp
                ret


long_int_add_checked:
                mov             r8, long_int_add
                mov             rcx, POISON + 42
                jmp             call_with_abi_check


long_int_sub_checked:
                mov             r8, long_int_sub
                mov             rcx, POISON + 88
                jmp             call_with_abi_check


long_int_mul_checked:
                mov             r8, long_int_mul
                jmp             call_with_abi_check
