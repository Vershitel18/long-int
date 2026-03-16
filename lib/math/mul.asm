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
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15 ; будем использовать для сохранения адреса результата, чтобы не пушить r10 каждый раз
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rcx
    mov     r8,  rdx
    xor     rax, rax ; Зануляем регистр
    xor     rdx, rdx
    lea     rcx, [r14 * 2]
.zero:
    mov     [r8 + rcx*8 - 8], rax ; Перетёрли результат нулями
    dec     rcx
    jnz     .zero
    xor     rbx, rbx ; индекс разряда второго множителя
.outer:
    cmp     rbx, r14
    jge     .done
    mov     rdi, r12 ; возвращаем указатель на первый множитель, потому что внутри функции long_int_mul_short он будет изменён
    mov     rcx, r14
    mov     rsi, [r13 + rbx*8] ; двигаем указатель на следующий разряд второго множителя
    lea     r15, [r8 + rbx*8] ; двигаем указатель на следующий разряд результата, чтобы суммировать уже со следующего индекса
    mov     r10, r15
    .long_int_mul_short:
        test    rcx, rcx
        jz      .done_mul_short
        xor     r11, r11 ; будем использовать r11 для хранения бита переноса от умножения и сложения
    .loop:
        mov     rax, [rdi]
        mul     rsi ; rdx:rax = A[i] * b; в rdx будут старшие 64 бита, в rax - младшие
        add     rax, r11 ; + бит переноса от предыдущей итерации
        adc     rdx, 0 ; rdx так как результат записывается именно в него, поэтому прибавляем к нему бит переноса
        add     rax, [r10] ; cуммируем с уже записанным результатом
        adc     rdx, 0 ; учли бит переноса от сложения
        mov     [r10], rax
        mov     r11, rdx ; new carry
        lea     r10, [r10 + 8] ; двигаем указатель на следующий разряд результата
        lea     rdi, [rdi + 8] ; двигаем указатель на следующий разряд первого множителя
        dec     rcx
        jnz     .loop
        mov     rax, r11 ; return carry
.done_mul_short:
    ; получаем записанный в по адресу r10 результат текущего qword * B сложенный с текущим результатом
    mov     r9, r14
    add     r9, rbx
    add     [r8 + r9*8], rax ; записываем бит переноса в следующий разряд результата
    adc     qword [r8 + r9*8 + 8], 0 ; добавляем бит переноса если было переполнение в предыдущей операции
    inc     rbx
    jmp     .outer
.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

