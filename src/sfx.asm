; sfx.asm: a sound board for the game's sounds (src/sounds.inc), to
; hear them without playing to them.
;
;   make run-sfx
;
; The sounds are listed on screen; the arrow keys (or W and Z) move the
; mark up and down, SPACE plays the marked one (again each press).

#include "layout.inc"

                org     BSS
sel             rmb     1               ; the marked sound
keyprev         rmb     1
pressed         rmb     1
s_ptr           rmb     2

                org     CODE
start:
                sei
                lds     #STACK_TOP
                ldaa    #$FF
                staa    P1DDR
                ldaa    #VDG_RG6|VDG_CSS
                staa    VDG
                staa    vdg_shadow
                jsr     cls
                clr     sel
                clr     keyprev
                jsr     frame_init
                ldaa    #TXT_WHITE      ; the list
                staa    txt_col
                ldx     #TXT_AT(4,4)
                ldd     #s_title
                jsr     txt_str
                ldx     #TXT_AT(176,2)
                ldd     #s_help
                jsr     txt_str
                ldx     #sounds
                stx     s_ptr
                ldx     #TXT_AT(20,4)
list:           pshx
                ldx     s_ptr
                ldd     2,x             ; its name
                beq     list_end
                inx
                inx
                inx
                inx
                stx     s_ptr
                pulx
                pshx
                jsr     txt_str
                pulx
                ldab    #128            ; 8 rows down (256 bytes: two steps)
                abx
                abx
                bra     list
list_end:       pulx
                bsr     mark
loop:           jsr     frame_wait
                jsr     snd_frame
                jsr     kbd_read
                ldaa    keyprev         ; keys just pressed: up, down, SPACE
                coma
                anda    joy
                ldab    joy
                stab    keyprev
                staa    pressed
                bita    #J_UP           ; up: the one above (from the top,
                beq     loop_f1         ; the last)
                bsr     unmark
                ldaa    sel
                bne     up_f1
                ldaa    #NSOUNDS
up_f1:          deca
                staa    sel
                bsr     mark
loop_f1:        ldaa    pressed
                bita    #J_DOWN         ; down: the one below (from the
                beq     loop_f2         ; last, the top)
                bsr     unmark
                ldaa    sel
                inca
                cmpa    #NSOUNDS
                bcs     down_f1
                clra
down_f1:        staa    sel
                bsr     mark
loop_f2:        ldaa    pressed
                bita    #J_FIRE         ; SPACE: play the marked one (again
                beq     loop            ; and again: no moving on)
                ldab    sel
                aslb
                aslb
                ldx     #sounds
                abx
                ldx     0,x
                ldaa    #9
                jsr     snd_play
                bra     loop

mark:           ldaa    #'-'            ; the marker beside the selection
                bra     mark_f1
unmark:         ldaa    #' '
mark_f1:        psha
                ldab    sel             ; row 20 + 8 x sel, column 2
                ldaa    #8
                mul
                addb    #20
                clra
                aslb                    ; x 32
                rola
                aslb
                rola
                aslb
                rola
                aslb
                rola
                aslb
                rola
                addd    #SCREEN+2
                pshb
                psha
                pulx
                pula
                jmp     txt_char

cls:            ldx     #SCREEN
                clra
                clrb
cls_b1:         std     0,x
                inx
                inx
                cpx     #SCREEN_END
                bne     cls_b1
                rts

; the sounds: effect, name
sounds:         fdb     fx_extra, s1
                fdb     fx_bing, s14
                fdb     fx_life, s2
                fdb     fx_start, s3
                fdb     fx_salute, s4
                fdb     fx_gameover, s15
                fdb     fx_finale, s5
                fdb     fx_bossin, s6
                fdb     fx_open, s7
                fdb     fx_clang, s8
                fdb     fx_ping, s16
                fdb     fx_bossdie, s9
                fdb     fx_shipboom, s10
                fdb     fx_warp, s11
                fdb     fx_zap, s12
                fdb     fx_drop, s17
                fdb     fx_boom, s13
                fdb     0, 0
NSOUNDS         equ     (*-sounds)/4-1
s_title:        fcc     "STARFALL SOUND BOARD"
                fcb     0
s_help:         fcc     "UP/DOWN CHOOSE, SPACE PLAYS"
                fcb     0
s1:             fcc     "EXTRA SHIP"
                fcb     0
s2:             fcc     "FRESH SHIP"
                fcb     0
s3:             fcc     "GAME START"
                fcb     0
s4:             fcc     "AREA CLEARED"
                fcb     0
s5:             fcc     "FINALE MARCH"
                fcb     0
s6:             fcc     "BOSS WARNING"
                fcb     0
s7:             fcc     "CORE OPENS"
                fcb     0
s8:             fcc     "CORE HIT"
                fcb     0
s9:             fcc     "BOSS EXPLODES"
                fcb     0
s10:            fcc     "SHIP EXPLODES"
                fcb     0
s11:            fcc     "WARP"
                fcb     0
s12:            fcc     "SHOT"
                fcb     0
s13:            fcc     "ALIEN EXPLODES"
                fcb     0
s14:            fcc     "SORTIE BONUS"
                fcb     0
s15:            fcc     "GAME OVER"
                fcb     0
s16:            fcc     "HULL RICOCHET"
                fcb     0
s17:            fcc     "BOMB DROP"
                fcb     0

#include "sounds.inc"
#include "frame.asm"
#include "input.asm"
#include "sound.asm"
#include "text.asm"
