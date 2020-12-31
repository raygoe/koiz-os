format elf
use32

; This code is pretty brute-force, but readable..

; This macro pushes 0 as the error code for interrupts
; that do not have an error code
; It also pushes the interrupt number
macro no_error_code_interrupt_handler int_num* {
    public isr_#int_num
    isr_#int_num#:
        pushd 0
        pushd int_num
        jmp common_interrupt_handler
}

; This macro already assumes that the error code is on the stack
; It only pushes the interrupt number
macro error_code_interrupt_handler int_num* {
    public isr_#int_num
    isr_#int_num#:
        pushd int_num
        jmp common_interrupt_handler
}

; This macro inserts an interrupt entry into the IDT
; Note that the C func setup_idt will populate the func pointers from 0xDEAD
;
; IDT Entry Layout
; Offset (Low)      - Bits 0-15     - Lower part of the interrupt func addr 
; Selector          - Bits 16-31    - CS selector in GDT (We made it 8 in GDT)
; Zeros             - Bits 32-39    - Should all be zero
;
; Gate Type         - Bits 40-43    - 0b1110 for 32-bit interrupt gate
;   Storage Segment   - Bit 44        - 0 for interrupt and trap gates
;   Desc Priv Level   - Bit 45-46     - Call protection
;   Present           - Bit 47        - Is 1 unless interrupt is unused
;
; Offset (High)     - Bit 48-63     - Higher part of the interrupt func addr 
macro irq_interrupt_entry entry_num* {
    public irq#entry_num
    irq#entry_num:
        dw 0xDEAD
        dw 0x0008
        db 0x00
        db 10101110b
        dw 0xDEAD
}

include 'ccall.inc'

section '.text' executable

    public load_idt
    public common_interrupt_handler
    extrn printf
    extrn interrupt_handler
    extrn setup_idt

    ; at this point the stack should contain [esp + 4] -> first entry in EDT
    ; [esp] -> the return address    
    load_idt:
        PUSHAD

        call setup_idt
        lidt [idt_info]

        POPAD
        ret

    common_interrupt_handler:
        sti 

        ; Manually save registers
        ; Only because we want to access the other members of the stack

        ; Stack layout is as following:
        ; 44 eflags
        ; 40 cs
        ; 36 eip
        ; 32 error code
        ; 28 interrupt num
        pushd eax ;24
        pushd ebx ;20
        pushd ecx ;16
        pushd edx ;12
        pushd esi ;8
        pushd edi ;4
        pushd ebp ;0

        ; Call our C function
        ;call interrupt_handler
        mov edi, esp
        add edi, 28
        ccall printf, msg, [edi]

        ; Restore registers
        popd ebp
        popd edi
        popd esi
        popd edx
        popd ecx
        popd ebx
        popd eax

        ; Restores the ESP
        add esp, 8

        ; We need to use iret to return from 
        cli
        iret

    no_error_code_interrupt_handler 0
    no_error_code_interrupt_handler 1

section '.rodata'
    msg db "Handling Interrupt %x",0xA,0
    public idt_info
    public idt_start
    idt_start:
        irq_interrupt_entry 0
        irq_interrupt_entry 1
    idt_end:
    idt_info:
        dw idt_end - idt_start - 1
        dd idt_start

section '.data' writeable

