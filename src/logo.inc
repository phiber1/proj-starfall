; logo.inc: the title logo's letters and their drawing (src/starfall.asm),
; shared with the logo colour comparison (src/logos.asm).  The program
; provides the variables (bg_scr, bg_g, bg_b (3), bg_n, bg_k, bg_row,
; bg_cols (3: white, orange, blue masks), bg_m, bg_bandp (the band table
; to use: 30 rows of 0 white, 1 orange, 2 blue) and bu_s); the logo's
; font tables come with it.

; big_str: X = screen, D = string: the logo's letters (logo_font: 9
; pixels and a 3-pixel gap, 3 bytes, by 30 rows) in colour bands
; (bg_bandp's table, through bg_cols)
big_str:
                std     bu_s
big_str_b1:     pshx
                ldx     bu_s
                ldaa    0,x
                beq     big_str_f1
                inx
                stx     bu_s
                pulx
                pshx
                bsr     big_char
                pulx
                inx
                inx
                inx
                bra     big_str_b1
big_str_f1:     pulx
                rts

big_char:                               ; A = character, X = screen (letters
                stx     bg_scr          ; not in the logo font stay blank)
                ldx     #logo_font
big_char_b1:    ldab    0,x
                bne     big_char_f0
                rts
big_char_f0:    cba
                beq     big_char_f1
                ldab    #1+2*LOGO_ROWS
                abx
                bra     big_char_b1
big_char_f1:    inx
                stx     bg_g
                ldaa    #LOGO_ROWS
                staa    bg_n
                clr     bg_row
big_char_row:   ldx     bg_g            ; a row: pixels in bits 15-7 -> 3
                ldd     0,x             ; bytes of white bit pairs
                inx
                inx
                stx     bg_g
                stab    bg_m            ; (bit 7: the ninth pixel)
                tab
                lsrb
                lsrb
                lsrb
                lsrb
                ldx     #lg_expand
                abx
                ldab    0,x
                stab    bg_b
                anda    #15
                tab
                ldx     #lg_expand
                abx
                ldab    0,x
                stab    bg_b+1
                clrb
                tst     bg_m
                bpl     big_char_f2
                ldab    #$C0
big_char_f2:    stab    bg_b+2
                ldaa    #2              ; each row twice
                staa    bg_k
big_char_b2:    ldx     bg_bandp        ; this row's colour mask
                ldab    bg_row
                abx
                ldab    0,x
                ldx     #bg_cols
                abx
                ldab    0,x
                stab    bg_m
                ldx     bg_scr
                ldaa    bg_b
                anda    bg_m
                staa    0,x
                ldaa    bg_b+1
                anda    bg_m
                staa    1,x
                ldaa    bg_b+2
                anda    bg_m
                staa    2,x
                ldab    #ROW_BYTES
                abx
                stx     bg_scr
                inc     bg_row
                dec     bg_k
                bne     big_char_b2
                dec     bg_n
                beq     big_char_r
                jmp     big_char_row
big_char_r:     rts
; the logo's own letters (owner: straight diagonals for the curves): 9
; pixels by 15 rows, each row drawn twice (one pixel per two rows: 45
; degrees, artifact pixels being twice as wide as tall); per letter its
; code, then a word a row, pixels in bits 15-7 (1 = lit)
LOGO_ROWS       equ     15
logo_font:
                fcb     'S'
                fdb     $3F80            ; ..#######
                fdb     $7F80            ; .########
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $FF00            ; ########.
                fdb     $FF80            ; #########
                fdb     $7F80            ; .########
                fdb     $0380            ; ......###
                fdb     $0380            ; ......###
                fdb     $0380            ; ......###
                fdb     $0380            ; ......###
                fdb     $FF00            ; ########.
                fdb     $FE00            ; #######..
                fcb     'T'
                fdb     $FF80            ; #########
                fdb     $FF80            ; #########
                fdb     $FF80            ; #########
                fdb     $1C00            ; ...###...
                fdb     $1C00            ; ...###...
                fdb     $1C00            ; ...###...
                fdb     $1C00            ; ...###...
                fdb     $1C00            ; ...###...
                fdb     $1C00            ; ...###...
                fdb     $1C00            ; ...###...
                fdb     $1C00            ; ...###...
                fdb     $1C00            ; ...###...
                fdb     $1C00            ; ...###...
                fdb     $1C00            ; ...###...
                fdb     $1C00            ; ...###...
                fcb     'A'
                fdb     $3E00            ; ..#####..
                fdb     $7F00            ; .#######.
                fdb     $E380            ; ###...###
                fdb     $E380            ; ###...###
                fdb     $E380            ; ###...###
                fdb     $E380            ; ###...###
                fdb     $FF80            ; #########
                fdb     $FF80            ; #########
                fdb     $FF80            ; #########
                fdb     $E380            ; ###...###
                fdb     $E380            ; ###...###
                fdb     $E380            ; ###...###
                fdb     $E380            ; ###...###
                fdb     $E380            ; ###...###
                fdb     $E380            ; ###...###
                fcb     'R'
                fdb     $FE00            ; #######..
                fdb     $FF00            ; ########.
                fdb     $E380            ; ###...###
                fdb     $E380            ; ###...###
                fdb     $E380            ; ###...###
                fdb     $FF00            ; ########.
                fdb     $FE00            ; #######..
                fdb     $EE00            ; ###.###..
                fdb     $E700            ; ###..###.
                fdb     $E380            ; ###...###
                fdb     $E380            ; ###...###
                fdb     $E380            ; ###...###
                fdb     $E380            ; ###...###
                fdb     $E380            ; ###...###
                fdb     $E380            ; ###...###
                fcb     'F'
                fdb     $FF80            ; #########
                fdb     $FF80            ; #########
                fdb     $FF80            ; #########
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $FE00            ; #######..
                fdb     $FE00            ; #######..
                fdb     $FE00            ; #######..
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fcb     'L'
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $E000            ; ###......
                fdb     $FF80            ; #########
                fdb     $FF80            ; #########
                fdb     $FF80            ; #########
                fcb     0
lg_expand:      fcb     $00, $03, $0C, $0F, $30, $33, $3C, $3F ; 4 pixels -> 4
                fcb     $C0, $C3, $CC, $CF, $F0, $F3, $FC, $FF ; white bit pairs
