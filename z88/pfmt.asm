; pfmt.asm - printf's conversions, cut to those Rogue uses (%s %c %d %u %x,
; with l for long).  Replaces z88dk's default table, which also links %o %p
; %X %B %n and the 64-bit %ll code into the application bank.

        MODULE  __printf_format_table
        SECTION rodata_clib
        PUBLIC  __printf_format_table
        PUBLIC  __printf_get_flags

        EXTERN  __printf_get_flags_impl
        EXTERN  __printf_handle_s
        EXTERN  __printf_handle_c
        EXTERN  __printf_handle_d
        EXTERN  __printf_handle_u
        EXTERN  __printf_handle_x

        defc    __printf_get_flags = __printf_get_flags_impl

__printf_format_table:
        defb    's'
        defw    __printf_handle_s
        defb    'c'
        defw    __printf_handle_c
        defb    'd'
        defw    __printf_handle_d
        defb    'u'
        defw    __printf_handle_u
        defb    'x'
        defw    __printf_handle_x
        defb    0
