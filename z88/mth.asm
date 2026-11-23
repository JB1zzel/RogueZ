; mth.asm - Rogue's MENU topics, commands and help pages (mpm).
; Lives at the top of the last code bank ($3E), above the data image;
; mkcard.py sets the org (OZ reads it in segment 3) and
; z88/dor.asm points at it.  tools/mkcard.py assembles it, after making
; help.inc from z88/help.txt with the kit's tools/helpwrap.py (OZ shows 7
; lines of about 62 characters a page, and does not wrap).
; The first 4 bytes give mkcard.py the addresses of in_commands and in_help.
; The help is not tokenized: OZ before 4.3 cannot use a token table.
; Menu commands come to the game as 0 then the code (src/zoz.c zb_getkey).

        module rogue_mth

        include "dor.def"
        include "macros.def"

        org     $C000

defc CMD_SAVE   = $81           ; -> S
defc CMD_OPTS   = $82           ; (was o; the options are a topic now)
defc CMD_MAP    = $83           ; -> M  (DIAMOND L: DIAMOND M is ENTER)
defc CMD_REDRAW = $84           ; -> ^R
defc CMD_QUIT   = $85           ; -> Q
defc CMD_OPT    = $86           ; $86-$8D: options 0-7 (src/options.c z_option)

        defw    in_commands, in_help

in_topics:
        defb    0
        mthtpc  ["Info"], TPCF_INFO|TPCF_HELP, (hlp_info-in_help)
        mthtpc  ["Game"], TPCF_HELP, (hlp_game-in_help)
        mthtpc  ["Options"], TPCF_HELP, (hlp_opts-in_help)
        defb    0

in_commands:
        defb    0
        mthcmd  (0, , ["The aim"],          CMDF_HELP, (hlp_aim-in_help))
        mthcmd  (0, , ["Moving"],           CMDF_HELP, (hlp_moving-in_help))
        mthcmd  (0, , ["Fighting"],         CMDF_HELP, (hlp_fighting-in_help))
        mthcmd  (0, , ["Things"],           CMDF_HELP, (hlp_items-in_help))
        mthcmd  (0, , ["More commands"],    CMDF_HELP, (hlp_more-in_help))
        mthcmd  (0, , ["The screen"],       CMDF_HELP, (hlp_screen-in_help))
        mthcmd  (0, , ["Saving"],           CMDF_HELP, (hlp_saving-in_help))
        defb    1                       ; end of the Info topic
        mthcmd  (CMD_SAVE,   ["S"] , ["Save game"],     CMDF_HELP, (hlp_saving-in_help))
        mthcmd  (CMD_MAP,    ["L"] , ["Level map"],     CMDF_HELP, (hlp_screen-in_help))
        mthcmd  (CMD_REDRAW, ["R"] , ["Redraw screen"], CMDF_HELP, (hlp_redraw-in_help))
        mthcmd  (CMD_QUIT,   ["Q"] , ["Quit"],          CMDF_HELP, (hlp_quit-in_help))
        defb    1                       ; end of the Game topic
        mthcmd  (CMD_OPT+7, , ["Your name"],           CMDF_HELP, (hlp_o_name-in_help))
        defb    1                       ; end of the Options topic
        defb    0                       ; end of commands

        include "help.inc"
