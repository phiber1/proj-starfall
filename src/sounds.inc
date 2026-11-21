; sounds.inc: the game's sound effects and jingles (src/starfall.asm),
; shared with the sound board (src/sfx.asm) so it plays the real ones.
; Sound effects
fx_zap:         fcb     5, SND_TONE     ; the ship's shot: a bright "pew",
                fdb     600, 90         ; above the aliens' bombs (short: as
                fcb     0               ; many interrupts as a longer, lower
                                        ; one, and rapid fire plays it a lot)
fx_boom:        fcb     4, SND_NOISE     ; (noise and tones here are kept
                fdb     800, 0          ; slow: every half-period is an
                fcb     24, SND_NOISE   ; interrupt, and boss fights with
                fdb     1100, 30        ; rapid fire play these constantly)
                fcb     0
fx_drop:        fcb     6, SND_TONE     ; a bomb drops: a darker falling
                fdb     1300, 80        ; blip, below the ship's shot
                fcb     0
; Jingles (priority 9: nothing interrupts them)
fx_start:                               ; the start fanfare, ~1.6 s
                NOTE    N_C5, 7
                NOTE    N_E5, 7
                NOTE    N_G5, 7
                NOTE    N_C6, 14
                REST    4
                NOTE    N_A5, 7
                NOTE    N_B5, 7
                NOTE    N_C6, 28
                fcb     0
fx_life:                                ; a fresh ship, ~0.8 s
                NOTE    N_G5, 6
                NOTE    N_A5, 6
                NOTE    N_B5, 6
                NOTE    N_D6, 22
                fcb     0
fx_salute:                              ; the victory salute, ~1.8 s
                NOTE    N_G5, 7
                NOTE    N_G5, 5
                NOTE    N_G5, 5
                NOTE    N_C6, 14
                REST    4
                NOTE    N_E6, 8
                NOTE    N_D6, 8
                NOTE    N_E6, 8
                NOTE    N_C6, 30
                fcb     0
fx_finale:                              ; all four bosses beaten: a victory
                NOTE    N_G4, 8         ; march, ~10 s (an original tune)
                NOTE    N_C5, 8
                NOTE    N_E5, 8
                NOTE    N_G5, 8
                NOTE    N_C6, 20
                REST    4
                NOTE    N_E5, 8
                NOTE    N_G5, 8
                NOTE    N_C6, 8
                NOTE    N_E6, 16
                NOTE    N_D6, 8
                NOTE    N_C6, 8
                NOTE    N_D6, 32
                NOTE    N_G5, 8         ; (the dominant)
                NOTE    N_B5, 8
                NOTE    N_D6, 8
                NOTE    N_G5, 8
                NOTE    N_D6, 20
                REST    4
                NOTE    N_B5, 8
                NOTE    N_C6, 8
                NOTE    N_D6, 8
                NOTE    N_E6, 16
                NOTE    N_D6, 8
                NOTE    N_B5, 8
                NOTE    N_C6, 32
                NOTE    N_A5, 8         ; (the subdominant)
                NOTE    N_C6, 8
                NOTE    N_F5, 8
                NOTE    N_A5, 8
                NOTE    N_C6, 16
                NOTE    N_A5, 8
                NOTE    N_F5, 8
                NOTE    N_G5, 16
                NOTE    N_E5, 16
                NOTE    N_F5, 8
                NOTE    N_A5, 8
                NOTE    N_D6, 8
                NOTE    N_C6, 8
                NOTE    N_B5, 16
                NOTE    N_G5, 16
                NOTE    N_C6, 8         ; (home)
                NOTE    N_G5, 8
                NOTE    N_E5, 8
                NOTE    N_G5, 8
                NOTE    N_C6, 8
                NOTE    N_E6, 8
                NOTE    N_D6, 8
                NOTE    N_B5, 8
                NOTE    N_C6, 60
                fcb     0
fx_extra:                               ; an extra ship: three quick, high
                rept    3               ; beeps, like no other sound
                fcb     4, SND_TONE
                fdb     N_E6, 0
                fcb     3, SND_REST
                fdb     0, 0
                endm
                fcb     0
fx_bing:                                ; a sortie bonus: two quick, high,
                fcb     3, SND_TONE     ; rising beeps (the extra ship's are
                fdb     N_D6, 0         ; three, all E6)
                fcb     2, SND_REST
                fdb     0, 0
                fcb     3, SND_TONE
                fdb     N_E6, 0
                fcb     0
fx_gameover:                            ; game over: a falling A minor
                NOTE    N_E5, 10        ; arpeggio, a darker answer, a long
                NOTE    N_C5, 10        ; low A (~2 s; an original phrase)
                NOTE    N_A4, 10
                REST    4
                NOTE    N_D5, 8
                NOTE    N_B4, 8
                NOTE    N_GS4, 8
                REST    4
                NOTE    N_A4, 40
                fcb     0
fx_warp:                                ; the afterburner: a rising roar
                fcb     40, SND_NOISE
                fdb     900, -12
                fcb     60, SND_NOISE
                fdb     420, 0
                fcb     0
fx_bossin:                              ; the boss arrives: eight low, falling
                rept    8               ; wails (~4 s; low tones are cheap)
                fcb     24, SND_TONE
                fdb     1200, 16
                fcb     6, SND_REST
                fdb     0, 0
                endm
                fcb     0
fx_ping:                                ; a shot ricochets off the hull: a
                fcb     2, SND_TONE     ; high "tink" falling fast (short:
                fdb     380, 220        ; it plays on every shot at a hull,
                fcb     0               ; and high tones cost interrupts)
fx_clang:                               ; a hit on the core
                fcb     3, SND_NOISE
                fdb     600, 0
                fcb     8, SND_TONE
                fdb     900, 40
                fcb     0
fx_open:                                ; the core's hatch opens
                NOTE    N_C4, 6
                NOTE    N_G4, 6
                NOTE    N_C5, 12
                fcb     0
fx_bossdie:                             ; the boss goes up: a long roar
                fcb     10, SND_NOISE
                fdb     250, 0
                fcb     110, SND_NOISE
                fdb     380, 4
                fcb     0
fx_shipboom:    fcb     6, SND_NOISE    ; the ship: a long, deep explosion
                fdb     300, 0
                fcb     50, SND_NOISE
                fdb     500, 20
                fcb     0

