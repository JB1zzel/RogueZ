; dor.asm - Rogue's application DOR and card header (mpm, Z88 dev kit macros)
;       mpm -I<devkit>/def -b dor.asm      (tools/mkcard.py does this)
; Assembled at $FE00 in the application bank, above the resident code that
; z88dk links from $C000 (tools/mkcard.py checks they do not overlap).
        module rogue_dor

        include "dor.def"
        include "macros.def"

        org     $FE00

defc BANK_APPL = $3F            ; application bank (top of the 128K card)
defc BANK_CODE0 = $38           ; code bank 0, bound in S2 at entry
defc REQPAGES = 96              ; continuous RAM $2000-$7FFF
defc BANK_MTH = $3E             ; data image bank: MENU and help at $E000
defc ENTRY = $C000              ; z88/rogue_crt0.asm: jp start / scf / ret

in_dor:
        dorappl ("Rogue", 'G', AT_Bad|AT_Ones|AT_Draw, 0,  \
                 ENTRY,                                    \
                 0, 0, BANK_CODE0, BANK_APPL,              \
                 REQPAGES, 0, 0, 0,                        \
                 [in_topics, BANK_MTH],                    \
                 [in_commands, BANK_MTH],                  \
                 [in_help, BANK_MTH],                      \
                 ,                                         \
                 BANK_APPL)

; the MENU and help are in z88/mth.asm, in bank BANK_MTH (mkcard.py makes
; mth_addr.def from its first bytes)
        include "mth_addr.def"
end_of_dor:

        defs    $1C0-end_of_dor         ; to $FFC0 ($ and labels count from $FE00)

        doraplf [in_dor & $3FFF, BANK_APPL]
        defs    $1F8-$1D3
        defb    $52,$47,$45             ; card ID
        defb    $80                     ; external application ID
        defb    8                       ; card size: 8 banks (128K)
        defb    0                       ; application card
        defm    "OZ"
