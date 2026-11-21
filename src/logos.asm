; logos.asm: the title logo in several color schemes, one above another,
; for comparing them (the same drawing code as the game: logo.inc).
;
;   make run-logos
;
; E: the game's current scheme, then A-D: candidates.  Each band table
; is 30 rows of 0 white, 1 orange, 2 blue.

#include "layout.inc"

                org     BSS
bg_scr          rmb     2
bg_g            rmb     2
bg_b            rmb     3
bg_n            rmb     1
bg_k            rmb     1
bg_row          rmb     1
bg_cols         rmb     3
bg_m            rmb     1
bg_bandp        rmb     2
bu_s            rmb     2
lg_ptr          rmb     2
lg_scr          rmb     2
lg_lbl          rmb     2

                org     CODE
start:
                sei
                lds     #STACK_TOP
                ldaa    #VDG_RG6|VDG_CSS
                staa    VDG
                staa    vdg_shadow
                jsr     cls
                ldaa    #TXT_WHITE      ; white, orange, blue (no swap here)
                ldab    #TXT_ORANGE
                std     bg_cols
                ldaa    #TXT_BLUE
                staa    bg_cols+2
                ldx     #schemes
                stx     lg_ptr
                ldx     #SCREEN+2*ROW_BYTES
                stx     lg_scr
next:           ldx     lg_ptr          ; each scheme: its band table, then
                ldd     0,x             ; its label beside its logo
                beq     done
                std     bg_bandp
                ldd     2,x
                std     lg_lbl
                ldab    #4
                abx
                stx     lg_ptr
                ldd     lg_scr          ; the label: 12 rows down, column 1
                addd    #12*ROW_BYTES+1
                pshb
                psha
                pulx
                ldaa    #TXT_WHITE
                staa    txt_col
                ldd     lg_lbl
                jsr     txt_str
                ldd     lg_scr          ; the logo: column 4
                addd    #4
                pshb
                psha
                pulx
                ldd     #s_name
                jsr     big_str
                ldd     lg_scr          ; the next, 38 rows down
                addd    #38*ROW_BYTES
                std     lg_scr
                bra     next
done:           bra     done

cls:            ldx     #SCREEN
                clra
                clrb
cls_b1:         std     0,x
                inx
                inx
                cpx     #SCREEN_END
                bne     cls_b1
                rts

s_name:         fcc     "STARFALL"
                fcb     0

schemes:        fdb     band_e, s_e
                fdb     band_a, s_a
                fdb     band_b, s_b
                fdb     band_c, s_c
                fdb     band_d, s_d
                fdb     0
s_e:            fcc     "E"
                fcb     0
s_a:            fcc     "A"
                fcb     0
s_b:            fcc     "B"
                fcb     0
s_c:            fcc     "C"
                fcb     0
s_d:            fcc     "D"
                fcb     0
band_e:         fcb     2, 2, 2, 2, 2, 2, 2, 2, 2, 2       ; the game's (B)
                fcb     2, 0, 2, 2, 0, 2, 0, 2, 0, 0
                fcb     2, 0, 0, 0, 0, 0, 0, 0, 0, 0
band_a:         fcb     2, 2, 2, 2, 2, 2, 2, 2, 2, 2       ; chrome horizon
                fcb     2, 2, 2, 0, 0, 1, 1, 1, 1, 1
                fcb     1, 1, 1, 1, 1, 1, 1, 1, 1, 1
band_b:         fcb     2, 2, 2, 2, 2, 2, 2, 2, 2, 2       ; starlight glow
                fcb     2, 0, 2, 2, 0, 2, 0, 2, 0, 0
                fcb     2, 0, 0, 0, 0, 0, 0, 0, 0, 0
band_c:         fcb     0, 0, 0, 0, 0, 0, 0, 0, 0, 0       ; rising glow
                fcb     0, 2, 0, 0, 2, 0, 2, 0, 2, 2
                fcb     0, 2, 2, 2, 2, 2, 2, 2, 2, 2
band_d:         fcb     0, 0, 0, 0, 0, 0, 0, 0, 0, 0       ; molten
                fcb     0, 1, 0, 0, 1, 0, 1, 0, 1, 1
                fcb     0, 1, 1, 1, 1, 1, 1, 1, 1, 1

#include "logo.inc"
#include "text.asm"
