; starfall.asm: StarFall, a vertical space shooter for the MC-10 (8K mod +
; MCX32-SD), built on mc10-game-engine (the engine/ submodule).
;
; An original vertical space shooter in artifact color.  The title screen
; shows a color sample (C swaps orange and blue, for real NTSC machines
; that power up in the other color phase); SPACE starts.  "PLAYER 1" is
; shown at the start and after each lost ship.  Waves of aliens fly
; scripted paths, dive through the bottom and back in at the top, and
; drop bombs; shots make them explode.  Bombs or collisions destroy the
; ship; it comes back flashing (invulnerable) while ships remain.
;
;   W A S Z / arrows move, SPACE fires.     METER=1  CPU meter

#define OBJ_EXTRA 10                    /* flight (7) + animation (3) */
#define AN_BASE 7                       /* animation bytes after flight's */
#define FL_HALFX 1                      /* artifact color: 128 pixels across */
#define STAR_TOP 7                      /* stars stay below the status bar */
#include "layout.inc"
#include "ovl.inc"

#define NALIEN 10
#define NBOMB 6
#define NSHOT 3

SHIP_SPEEDX     equ     $0100           ; 1 artifact pixel (2 screen pixels)
SHIP_SPEED      equ     $0200           ; 2 rows a frame
SHOT_SPEED      equ     $0400
BOMB_SPEED      equ     $0200           ; round 1: 2 rows a frame (+1/4 a round,
                                        ; to 3: the bomb's halo is 3 rows)
SHIP_XMAX       equ     128-ship_W
AL_W            equ     saucer_W        ; all alien types share one box size
AL_H            equ     saucer_H
SHIP_YMIN       equ     120
SHIP_YMAX       equ     192-ship_H
FIRE_DELAY      equ     8
WAVE_GAP        equ     90              ; frames between waves
MAX_ALIVE       equ     8               ; live aliens on screen at most
SORTIE_GAP      equ     180             ; a sortie bonus: kills at most 3 s apart
HI_SIZE         equ     6               ; STARFALL.HI: its bytes,
HI_FILE         equ     1               ; ... its file number (SD: 1-2)
FORT_ALIVE      equ     1               ; ... in the fortress fight (it's busy)
SPRAY_ON        equ     36              ; bombs may drop for 36 frames (round 1),
SPRAY_OFF       equ     80              ; then a quiet spell of 80
BOMB_GAP        equ     9               ; at least 9 frames between bombs (round 1)
DIFF_MAX        equ     4               ; rounds get harder up to round 5 (see
                                        ; set_diff)
FF_HOPL         equ     $02             ; F_FLAGS: back in at a random x (event 2)
FF_HOPR         equ     $04             ; ... for right circles (event 3)
FF_WAIT1        equ     $08             ; F_FLAGS bits 3-7: a hidden wait (count)
HOP_WAIT        equ     10              ; ... after a hop: 10-25 counts of 4 frames
AIM_W           equ     2               ; aimed drops: within 2 pixels of the nose
BOMB_WARN       equ     36              ; bombs start 36 rows above the ship (12 frames)

START_SHIPS     equ     2               ; ships in reserve at the start (3 in all)
DEAD_TIME       equ     110             ; frames from losing a ship to what's next
BANNER_TIME     equ     110             ; frames a banner stays up
OVER_TIME       equ     200             ; "GAME OVER"
INVULN_TIME     equ     120             ; flashing, untouchable, after a respawn
BANNER_ROW      equ     93
BAND            equ     7               ; the status bar: rows 0-6, in front of
                                        ; everything
NAREAS          equ     4
AREA_WAVES      equ     8               ; waves in each area
MODE_PLAY       equ     0
MODE_SALUTE     equ     1               ; the victory salute
MODE_WARP       equ     2               ; blasting off, up behind the status bar
MODE_COAST      equ     3               ; gone: just the streaking stars
MODE_ARRIVE     equ     4               ; rising in from the bottom, braking
MODE_FINALE     equ     5               ; the fortress has fallen: song,
FIN_TIME        equ     870             ; fireworks, banners (frames, counted
FIN_T1          equ     670             ; down; the song takes ~680, and the
FIN_T2          equ     540             ; warp's roar must follow it): "ALL
FIN_TB          equ     410             ; FOUR BOSSES DEFEATED", the bonus,
FIN_T3          equ     260             ; the Blorps' threat, "ROUND n", the
FIN_T4          equ     140             ; last firework; at 0,
                                        ; the warp
COAST_TIME      equ     70
BS_NONE         equ     0               ; boss states
BS_ENTER        equ     1               ; descending from under the status bar
BS_FIGHT        equ     2
BS_DYING        equ     3               ; exploding
BS_DEFEATED     equ     4               ; gone: the area is won
BOSS_TOP        equ     4               ; boss1's antenna rows, above the hull
BOSS_Y          equ     24-BOSS_TOP     ; where it stops descending
BOSS_SPEED      equ     $0080           ; half a pixel a frame
BOSS_DESCEND    equ     $0040           ; a slow, ominous descent
WARN_TIME       equ     240             ; the warning: siren and flashing banner
BOSS_XMIN       equ     4               ; sway range without envoys ...
BOSS_XMAX       equ     128-boss1_W-4
ENV_DXL         equ     envoy_W+2       ; envoys' boxes: left of the hull ...
ENV_DXR         equ     boss1_W+2       ; ... and right of it
BOSS_EXMIN      equ     ENV_DXL+2       ; ... and with them (they stay on
BOSS_EXMAX      equ     128-ENV_DXR-envoy_W-2 ; screen)
ENV_FIRE        equ     16              ; frames between envoy bombs
ENV_PATROL      equ     12              ; a fortress's envoys patrol 12 px out
ENV_PATROL_V    equ     $0080           ; ... at half a pixel a frame
NCORE           equ     3               ; cores per boss at most
CS_SHUT         equ     0               ; a core: shut (shots ping off) ...
CS_OPEN         equ     1               ; ... open (shots hurt it) ...
CS_DEAD         equ     2               ; ... destroyed
BOSS_FIRE       equ     22              ; frames between cannon shots
DIE_TIME        equ     120             ; frames of explosions
SALUTE_TIME     equ     110
MAP_TIME        equ     130             ; frames the map screen stays up
MAP_SEG         equ     30              ; map rows per area
MAP_BOTTOM      equ     176             ; the map's bottom row
MAP_COL         equ     15              ; the map strip's byte column

                org     PROG_DP         ; direct page: the per-frame variables
cooldown        rmb     1
seed            rmb     2
obj             rmb     2               ; object being processed
obj2            rmb     2
wv_ptr          rmb     2               ; current wave
wv_left         rmb     1               ; aliens still to launch
wv_timer        rmb     1               ; frames to the next launch / wave
wv_x            rmb     1               ; entry x of the next launch
bomb_cd         rmb     1               ; frames until another bomb may drop
spray_t         rmb     1               ; bomb rhythm: spray, then quiet
alive           rmb     1               ; aliens on screen
cy              rmb     1               ; collide: the shot's row + 24
col_par         rmb     1               ; collide: frame parity
cs_par          rmb     1               ; collide: shot parity
dead            rmb     1               ; nonzero while the ship is lost
invuln          rmb     1               ; frames of invulnerability left
mode            rmb     1               ; MODE_PLAY, MODE_SALUTE, MODE_WARP ...
warpf           rmb     1               ; star updates per frame
banner_t        rmb     1               ; frames the banner stays up
status_t        rmb     1
area_done       rmb     1               ; the area's waves are all launched
boss_state      rmb     1               ; BS_NONE ... BS_DEFEATED
                DP_CHECK

                org     BSS             ; ordinary RAM: the rest
score           rmb     3               ; BCD, 6 digits
hiscore         rmb     3               ; the high score (BCD), STARFALL.HI
next_bonus      rmb     3               ; the next extra ship's score (BCD)
sortie_on       rmb     1               ; the wave flying can still earn its bonus
sortie_dsc      rmb     2               ; ... its alien type,
sortie_left     rmb     1               ; ... aliens of it still to destroy,
sortie_hit      rmb     1               ; ... one destroyed already,
sortie_t        rmb     1               ; ... frames since the last
hi_new          rmb     1               ; beaten this game: save it
title_seen      rmb     1               ; the title has been shown once
hi_buf          rmb     HI_SIZE         ; the file: "SF", score, checksum
lives           rmb     1               ; ships in reserve (not the one flying)
dead_t          rmb     1
gover           rmb     1               ; game over: back to the title
col_o           rmb     1               ; the orange and blue masks (swapped
col_b           rmb     1               ; by C on the title screen)
keyprev         rmb     1
area            rmb     1               ; 0-3
wv_index        rmb     1               ; waves done in this area (the map)
mode_t          rmb     1
bg_scr          rmb     2               ; big_char: screen position,
bg_g            rmb     2               ; ... glyph row,
bg_b            rmb     3               ; ... a glyph row magnified,
bg_n            rmb     1               ; ... rows left,
bg_k            rmb     1
bg_row          rmb     1               ; ... the logo row (its color band)
bg_cols         rmb     3               ; white, orange, blue masks
bg_m            rmb     1               ; ... the row's mask
bg_bandp        rmb     2               ; ... the band table drawn with
fin_t           rmb     2               ; the finale's countdown
round           rmb     1               ; 1, 2 ... (each fortress begins another)
dlev            rmb     1               ; difficulty: round - 1, at most DIFF_MAX
al_flip         rmb     1               ; 1: the aliens' colors are swapped
dgap            rmb     1               ; ... dlev x 2 (launch gaps, core hits)
spray_on        rmb     1               ; ... frames of each bomb cycle that spray
bomb_gap        rmb     1               ; ... frames between bombs at least
boss_fire       rmb     1               ; ... frames between cannon shots
env_fire        rmb     1               ; ... frames between envoy bombs
bomb_spd        rmb     2               ; ... bombs' speed (rows a frame, 8.8)
wp_wrapped      rmb     1
banner_p        rmb     2               ; the banner being shown
banner_p2       rmb     2               ; ... and its second line (0: none)
bu_s            rmb     2
banner_fl       rmb     1               ; the banner flashes
mp_t            rmb     1
mp_a            rmb     2
bm_xy           rmb     2               ; bomb_at: the bomb's position
bm_dx           rmb     2               ; and its sideways speed
rnd_n           rmb     1               ; rnd: steps left
hop_vis         rmb     1               ; hopping aliens on screen (this frame)
hop_park        rmb     1               ; ... and waiting out of sight
hop_rel         rmb     1               ; the waiting ones may come back
ba_xy           rmb     2               ; boss_attach scratch
ba_f            rmb     2               ; ... the hull's x and y fractions
env_ofs         rmb     2               ; a fortress's envoys: patrol offset
env_v           rmb     2               ; ... and speed (8.8, signed)
ba_dx           rmb     2
ba_dy           rmb     2
boss_hp         rmb     NCORE           ; hits left, per core; then per
core_fl         rmb     NCORE           ; core (these six in this order):
core_s          rmb     NCORE           ; frames it stays white, CS_ state,
core_st         rmb     NCORE           ; stage (0: opens when the envoys
core_dx         rmb     NCORE           ; are gone, 1: when the stage 0
core_dy         rmb     NCORE           ; cores are), offset in the hull
ncores          rmb     1               ; this boss's cores
ci              rmb     1               ; core loops: the index
os_st           rmb     1               ; open_stage / cores_alive scratch
os_i            rmb     1
os_n            rmb     1
bs_obj          rmb     2               ; boss_shot: the core tested
boss_can        rmb     2               ; this boss's cannon list
boss_ci         rmb     1               ; the cannon that fired last (1-n)
boss_w          rmb     1               ; the hull's visible width
boss_h          rmb     1               ; ... its box height
boss_y          rmb     1               ; ... where it stops descending
boss_still      rmb     1               ; nonzero: it never sways
boss_edxr       rmb     1               ; ... its right envoy's x offset
boss_t          rmb     1               ; boss timer (bombs, dying)
wv_start        rmb     2               ; the escort list (it loops)
env_left        rmb     1               ; envoys still flying (shield up)
env_hp          rmb     2               ; hits left: left envoy, right envoy
env_t           rmb     1               ; envoy bomb timer
env_side        rmb     1               ; which envoy bombs next
boss_xmin       rmb     1               ; the hull's sway range
boss_xmax       rmb     1
boss_edy        rmb     1               ; this boss: the envoys' row offset
ovl_cur         rmb     1               ; the boss overlay in memory (0: none)
alive_max       rmb     1               ; aliens flying at most (MAX_ALIVE,
                                        ; or fewer in a boss fight: BT_ALIVE)
ovl_pb          rmb     PB_SIZE         ; the MCX32-SD BIOS's parameter block
ld_t            rmb     1               ; frames the last boss load took
status_buf      rmb     BAND*ROW_BYTES  ; the status bar, ready to copy
sr_sp           rmb     2
sr_bsp          rmb     2
sr_dst          rmb     2
sr_n            rmb     1
BSS_USED        equ     *
                BSS_CHECK

                org     CODE
start:
                sei
                lds     #STACK_TOP
                ldaa    #$FF
                staa    P1DDR
                ldaa    #VDG_RG6|VDG_CSS
                staa    VDG
                staa    vdg_shadow
                ldx     #PROG_DP        ; clear all of this program's variables
start_b1:       clr     0,x
                inx
                cpx     #ht_al
                bne     start_b1
                ldx     #BSS
start_b2:       clr     0,x
                inx
                cpx     #BSS_USED
                bne     start_b2
                ldd     FRC
                orab    #1
                std     seed
                std     st_seed
                ldaa    #TXT_ORANGE
                staa    col_o
                ldaa    #TXT_BLUE
                staa    col_b
                ldx     #objs
                stx     obj_first
                ldx     #objs_end
                stx     obj_end
                jsr     frame_init

; ---------------------------------------------------------------- title
; The color check, once after loading: a block that should look orange
; (C swaps orange and blue if it doesn't); SPACE goes on to the title.
                jsr     hi_load         ; the high score from the SD card
color_check:
                jsr     col_draw
cc2_loop:       jsr     frame_wait
                jsr     snd_frame
                jsr     kbd_read
                jsr     key_c           ; C: swap the colors
                cmpa    keyprev
                beq     cc2_fire
                staa    keyprev
                tsta
                beq     cc2_fire
                ldx     #all_sprites
                jsr     col_swap
                ldaa    col_o
                ldab    col_b
                staa    col_b
                stab    col_o
                jsr     col_draw
cc2_fire:       ldaa    joy
                bita    #J_FIRE
                beq     cc2_loop
cc2_up:         jsr     frame_wait      ; SPACE let go first (or the title
                jsr     kbd_read        ; would start a game at once)
                ldaa    joy
                bita    #J_FIRE
                bne     cc2_up

; The title screen: unchanging; SPACE starts a game
title:
                jsr     snd_stop
                tst     hi_new          ; a new record: save it
                beq     title_f1
                clr     hi_new
                jsr     hi_save
title_f1:       clra                    ; the cast in its own colors
                jsr     al_colors
                jsr     title_draw
                tst     title_seen      ; the very first title: it bursts on
                bne     title_f2        ; with the boss explosion's roar
                inc     title_seen      ; (not after a game over)
                ldx     #fx_bossdie
                ldaa    #9
                jsr     snd_play
title_f2:
                inc     st_behind       ; the star field, behind the title
                jsr     stars_init
t_loop:
                jsr     frame_wait
                jsr     stars_update
                jsr     snd_frame
                jsr     kbd_read
                ldaa    joy
                bita    #J_FIRE
                beq     t_loop

; ---------------------------------------------------------------- a game
game_start:
                clr     st_behind       ; (the game's stars are plain)
                jsr     cls
                jsr     stars_init
                ldx     #objs           ; empty every object slot
game_start_b1:  clr     0,x
                inx
                cpx     #ship
                bne     game_start_b1
                ldd     #0
                std     score
                staa    score+2
                ldd     #$0100          ; the first extra ship: 10,000
                std     next_bonus
                clr     next_bonus+2
                ldaa    #START_SHIPS
                staa    lives
                clr     alive
                clr     dead
                clr     invuln
                clr     gover
                clr     bomb_cd
                clr     spray_t
                ldaa    #FIRE_DELAY
                staa    cooldown
                jsr     status_labels   ; the bar, labels and all
                ldaa    #BAND
                staa    sm_band
                jsr     ship_place
                clr     area
                clr     mode
                clr     boss_state
                ldaa    #1
                staa    round
                jsr     set_diff
                ldaa    #1
                staa    warpf
                ldx     #fx_start       ; the start fanfare, over the map
                ldaa    #9
                jsr     snd_play
                jsr     area_begin
                jsr     map_show
                jsr     round_banner    ; "ROUND 1" as play begins
loop:
                jsr     frame_wait
                METER_ON
                ldaa    #$AA
                DBGA
                jsr     snd_frame
                jsr     kbd_read
                jsr     ship_logic
                jsr     fire_logic
                jsr     wave_logic
                jsr     aliens_logic
                jsr     boss_logic
                jsr     bombs_logic
                jsr     shots_logic
                jsr     collide
                jsr     victory_check
                ldab    warpf           ; stars first: sprites cover them
loop_b1:        pshb                    ; (several updates a frame at warp)
                jsr     stars_update
                pulb
                decb
                bne     loop_b1
                jsr     spr_update_all
                jsr     status_update   ; render the bar if it changed ...
                jsr     status_repair   ; ... and put it in front of sprites
                jsr     banner_update
                ldaa    #$BB
                DBGA
                METER_OFF
                ldaa    gover           ; game over and its banner done?
                beq     loop
                ldaa    banner_t
                bne     loop
                jmp     title

; ---------------------------------------------------------------- waves
; A wave: fdb descriptor, script; fcb count, launch interval, entry x,
; x step (added to the entry x after each launch, signed: spreads the
; wave across the screen).  The table ends with fdb 0 (back to the start).
W_DESC          equ     0
W_PATH          equ     2
W_COUNT         equ     4
W_GAP           equ     5
W_X             equ     6
W_XSTEP         equ     7
W_SIZE          equ     8

wave_begin:
                ldx     wv_ptr
                ldaa    W_X,x
                staa    wv_x
                ldaa    W_COUNT,x
                staa    wv_left
                ldaa    #1
                staa    wv_timer
                rts

wl_done0:       rts
wave_logic:
                tst     mode
                bne     wl_done0
                tst     area_done
                bne     wl_done0
                dec     wv_timer
                bne     wl_done0
                ldaa    wv_left
                beq     wl_next         ; all launched: wait for the next wave
                ldaa    alive           ; at most alive_max flying at once:
                cmpa    alive_max       ; the rest wait their turn (the area's
                bcc     wl_wait         ; tally is the same)
                ldx     #aliens         ; launch one into a free slot
wave_logic_b1:  ldd     O_SPR,x
                beq     wave_logic_f1
                ldab    #OBJ_SIZE
                abx
                cpx     #aliens_end
                bne     wave_logic_b1
wl_wait:        inc     wv_timer        ; none free: try next frame
                rts
wave_logic_f1:  stx     obj
                ldx     wv_ptr
                ldab    W_GAP,x         ; (closer together in later rounds,
                subb    dgap            ; but at least 6 frames)
                bcs     wl_gap_f1
                cmpb    #6
                bcc     wl_gap_f2
wl_gap_f1:      ldab    #6
wl_gap_f2:      stab    wv_timer
                ldaa    wv_x            ; this alien's entry x; the next one's
                tab                     ; is W_XSTEP further across ...
                addb    W_XSTEP,x
                cmpb    #128-AL_W       ; ... back to the first lane if that
                bcs     wl_xok          ; would be off screen (relaunched
                ldab    W_X,x           ; survivors can outnumber the lanes)
wl_xok:         stab    wv_x
                ldx     obj
                staa    O_X,x           ; enter just above the top
                clr     O_XF,x
                ldab    #256-AL_H
                stab    O_Y,x
                clr     O_YF,x
                ldx     wv_ptr
                ldd     W_PATH,x
                pshb
                psha
                ldd     W_DESC,x
                ldx     obj
                std     O_SPR,x
                pula
                pulb
                jsr     fl_start
                ldx     obj
                jsr     fl_step         ; first frame: sets the velocity
                ldaa    fl_event        ; (a path may start with event 2/3)
                cmpa    #2
                bcs     wl_nohop
                ldx     obj
                jsr     hop_flag
wl_nohop:       ldx     wv_ptr          ; the wave's first launch: its sortie
                ldaa    wv_left
                cmpa    W_COUNT,x
                bne     wl_sortie_f1
                jsr     sortie_new
wl_sortie_f1:   dec     wv_left
                inc     alive
wl_done:        rts
wl_next:                                ; next wave when at most 2 remain
                ldaa    alive
                cmpa    #2
                bls     wl_next_f1
                inc     wv_timer
                rts
wl_next_f1:     ldx     wv_ptr
                ldab    #W_SIZE
                abx
                inc     wv_index
                ldd     0,x             ; another wave in the list?
                bne     wl_launch
                tst     boss_state      ; the end of the list.  In a boss
                beq     wl_area_end     ; fight the escorts go round again
                ldx     wv_start
                bra     wl_launch
wl_area_end:    inc     area_done       ; otherwise the area's waves are done
                rts
wl_launch:      stx     wv_ptr
                ldaa    W_X,x
                staa    wv_x
                ldaa    W_COUNT,x
                staa    wv_left
                ldaa    #WAVE_GAP
                staa    wv_timer
                rts

; ---------------------------------------------------------------- aliens
aliens_logic:
                tst     sortie_on       ; the sortie: kills too far apart end
                beq     al_sortie_f1    ; it (counted from the first)
                tst     sortie_hit
                beq     al_sortie_f1
                inc     sortie_t
                ldaa    sortie_t
                cmpa    #SORTIE_GAP
                bcs     al_sortie_f1
                clr     sortie_on
al_sortie_f1:   ldaa    bomb_cd         ; bomb rhythm
                beq     aliens_logic_f1
                dec     bomb_cd
aliens_logic_f1:
                inc     spray_t
                ldaa    spray_t
                cmpa    #SPRAY_ON+SPRAY_OFF
                bcs     aliens_logic_f2
                clr     spray_t
aliens_logic_f2:
                ldaa    hop_park        ; hops: the waiting aliens come back
                bne     al_hops         ; only once their whole column has
                clr     hop_rel         ; left the screen (then each after
                bra     al_hops_f1      ; its own random time); none
al_hops:        tst     hop_vis         ; waiting: start again
                bne     al_hops_f1
                inc     hop_rel
al_hops_f1:     clr     hop_park
                clr     hop_vis
                ldaa    ship+O_X        ; the aim target: the ship
                staa    fl_tx
                ldaa    ship+O_Y
                staa    fl_ty
                ldx     #aliens
al_loop:
                stx     obj
                ldd     O_SPR,x
                bne     al_used
                jmp     al_next
al_used:        ldd     AN_PTR,x        ; exploding?
                beq     al_live
                ldd     O_X,x           ; drift, but not off the sides ...
                addd    O_DX,x
                cmpa    #128-AL_W
                bcs     al_loop_f1
                ldd     #0
                std     O_DX,x
al_loop_f1:     ldd     O_Y,x           ; ... nor below the screen: past row
                addd    O_DY,x          ; 223 is BSS, so nothing may be drawn
                cmpa    #192-AL_H       ; there (an alien exploding low,
                bcs     al_loop_f2      ; still diving, used to drift in and
                cmpa    #224            ; overwrite the variables); coming
                bcc     al_loop_f2      ; in from above is fine
                ldd     #0
                std     O_DY,x
al_loop_f2:     jsr     obj_anim_step   ; next frame; frees the slot at the end
                jmp     al_next
al_live:
                ldaa    F_FLAGS,x       ; waiting out of sight before coming
                cmpa    #FF_WAIT1       ; back in (a count in bits 3-7)?
                bcs     al_go
                inc     hop_park
                tst     hop_rel         ; the column still on screen?
                beq     al_wait
                ldab    spray_t         ; count every 4th frame
                andb    #3
                bne     al_wait
                suba    #FF_WAIT1
                staa    F_FLAGS,x
                cmpa    #FF_WAIT1
                bcc     al_wait
                jsr     fl_velocity     ; time's up: on along the path
al_wait:        jmp     al_next
al_go:          bita    #FF_HOPL|FF_HOPR ; a hopping alien on screen?
                beq     al_go_f1
                ldab    O_Y,x
                cmpb    #192
                bcc     al_go_f1
                inc     hop_vis
al_go_f1:       ldaa    F_FLAGS,x       ; wrapping aliens may be anywhere
                bita    #FF_WRAP
                bne     al_inside
                ldaa    O_X,x           ; off the side somehow?  Back inside
                cmpa    #128-AL_W       ; (left edge if it wrapped below 0)
                bcs     al_inside
                clrb
                cmpa    #192
                bcc     al_clamp
                ldab    #128-AL_W-1
al_clamp:       stab    O_X,x
                ldaa    #128            ; and turn it round
                suba    F_ANG,x
                staa    F_ANG,x
al_inside:      jsr     fl_step
                ldaa    fl_event        ; event 1: drop a bomb
                cmpa    #1
                beq     al_drop
                bcs     al_aim
                ldx     obj
                jsr     hop_flag
                bra     al_live_f1
al_aim:         ldx     obj             ; or right over the ship (no spot
                ldaa    O_X,x           ; is safe for a ship that never
                suba    ship+O_X        ; moves); the rhythm still decides
                adda    #saucer_PADX+3-ship_PADX-3+AIM_W
                cmpa    #2*AIM_W+1
                bcc     al_live_f1
                jsr     drop_aim
                bra     al_live_f1
al_drop:        jsr     drop_bomb
al_live_f1:     ldx     obj
                ldaa    F_FLAGS,x       ; a wrapping alien: through the side
                bita    #FF_WRAP        ; to the other one
                beq     al_mirror
                ldd     O_X,x
                addd    O_DX,x
                bita    #$80            ; next x past either edge (128-255)?
                beq     al_live_f2
                jsr     obj_erase       ; the halo can't bridge the jump
                ldx     obj
                ldaa    O_X,x           ; x stays below 128, so the other
                eora    #$80            ; side is x +/- 128: flip the top bit
                staa    O_X,x
                bra     al_live_f2
al_mirror:      ldd     O_X,x           ; safety: mirror off the sides
                addd    O_DX,x
                cmpa    #128-AL_W
                bcs     al_live_f2
                ldaa    #128
                suba    F_ANG,x
                staa    F_ANG,x
                jsr     fl_velocity
                ldx     obj
al_live_f2:     ldd     O_Y,x           ; through the bottom: back in at the top
                addd    O_DY,x
                cmpa    #192
                bcs     al_next
                cmpa    #224
                bcc     al_next
                jsr     sortie_leave    ; (out of the sortie's reach)
                ldx     obj
                ldab    F_FLAGS,x       ; somewhere new?
                bitb    #FF_HOPL|FF_HOPR
                beq     al_top
                jsr     obj_erase       ; (in the hidden rows: just tidy)
                jsr     rnd             ; x = 1-96, or 22-117 for left
                ldab    #96             ; circles (they stay on screen)
                mul
                inca
                ldx     obj
                ldab    F_FLAGS,x
                bitb    #FF_HOPL
                beq     al_hop_x
                adda    #21
al_hop_x:       staa    O_X,x
                ldd     #0              ; and wait there a moment, out of
                std     O_DX,x          ; sight, so it looks intentional
                std     O_DY,x
                jsr     rnd             ; for its own random time (not in
                andb    #15             ; step with the others leaving, or
                addb    #HOP_WAIT       ; it looks like an instant swap)
                aslb
                aslb
                aslb
                ldx     obj
                orab    F_FLAGS,x
                stab    F_FLAGS,x
al_top:         ldaa    #256-AL_H
                staa    O_Y,x
al_next:
                ldx     obj
                ldab    #OBJ_SIZE
                abx
                cpx     #aliens_end
                beq     al_done
                jmp     al_loop
al_done:        rts

; an explosion for the object at X, D = frame list: the boom sprites are
; compiled for shift 0 only (spritec "shift 0": a quarter of the code),
; so x snaps down to a byte boundary (after the old image is erased) and
; the debris drifts only up or down
boom_start:
                jsr     obj_anim_start
                ldx     an_obj
                ldaa    O_X,x
                anda    #$FC
                staa    O_X,x
                ldd     #0
                std     O_DX,x
                rts

; event 2/3 (A) for the alien at X: from now on it comes back in from
; the top at a random x (2: for left circles, 3: right ones)
hop_flag:
                ldab    #FF_HOPL
                cmpa    #2
                beq     hop_flag_f1
                ldab    #FF_HOPR
hop_flag_f1:    orab    F_FLAGS,x
                stab    F_FLAGS,x
                rts

; drop a bomb from the alien at obj: it keeps the alien's sideways
; speed, so bombs thrown along a dive land along its line (an unmoving
; ship is never safe between the drop points)
drop_bomb:
                ldx     obj
                ldd     O_DX,x          ; half the alien's sideways speed
                asra
                rorb
                std     bm_dx
                bra     drop_pos
drop_aim:                               ; straight down, onto the ship
                ldx     #0
                stx     bm_dx
                ldx     obj
drop_pos:       ldaa    O_X,x
                adda    #saucer_PADX+3-bomb_PADX
                ldab    O_Y,x
                addb    #saucer_H-saucer_PADY-bomb_PADY
                bra     bomb_dx

; a bomb at A = x, B = y (its box), falling straight, if the rhythm
; allows and it's far enough above the ship
bomb_at:
                ldx     #0
                stx     bm_dx
bomb_dx:        std     bm_xy
                ldaa    bomb_cd         ; too soon after the last bomb?
                bne     db_done
                ldaa    spray_t         ; in a spray window?
                cmpa    spray_on
                bcc     db_done
                ldaa    ship+O_Y        ; far enough above the ship to
                suba    #BOMB_WARN      ; dodge?
                cmpa    bm_xy+1
                bls     db_done
                ldx     #bombs
bomb_at_b1:     ldd     O_SPR,x
                beq     db_done_f1
                ldab    #OBJ_SIZE
                abx
                cpx     #bombs_end
                bne     bomb_at_b1
db_done:        rts
db_done_f1:     ldd     bm_xy
                staa    O_X,x
                stab    O_Y,x
                clr     O_XF,x
                clr     O_YF,x
                ldd     bm_dx
                std     O_DX,x
                ldd     bomb_spd
                std     O_DY,x
                ldd     #bomb_dsc
                std     O_SPR,x
                ldaa    bomb_gap
                staa    bomb_cd
                ldx     #fx_drop
                ldaa    #1
                jmp     snd_play

; a bomb at A = x, B = y, whatever the rhythm (envoys), if a slot is free
bomb_force:
                std     bm_xy
                ldaa    ship+O_Y        ; far enough above the ship to
                suba    #BOMB_WARN      ; dodge?
                cmpa    bm_xy+1
                bls     bf_done
                ldx     #bombs
bf_find:        ldd     O_SPR,x
                beq     bf_slot
                ldab    #OBJ_SIZE
                abx
                cpx     #bombs_end
                bne     bf_find
bf_done:        rts
bf_slot:        ldd     bm_xy
                staa    O_X,x
                stab    O_Y,x
                clr     O_XF,x
                clr     O_YF,x
                ldd     #0
                std     O_DX,x
                ldd     bomb_spd
                std     O_DY,x
                ldd     #bomb_dsc
                std     O_SPR,x
                rts

bombs_logic:
                ldx     #bombs
bombs_logic_b1: stx     obj2
                ldd     O_SPR,x
                beq     bombs_logic_f1
                ldd     O_X,x           ; off a side (thrown bombs)?
                addd    O_DX,x
                cmpa    #128-bomb_W
                bcc     bombs_logic_off
                ldd     O_Y,x           ; off the bottom?
                addd    O_DY,x
                cmpa    #192-bomb_H
                bcs     bombs_logic_f1
bombs_logic_off:
                jsr     obj_erase
                ldx     obj2
                ldd     #0
                std     O_SPR,x
bombs_logic_f1: ldx     obj2
                ldab    #OBJ_SIZE
                abx
                cpx     #bombs_end
                bne     bombs_logic_b1
                rts

; ---------------------------------------------------------------- ship
ship_logic:
                ldaa    mode
                beq     sl_play
                cmpa    #MODE_SALUTE
                bne     sl_warp
                ldx     #ship           ; the salute: hold still
                ldd     #0
                std     O_DX,x
                std     O_DY,x
                jsr     ship_align
                dec     mode_t
                bne     sl_ret
                jmp     warp_begin
sl_warp:        cmpa    #MODE_WARP
                bne     sl_nwarp
                jmp     warp_logic
sl_nwarp:       cmpa    #MODE_COAST
                bne     sl_ncoast
                jmp     coast_logic
sl_ncoast:      cmpa    #MODE_FINALE
                bne     sl_narr
                jmp     finale_logic
sl_narr:        jmp     arrive_logic
sl_play:        tst     dead
                beq     sl_alive
                ldx     #ship           ; lost: let the explosion play out
                ldd     AN_PTR,x
                beq     sl_play_f1
                jsr     obj_anim_step
sl_play_f1:     dec     dead_t
                bne     sl_ret
                tst     lives           ; none in reserve: that was the last
                beq     sl_over
                jsr     field_clear     ; a fresh screen ...
                jsr     map_show        ; ... after the map
                clr     dead            ; another ship: one fewer in reserve,
                jsr     ship_place      ; counted as it appears
                dec     lives
                ldaa    #1
                staa    status_t
                ldaa    #INVULN_TIME
                staa    invuln
                ldx     #fx_life        ; a fresh ship's phrase
                ldaa    #9
                jmp     snd_play
sl_over:
                clr     lives           ; (none left: it shows 0 already)
                ldaa    #1
                staa    status_t
                ldx     #fx_gameover    ; the game over jingle
                ldaa    #9
                jsr     snd_play
                inc     gover
                ldd     #s_gameover
                jsr     banner_show
                ldaa    #OVER_TIME
                staa    banner_t
sl_ret:         rts
sl_alive:
                ldaa    invuln          ; flashing after a respawn
                beq     sl_move
                dec     invuln
                ldx     #ship
                ldaa    invuln
                beq     sl_alive_f1               ; the end: visible
                bita    #4
                beq     sl_alive_f2              ; every 4 frames: hide ...
sl_alive_f1:    ldd     #ship_dsc       ; ... or show
                std     O_SPR,x
                bra     sl_move
sl_alive_f2:    ldd     O_SPR,x
                beq     sl_move
                jsr     obj_erase
                ldx     #ship
                ldd     #0
                std     O_SPR,x
sl_move:
                ldx     #ship
                ldd     #0
                std     O_DX,x
                std     O_DY,x
                ldaa    joy
                bita    #J_LEFT
                beq     sl_move_f1
                ldd     #-SHIP_SPEEDX
                std     O_DX,x
                ldaa    joy
sl_move_f1:     bita    #J_RIGHT
                beq     sl_move_f2
                ldd     #SHIP_SPEEDX
                std     O_DX,x
                ldaa    joy
sl_move_f2:     bita    #J_UP
                beq     sl_move_f3
                ldd     #-SHIP_SPEED
                std     O_DY,x
                ldaa    joy
sl_move_f3:     bita    #J_DOWN
                beq     sl_move_f4
                ldd     #SHIP_SPEED
                std     O_DY,x
sl_move_f4:     ldd     O_X,x
                addd    O_DX,x
                cmpa    #SHIP_XMAX
                bcs     sl_move_f5
                ldd     #0
                std     O_DX,x
sl_move_f5:     ldd     O_Y,x
                addd    O_DY,x
                cmpa    #SHIP_YMIN
                bcs     sl_stop
                cmpa    #SHIP_YMAX
                bcs     sl_done
sl_stop:        ldd     #0
                std     O_DY,x
sl_done:        ldd     O_SPR,x         ; hidden (flashing): the sprite manager
                bne     sl_done_f1               ; won't move it, so move it here
                ldd     O_X,x
                addd    O_DX,x
                std     O_X,x
                ldd     O_Y,x
                addd    O_DY,x
                std     O_Y,x
sl_done_f1:     rts

; After a lost ship: every alien, bomb and shot goes.  Aliens that weren't
; destroyed still count: they are launched again along the current wave's
; path.  (In a boss fight the boss stays; its escorts start over.)
field_clear:
                ldx     #aliens         ; empty the alien, bomb and shot slots
fc_clear:       clr     0,x
                inx
                cpx     #shots_end
                bne     fc_clear
                ldaa    alive           ; the survivors must come again
                beq     fc_done
                adda    wv_left
                staa    wv_left
                clr     alive
                clr     area_done
                ldx     wv_ptr          ; from the wave's entry point
                ldaa    W_X,x
                staa    wv_x
                ldaa    #60
                staa    wv_timer
fc_done:        rts

ship_place:                             ; a fresh ship at the bottom centre
                ldx     #ship
                ldaa    #(128-ship_W)/2
                staa    O_X,x
                ldaa    #160
                staa    O_Y,x
                clr     O_XF,x
                clr     O_YF,x
                ldd     #0
                std     O_DX,x
                std     O_DY,x
                std     AN_PTR,x
                ldd     #ship_dsc
                std     O_SPR,x
                rts

; the ship is hit (unless already lost or flashing)
ship_hit:
                tst     mode            ; untouchable during the salute and warp
                bne     ship_hit_f1
                tst     dead
                bne     ship_hit_f1
                tst     invuln
                bne     ship_hit_f1
                clr     sortie_on       ; (no sortie bonus now)
                inc     dead            ; (the ships count drops when the
                ldaa    #DEAD_TIME      ; next ship appears, or at game over)
                staa    dead_t
                ldx     #ship
                ldd     #0
                std     O_DX,x
                std     O_DY,x
                ldd     #anim_shipboom
                jsr     boom_start
                ldx     #fx_shipboom
                ldaa    #3
                jmp     snd_play
ship_hit_f1:    rts

; ---------------------------------------------------------------- shots
fire_logic:
                tst     dead
                bne     fl_done
                tst     mode
                bne     fl_done
                ldaa    cooldown
                beq     fire_logic_f1
                dec     cooldown
                rts
fire_logic_f1:  ldaa    joy
                bita    #J_FIRE
                beq     fl_done
                ldx     #shots
fire_logic_b1:  ldd     O_SPR,x
                beq     fire_logic_f2
                ldab    #OBJ_SIZE
                abx
                cpx     #shots_end
                bne     fire_logic_b1
                rts
fire_logic_f2:  ldaa    ship+O_X        ; the nose: column 3 of the ship
                adda    #ship_PADX+3-shot_PADX
                staa    O_X,x
                ldaa    ship+O_Y
                adda    #ship_PADY-shot_H+shot_PADY
                staa    O_Y,x
                clr     O_XF,x
                clr     O_YF,x
                ldd     #0
                std     O_DX,x
                ldd     #-SHOT_SPEED
                std     O_DY,x
                ldd     #shot_dsc
                std     O_SPR,x
                ldaa    #FIRE_DELAY
                staa    cooldown
                ldx     #fx_zap
                ldaa    #1
                jsr     snd_play
fl_done:        rts

shots_logic:
                ldx     #shots
shots_logic_b1: stx     obj2
                ldd     O_SPR,x
                beq     sh_gone_f1
                ldd     O_Y,x           ; under the status bar (or past the
                addd    O_DY,x          ; top): gone
                cmpa    #BAND
                bcs     sh_gone
                cmpa    #192
                bcs     sh_gone_f1
sh_gone:
                jsr     obj_erase
                ldx     obj2
                ldd     #0
                std     O_SPR,x
sh_gone_f1:     ldx     obj2
                ldab    #OBJ_SIZE
                abx
                cpx     #shots_end
                bne     shots_logic_b1
                rts

; ---------------------------------------------------------------- hits
; Collisions.  Shots against the boss every frame (the core's window is
; shallow), but each shot against the aliens only every other frame
; (alternating shots), and the ship against aliens / bombs on alternate
; frames: their overlap windows are deeper than two frames' movement, so
; nothing slips through, and it halves the work.
collide:
                com     col_par         ; this frame's parity
                ldaa    col_par
                staa    cs_par
                ldx     #shots          ; shots against the boss and aliens
cs_loop:
                stx     ht_a
                ldd     O_SPR,x
                beq     cs_next
                jsr     boss_shot       ; the boss first
                bcc     cs_loop_f1
                ldx     ht_a            ; it hit the boss: the shot is spent
                jsr     obj_erase
                ldx     ht_a
                ldd     #0
                std     O_SPR,x
                jmp     cs_next
cs_loop_f1:     com     cs_par          ; every other shot (alternating) meets
                beq     cs_next         ; the aliens this frame
                ldx     ht_a
                ldaa    O_Y,x           ; this shot's row, for the quick reject
                adda    #24
                staa    cy
                ldx     #aliens
ca_loop:                                ; tight: most pairs are rejected here
                ldd     O_SPR,x
                beq     ca_next
                ldd     AN_PTR,x        ; already exploding
                bne     ca_next
                ldaa    cy              ; within 24 rows of the shot?
                suba    O_Y,x
                cmpa    #48
                bcc     ca_next
                stx     ht_b            ; close: the full test
                jsr     hit_test
                ldx     ht_b
                bcc     ca_next
                ldx     ht_a            ; hit: remove both
                jsr     obj_erase
                ldx     ht_a
                ldd     #0
                std     O_SPR,x
                ldx     ht_b
                jsr     sortie_kill     ; (its type, before it explodes)
                ldx     ht_b            ; the alien explodes, drifting on at
                asr     O_DX,x          ; half its speed
                ror     O_DX+1,x
                asr     O_DY,x
                ror     O_DY+1,x
                ldd     #anim_boom
                jsr     boom_start
                dec     alive
                jsr     score_alien
                ldx     #fx_boom
                ldaa    #2
                jsr     snd_play
                bra     cs_next
ca_next:
                ldab    #OBJ_SIZE
                abx
                cpx     #aliens_end
                bne     ca_loop
cs_next:
                ldx     ht_a
                ldab    #OBJ_SIZE
                abx
                cpx     #shots_end
                beq     shots_done
                jmp     cs_loop
shots_done:     tst     col_par         ; bombs against the ship on one frame,
                beq     cb_skip         ; aliens against it on the other
                tst     dead
                bne     cb_skip
                ldx     #ship
                stx     ht_b
                ldx     #bombs
cb_loop:
                stx     ht_a
                ldd     O_SPR,x
                beq     cb_next
                ldaa    O_Y,x           ; quick reject: more than 24 rows apart
                suba    ship+O_Y
                adda    #24
                cmpa    #48
                bcc     cb_next
                jsr     hit_test
                bcc     cb_next
                ldx     ht_a
                jsr     obj_erase
                ldx     ht_a
                ldd     #0
                std     O_SPR,x
                jsr     ship_hit
cb_next:
                ldx     ht_a
                ldab    #OBJ_SIZE
                abx
                cpx     #bombs_end
                bne     cb_loop
                rts
cb_skip:
                tst     dead            ; aliens against the ship
                bne     cc_done
                tst     invuln
                bne     cc_done
                ldx     #ship
                stx     ht_b
                ldaa    O_Y,x
                adda    #24
                staa    cy
                ldx     #aliens
cc_loop:
                ldd     O_SPR,x
                beq     cc_next
                ldd     AN_PTR,x
                bne     cc_next
                ldaa    cy
                suba    O_Y,x
                cmpa    #48
                bcc     cc_next
                stx     ht_a
                jsr     hit_test
                ldx     ht_a
                bcc     cc_next
                ldd     #anim_boom      ; collision: both explode
                jsr     boom_start
                dec     alive
                jsr     score_alien
                jmp     ship_hit
cc_next:
                ldab    #OBJ_SIZE
                abx
                cpx     #aliens_end
                bne     cc_loop
cc_done:        rts

; ---------------------------------------------------------------- areas
area_begin:                             ; start the waves of area `area`
                ldab    area
                aslb
                ldx     #areas
                abx
                ldx     0,x
                stx     wv_ptr
                jsr     wave_begin
                ldaa    #60
                staa    wv_timer
                clr     area_done
                clr     wv_index
                ldaa    #MAX_ALIVE
                staa    alive_max
                rts

; The area is won when all its waves are launched and every alien is gone
; (later: when its boss is destroyed).
victory_check:
                tst     mode
                bne     vc_done
                tst     dead
                bne     vc_done
                ldaa    boss_state
                cmpa    #BS_DEFEATED
                beq     vc_win
                tst     area_done       ; waves cleared: the boss comes
                beq     vc_done
                tst     alive
                bne     vc_done
                tst     boss_state
                bne     vc_done
                jmp     boss_start
vc_win:
                clr     boss_state
                ldaa    area            ; the last area's boss (the fortress):
                cmpa    #NAREAS-1       ; the finale
                bne     vc_win_f1
                jmp     finale_begin
vc_win_f1:      ldaa    #MODE_SALUTE
                staa    mode
                ldaa    #SALUTE_TIME
                staa    mode_t
                jsr     score_1000
                ldx     #fx_salute
                ldaa    #9
                jsr     snd_play
                ldd     #s_cleared
                jmp     banner_show
vc_done:        rts

; ---------------------------------------------------------------- boss
; The boss: a big sprite (boss) with its weak spot, the core (core), a
; separate small sprite drawn over the boss's opening and moved with it.
; Only shots on the core do damage; the hull just pings them away.  It
; descends from under the status bar, sways and fires its cannons while
; escorts loop around it, and explodes when its core is spent.

boss_start:
                jsr     ovl_need        ; (loaded on the map screen already;
                ldaa    #BS_ENTER       ; this is a safety net)
                staa    boss_state
                ldab    area            ; this area's boss (boss_tab)
                ldaa    #BT_SIZE
                mul
                addd    #boss_tab
                std     bm_xy
                ldx     bm_xy
                ldaa    BT_ENV,x
                staa    env_left
                ldaa    BT_EHP,x        ; (one more a round, after the first)
                adda    dlev
                staa    env_hp
                staa    env_hp+1
                ldd     OVL_BASE        ; the hull (the overlay's header)
                std     boss+O_SPR
                ldd     BT_CANS,x
                std     boss_can
                clr     boss_ci
                ldaa    BT_EDY,x
                staa    boss_edy
                ldaa    BT_W,x          ; box width: the right envoy beside
                adda    #2              ; it, and the visible width
                staa    boss_edxr
                suba    #4
                staa    boss_w
                ldaa    BT_H,x
                staa    boss_h
                ldaa    BT_STOP,x
                staa    boss_y
                ldaa    BT_STILL,x
                staa    boss_still
                ldaa    BT_ALIVE,x      ; escorts flying at once
                staa    alive_max
                ldd     BT_ESC,x
                std     wv_start
                ldaa    BT_X,x
                ldx     #boss
                staa    O_X,x
                ldaa    boss_h          ; just above the top, hidden
                nega
                staa    O_Y,x
                clr     O_XF,x
                clr     O_YF,x
                ldd     #0
                std     O_DX,x
                ldd     #BOSS_DESCEND
                std     O_DY,x
                ldd     #0              ; no envoy patrol (yet)
                std     env_ofs
                std     env_v
                ldaa    #BOSS_XMIN      ; the sway range
                ldab    #BOSS_XMAX
                tst     env_left
                beq     bst_noenv
                ldd     OVL_BASE+2      ; the envoys
                ldx     #env1
                std     O_SPR,x
                ldx     #env2
                std     O_SPR,x
                ldaa    #BOSS_EXMIN
                ldab    #BOSS_EXMAX
bst_noenv:      staa    boss_xmin
                stab    boss_xmax
                ldx     bm_xy           ; the cores: a count, then column,
                ldx     BT_CORES,x      ; row, stage and hits each
                stx     ba_xy           ; (scratch until boss_attach)
                ldaa    0,x
                staa    ncores
                clr     ci
bst_core:       ldaa    ci
                cmpa    ncores
                bcc     bst_free
                ldx     ba_xy
                asla
                asla
                tab
                abx                     ; X = its entry - 1
                ldd     1,x             ; offsets
                std     bm_dx           ; (scratch)
                ldd     3,x             ; stage, hits
                ldx     #boss_hp
                pshb
                ldab    ci
                abx
                pulb
                addb    dgap            ; hits (two more a round)
                stab    0,x
                staa    3*NCORE,x       ; stage
                clr     NCORE,x         ; no flash
                ldab    #CS_OPEN        ; open from the start: stage 0, no
                tsta                    ; envoys
                bne     bst_shut
                tst     env_left
                beq     bst_st
bst_shut:       ldab    #CS_SHUT
bst_st:         stab    2*NCORE,x
                ldd     bm_dx
                staa    4*NCORE,x
                stab    5*NCORE,x
                ldaa    ci
                jsr     core_look
                bra     bst_cnext
bst_free:       ldx     #core_s         ; no such core: free its object
                ldab    ci
                abx
                ldaa    #CS_DEAD
                staa    0,x
                ldaa    ci
                jsr     core_obj
                ldd     #0
                std     O_SPR,x
                std     AN_PTR,x
bst_cnext:      inc     ci
                ldaa    ci
                cmpa    #NCORE
                bne     bst_core
                tst     boss_still      ; a fortress powers up on arrival:
                beq     bst_parts       ; its cores and envoys appear then
                jsr     fort_hide       ; (riding down with it over the
bst_parts:      jsr     boss_attach     ; status bar cost too much)
                ldaa    env_fire
                staa    env_t
                ldx     wv_start
                stx     wv_ptr
                jsr     wave_begin
                clr     area_done
                ldaa    #WARN_TIME      ; escorts after the warning
                staa    wv_timer
                ldaa    boss_fire
                staa    boss_t
                ldx     #fx_bossin      ; (a jingle's priority: a bonus's
                ldaa    #9              ; beeps still sounding mustn't stop
                jsr     snd_play        ; the warning starting)
                ldd     #s_bossin
                jsr     banner_show
                ldaa    #WARN_TIME
                staa    banner_t
                inc     banner_fl       ; flashing
                rts

bl_r0:          rts
boss_logic:
                ldaa    boss_state
                beq     bl_r0
                cmpa    #BS_DEFEATED
                beq     bl_r0
                cmpa    #BS_DYING
                bne     boss_logic_f1
                jmp     boss_dying
boss_logic_f1:  ldx     #boss
                cmpa    #BS_ENTER
                bne     bl_fight
                ldaa    O_Y,x           ; descending: arrived?
                cmpa    boss_y
                bcs     bl_core         ; (still above: 224-255 counts as high)
                cmpa    #192
                bcc     bl_core
                ldd     #0
                std     O_DY,x
                tst     boss_still      ; a fortress stays where it is, and
                beq     bl_sway         ; its envoys patrol beside it (or
                ldd     #ENV_PATROL_V   ; their bombs fall in one column,
                std     env_v           ; right where the ship must be to
                jsr     fort_show       ; shoot them); its cores and envoys
                ldx     #boss           ; appear now
                ldd     #0
                bra     bl_arr
bl_sway:        ldd     #BOSS_SPEED
bl_arr:         std     O_DX,x
                ldaa    #BS_FIGHT
                staa    boss_state
                bra     bl_core
bl_fight:
                ldd     O_X,x           ; sway between the sides
                addd    O_DX,x
                cmpa    boss_xmin
                bcs     bl_fight_f1
                cmpa    boss_xmax
                bcs     bl_fight_f2
bl_fight_f1:    ldd     #0
                subd    O_DX,x
                std     O_DX,x
bl_fight_f2:    dec     boss_t          ; the cannons, in turn
                bne     bl_core
                ldaa    boss_fire
                staa    boss_t
                ldx     boss_can        ; the next cannon in the list (a
                ldab    boss_ci         ; count, then x and y offsets each)
                incb
                cmpb    0,x
                bls     bl_fight_f3
                ldab    #1
bl_fight_f3:    stab    boss_ci
                aslb
                abx
                dex                     ; X = its entry
                ldd     0,x
                ldx     #boss
                adda    O_X,x
                addb    O_Y,x
                jsr     bomb_at
bl_core:
                ldaa    boss_state      ; the envoys' patrol (env_v is 0 but
                cmpa    #BS_FIGHT       ; for a fortress's)
                bne     bl_core_f1
                ldd     env_ofs
                addd    env_v
                std     env_ofs
                cmpa    #ENV_PATROL     ; past either end (0: beside the
                bge     bl_core_f2      ; hull, ENV_PATROL out): turn back
                tsta
                bpl     bl_core_f1
bl_core_f2:     ldd     #0
                subd    env_v
                std     env_v
bl_core_f1:     jsr     env_bomb
                jsr     boss_attach
                clr     ci              ; a hit core is white for a moment
bl_flash:       ldx     #core_fl
                ldab    ci
                abx
                tst     0,x
                beq     bl_flash_f1
                dec     0,x
                bne     bl_flash_f1
                ldaa    ci
                jsr     core_look
bl_flash_f1:    inc     ci
                ldaa    ci
                cmpa    ncores
                bcs     bl_flash
bl_r:           rts

fort_hide:                              ; a fortress's cores and envoys off
                clra                    ; until it arrives
fort_hide_b1:   psha
                jsr     core_obj
                ldd     #0
                std     O_SPR,x
                pula
                inca
                cmpa    ncores
                bcs     fort_hide_b1
                ldd     #0
                std     env1+O_SPR
                std     env2+O_SPR
                rts
fort_show:                              ; ... and on: the cores as their
                clr     ci              ; states say, the envoys if any
fort_show_b1:   ldaa    ci
                jsr     core_look
                inc     ci
                ldaa    ci
                cmpa    ncores
                bcs     fort_show_b1
                tst     env_left
                beq     fort_show_r
                ldd     OVL_BASE+2
                std     env1+O_SPR
                std     env2+O_SPR
fort_show_r:    rts

; A = a core's index: X = its object.  Uses A, B.
core_obj:
                ldab    #OBJ_SIZE
                mul
                addd    #core
                pshb
                psha
                pulx
                rts

; A = a core's index: show it shut or open, as its state says.  Uses A,
; B, X.
core_look:
                psha
                ldx     #core_s
                tab
                abx
                ldab    0,x
                pula
                pshb
                bsr     core_obj
                pulb
                cmpb    #CS_OPEN
                beq     core_look_f1
                ldd     #coreshut_dsc
                bra     core_look_f2
core_look_f1:   ldd     #core_dsc
core_look_f2:   std     O_SPR,x
                rts

; A = a stage: open its shut cores (with a sound if any opened)
open_stage:
                staa    os_st
                clr     os_i
                clr     os_n
os_loop:        ldaa    os_i
                cmpa    ncores
                bcc     os_done
                ldx     #core_s
                tab
                abx
                ldaa    0,x
                cmpa    #CS_SHUT
                bne     os_next
                ldaa    NCORE,x         ; its stage (core_st follows core_s)
                cmpa    os_st
                bne     os_next
                ldaa    #CS_OPEN
                staa    0,x
                inc     os_n
                ldaa    os_i
                jsr     core_look
os_next:        inc     os_i
                bra     os_loop
os_done:        tst     os_n
                beq     os_r
                ldx     #fx_open
                ldaa    #4
                jmp     snd_play
os_r:           rts

; A = a stage ($FF: any): B = how many of its cores are left
cores_alive:
                staa    os_st
                clrb
                ldx     #core_s
                ldaa    ncores
                staa    os_i
ca2_loop:       tst     os_i
                beq     ca2_done
                ldaa    0,x
                cmpa    #CS_DEAD
                beq     ca2_next
                ldaa    os_st
                bmi     ca2_yes
                cmpa    NCORE,x
                bne     ca2_next
ca2_yes:        incb
ca2_next:       inx
                dec     os_i
                bra     ca2_loop
ca2_done:       rts

; The core and the flying envoys ride with the hull: placed relative to
; it, with its velocity.  Exploding envoys stay where they died and play
; out their explosion.
boss_attach:
                ldx     #boss
                ldd     O_DX,x
                std     ba_dx
                ldd     O_DY,x
                std     ba_dy
                ldaa    O_X,x
                ldab    O_Y,x
                std     ba_xy
                ldaa    O_XF,x          ; (with its fractions, or a part's
                ldab    O_YF,x          ; steps drift against the hull's:
                std     ba_f            ; it vibrates)
                clr     ci              ; the cores (exploding ones play out
ba_core:        ldaa    ci              ; their explosion where they are)
                cmpa    ncores
                bcc     ba_cored
                jsr     core_obj
                ldd     O_SPR,x
                beq     ba_cnext
                ldd     AN_PTR,x
                beq     ba_cplace
                jsr     obj_anim_step
                bra     ba_cnext
ba_cplace:      pshx
                ldx     #core_dx
                ldab    ci
                abx
                ldd     ba_xy
                adda    0,x
                addb    NCORE,x         ; (core_dy follows core_dx)
                pulx
                jsr     ba_place
ba_cnext:       inc     ci
                bra     ba_core
ba_cored:       ldx     #env1
                ldd     O_SPR,x
                beq     ba_env2
                ldd     AN_PTR,x
                beq     ba_l
                jsr     obj_anim_step
                bra     ba_env2
ba_l:           ldd     ba_xy
                suba    #ENV_DXL
                addb    boss_edy
                bsr     ba_place
                ldd     O_X,x           ; the left one patrols leftwards
                subd    env_ofs         ; (out, never into the hull)
                std     O_X,x
                ldd     O_DX,x
                subd    env_v
                std     O_DX,x
ba_env2:        ldx     #env2
                ldd     O_SPR,x
                beq     ba_done
                ldd     AN_PTR,x
                beq     ba_r
                jmp     obj_anim_step
ba_r:           ldd     ba_xy
                adda    boss_edxr
                addb    boss_edy
                bsr     ba_place
ba_patrol:                              ; the right one rightwards (a
                ldd     O_X,x           ; fortress's patrol; 0 for the others)
                addd    env_ofs
                std     O_X,x
                ldd     O_DX,x
                addd    env_v
                std     O_DX,x
                rts
ba_place:                               ; X = object, A, B = x, y; the hull's
                staa    O_X,x           ; fractions and speed
                stab    O_Y,x
                ldd     ba_f
                staa    O_XF,x
                stab    O_YF,x
                ldd     ba_dx
                std     O_DX,x
                ldd     ba_dy
                std     O_DY,x
ba_done:        rts

; The envoys bomb in turn, fast and outside the aliens' spray rhythm.
env_bomb:
                tst     env_left
                beq     eb_done
                ldaa    boss_state
                cmpa    #BS_FIGHT
                bne     eb_done
                dec     env_t
                bne     eb_done
                ldaa    env_fire
                staa    env_t
                com     env_side
                ldx     #env1
                tst     env_side
                beq     eb_try
                ldx     #env2
eb_try:         ldd     AN_PTR,x        ; that one gone?  Then no bomb this
                bne     eb_done         ; turn: the survivor keeps its own
                ldd     O_SPR,x         ; pace (taking its partner's turns
                beq     eb_done         ; too, it was nearly unbeatable)
eb_fire:        ldaa    O_X,x
                adda    #envoy_PADX+3-bomb_PADX
                ldab    O_Y,x
                addb    #envoy_H-envoy_PADY-bomb_PADY
                jmp     bomb_force
eb_done:        rts

; a shot (ht_a) against the boss: carry set if it hit anything
bs_miss0:       clc
                rts
boss_shot:
                ldaa    boss_state
                cmpa    #BS_FIGHT
                bne     bs_miss0
                ldx     ht_a            ; quick reject: the shot below the boss
                ldaa    O_Y,x
                ldx     #boss
                suba    O_Y,x
                cmpa    boss_h
                bcc     bs_miss0
                ldx     #env1           ; the envoys
                jsr     env_test
                bcs     bs_hit
                ldx     #env2
                jsr     env_test
                bcs     bs_hit
                clr     ci              ; in a core's column?  (The quick
bs_cloop:       ldaa    ci              ; reject above already put the shot
                cmpa    ncores          ; in the boss's rows, so x decides.)
                bcc     bs_hull
                ldx     #core_s
                tab
                abx
                ldaa    0,x
                cmpa    #CS_DEAD        ; (a destroyed core's channel just
                beq     bs_cnext        ; leads to the hull)
                ldaa    ci
                jsr     core_obj
                stx     bs_obj
                ldx     ht_a
                ldaa    O_X,x
                ldx     bs_obj
                suba    O_X,x
                adda    #shot_PADX-core_PADX
                cmpa    #4              ; (a core is 4 pixels wide)
                bcc     bs_cnext
                ldx     ht_a            ; up the channel: has it reached the
                ldaa    O_Y,x           ; core's bottom row yet?
                adda    #shot_PADY
                ldx     bs_obj
                suba    O_Y,x
                suba    #core_PADY+4
                bcc     bs_miss         ; not yet: it flies on
                ldx     #core_s
                ldab    ci
                abx
                ldaa    0,x
                cmpa    #CS_OPEN        ; shut: it pings like the hull
                bne     bs_ping
                jmp     bs_core
bs_cnext:       inc     ci
                bra     bs_cloop
bs_hull:        ldx     ht_a            ; the hull: is the shot within its
                ldaa    O_X,x           ; width?
                adda    #shot_PADX
                ldx     #boss
                suba    O_X,x
                suba    #boss1_PADX
                cmpa    boss_w
                bcc     bs_miss
bs_ping:        ldx     #fx_ping        ; the hull: the shot bounces off
                ldaa    #1
                jsr     snd_play
bs_hit:         sec
                rts
bs_miss:        clc
                rts
bs_core:                                ; core ci is hit
                jsr     score_50
                ldaa    ci              ; flash white
                jsr     core_obj
                ldd     #corehit_dsc
                std     O_SPR,x
                ldx     #boss_hp
                ldab    ci
                abx
                ldaa    #6
                staa    NCORE,x
                dec     0,x
                beq     core_down
                ldx     #fx_clang
                ldaa    #2
                jsr     snd_play
                sec
                rts
core_down:                              ; destroyed (X = its boss_hp entry)
                clr     NCORE,x
                ldaa    #CS_DEAD
                staa    2*NCORE,x
                ldaa    #$FF            ; the last one: the boss is done for
                jsr     cores_alive
                tstb
                bne     cd_more
                jmp     boss_die
cd_more:        ldaa    ci              ; otherwise it explodes ...
                jsr     core_obj
                ldd     #anim_boom
                jsr     boom_start
                jsr     score_500
                ldx     #fx_boom
                ldaa    #3
                jsr     snd_play
                clra                    ; ... and when stage 0 is gone,
                jsr     cores_alive     ; stage 1 opens
                tstb
                bne     cd_done
                ldaa    #1
                jsr     open_stage
cd_done:        sec
                rts

; X = an envoy: if the shot ht_a hits it, take a hit (carry set)
env_test:
                ldd     O_SPR,x
                beq     et_miss
                ldd     AN_PTR,x
                bne     et_miss
                stx     ht_b
                ldaa    O_X,x           ; quick reject: the shot more than an
                ldx     ht_a            ; envoy's width to either side
                suba    O_X,x
                adda    #envoy_W
                cmpa    #2*envoy_W
                bcc     et_miss
                jsr     hit_test
                bcc     et_miss
                ldaa    #0              ; which envoy: 0 left, 1 right
                ldx     ht_b
                cpx     #env1
                beq     et_which
                inca
et_which:       ldx     #env_hp
                tab
                abx
                dec     0,x
                beq     et_down
                ldx     #fx_clang
                ldaa    #2
                jsr     snd_play
                sec
                rts
et_down:        ldx     ht_b            ; destroyed: it explodes ...
                ldd     #0
                std     O_DX,x
                std     O_DY,x
                ldd     #anim_boom
                jsr     boom_start
                jsr     score_500
                ldx     #fx_boom
                ldaa    #3
                jsr     snd_play
                dec     env_left        ; ... and when both are gone the
                bne     et_hit          ; first cores open (and a fortress,
                tst     boss_still      ; unguarded, sends two more escorts)
                beq     et_down_f1
                ldaa    alive_max
                adda    #2
                staa    alive_max
et_down_f1:     clra
                jsr     open_stage
et_hit:         sec
                rts
et_miss:        clc
                rts

boss_die:                               ; the core is spent
                ldaa    #BS_DYING
                staa    boss_state
                ldaa    #DIE_TIME
                staa    boss_t
                inc     area_done       ; no more escorts ...
                ldx     #boss
                ldd     #0
                std     O_DX,x
                std     O_DY,x
                clra                    ; the cores stop with it
bdie_core:      psha
                jsr     core_obj
                ldd     #0
                std     O_DX,x
                std     O_DY,x
                pula
                inca
                cmpa    #NCORE
                bne     bdie_core
                ldx     #aliens         ; ... and those flying explode with it
boss_die_b1:    stx     obj
                ldd     O_SPR,x
                beq     boss_die_f1
                ldd     AN_PTR,x
                bne     boss_die_f1
                ldd     #anim_boom
                jsr     boom_start
                dec     alive
boss_die_f1:    ldx     obj
                ldab    #OBJ_SIZE
                abx
                cpx     #aliens_end
                bne     boss_die_b1
                ldx     #fx_bossdie
                ldaa    #6
                jsr     snd_play
                sec
                rts

boss_dying:                             ; explosions all over the hull
                dec     boss_t
                bne     boss_dying_f0
                jmp     bd_gone
boss_dying_f0:  ldaa    boss_t
                anda    #7
                beq     boss_dying_f2
                rts
boss_dying_f2:
                ldx     #aliens         ; a burst in a free slot
boss_dying_b1:  ldd     O_SPR,x
                beq     boss_dying_f1
                ldab    #OBJ_SIZE
                abx
                cpx     #aliens_end
                bne     boss_dying_b1
                rts
boss_dying_f1:  stx     obj
                jsr     rnd             ; somewhere on the hull
                ldaa    boss_w
                suba    #6
                mul
                ldx     #boss
                adda    O_X,x
                staa    bm_xy
                jsr     rnd
                ldaa    boss_h
                suba    #10
                mul
                ldx     #boss
                adda    O_Y,x
                ldx     obj
                staa    O_Y,x
                ldaa    bm_xy
                staa    O_X,x
                ldd     #0
                std     O_DX,x
                std     O_DY,x
                ldd     #anim_boom
                jmp     boom_start
bd_gone:
                ldx     #env1           ; the end: the boss is gone
                jsr     obj_erase
                ldx     #env2
                jsr     obj_erase
                ldx     #env1
                ldd     #0
                std     O_SPR,x
                std     AN_PTR,x
                ldx     #env2
                std     O_SPR,x
                std     AN_PTR,x
                clra
bdg_core:       psha
                jsr     core_obj
                pshx
                jsr     obj_erase
                pulx
                ldd     #0
                std     O_SPR,x
                std     AN_PTR,x
                pula
                inca
                cmpa    #NCORE
                bne     bdg_core
                ldx     #boss
                jsr     obj_erase
                ldx     #boss
                ldd     #0
                std     O_SPR,x
                jsr     score_5000
                ldaa    #BS_DEFEATED
                staa    boss_state
bd_r:           rts

score_50:                               ; score += 50 (BCD)
                ldaa    score+2
                adda    #$50
                jmp     sc_lo
score_500:                              ; score += 500 (BCD)
                ldaa    score+1
                adda    #$05
                jmp     sc_mid
score_5000:                             ; score += 5000 (BCD)
                ldaa    score+1
                adda    #$50
                jmp     sc_mid

; ---------------------------------------------------------------- finale
; The fortress has fallen: all four bosses beaten.  A victory song,
; fireworks all over the screen and a run of banners (the ship holds
; still, untouchable), a bonus for every ship left, then the warp on to
; the next round.
finale_begin:
                ldaa    #MODE_FINALE
                staa    mode
                ldd     #FIN_TIME
                std     fin_t
                jsr     score_5000      ; (the area's bonus: bigger)
                ldx     #fx_finale
                ldaa    #9
                jsr     snd_play
                ldd     #s_fallen       ; (the first one stays longest,
                bsr     fin_banner      ; flashing)
                ldaa    #FIN_TIME-FIN_T1-5
                staa    banner_t
                inc     banner_fl
                rts
fin_banner:                             ; D = banner: up until the next one
                jsr     banner_show
                ldaa    #FIN_T1-FIN_T2-5
                staa    banner_t
                rts

finale_logic:
                ldx     #ship           ; hold still
                ldd     #0
                std     O_DX,x
                std     O_DY,x
                jsr     ship_align
                ldd     fin_t
                subd    #1
                std     fin_t
                bne     fin_f1
                jmp     warp_begin      ; on to the next round
fin_f1:         subd    #FIN_T1
                bne     fin_f2
                ldd     #s_alldone
                bsr     fin_banner
fin_f2:         ldd     fin_t
                subd    #FIN_T2
                bne     fin_f2b
                jsr     fin_bonus
fin_f2b:        ldd     fin_t           ; "...BUT THE ALIEN BLORPS / THREATEN
                subd    #FIN_TB         ; ANOTHER GALAXY!": on to the next
                bne     fin_f3          ; round
                ldd     #s_blorps
                jsr     fin_banner
                ldd     #s_blorps2
                std     banner_p2
                ldaa    #FIN_TB-FIN_T3-5 ; (up until ROUND n)
                staa    banner_t
fin_f3:         ldd     fin_t
                subd    #FIN_T3
                bne     fin_f4
                ldaa    round           ; the next round (shown up to 9)
                cmpa    #9
                bcc     fin_f5
                inca
                staa    round
                jsr     set_diff        ; (harder from now on)
fin_f5:         jsr     round_banner
fin_f4:         ldd     fin_t           ; fireworks, every 4 frames
                subd    #FIN_T4
                bcs     fin_r
                ldab    fin_t+1
                andb    #3
                bne     fin_r
                ; fall through
firework:                               ; a burst in a free slot, anywhere
                ldx     #aliens
firework_b1:    ldd     O_SPR,x
                beq     firework_f1
                ldab    #OBJ_SIZE
                abx
                cpx     #aliens_end
                bne     firework_b1
fin_r:          rts
firework_f1:    stx     obj
                jsr     rnd             ; x 4-115, y 16-159
                ldaa    #112
                mul
                adda    #4
                staa    bm_xy
                jsr     rnd
                ldaa    #144
                mul
                adda    #16
                ldx     obj
                staa    O_Y,x
                ldaa    bm_xy
                staa    O_X,x
                clr     O_XF,x
                clr     O_YF,x
                ldd     #0
                std     O_DX,x
                std     O_DY,x
                ldd     #anim_boom
                jmp     boom_start

; The difficulty for the round: dlev = round - 1 (at most DIFF_MAX).
; Each step: bombs a quarter row a frame faster (2 -> 3), the bomb
; spray window 15 frames longer (36 -> 96 of 128), the gap between bombs
; a frame shorter (9 -> 5), cannon shots 3 frames and envoy bombs 2
; frames apart less, waves launched 2 frames closer, two more hits for
; each boss core and one more for each envoy.  Round 1 is as designed.
set_diff:
                ldaa    round           ; even rounds: the aliens' orange and
                anda    #1              ; blue swapped (the old arcade trick)
                eora    #1
                bsr     al_colors
                ldaa    round
                deca
                cmpa    #DIFF_MAX
                bls     set_diff_f1
                ldaa    #DIFF_MAX
set_diff_f1:    staa    dlev
                ldab    #15
                mul
                addb    #SPRAY_ON
                stab    spray_on
                ldaa    #BOMB_GAP       ; (at least 4: 3 left the busiest
                suba    dlev            ; rounds near the frame budget)
                cmpa    #4
                bcc     set_diff_f2
                ldaa    #4
set_diff_f2:    staa    bomb_gap
                ldaa    dlev            ; bombs a quarter row a frame faster
                ldab    #$40            ; a round
                mul
                addd    #BOMB_SPEED
                std     bomb_spd
                ldaa    dlev
                ldab    #3
                mul
                negb
                addb    #BOSS_FIRE
                stab    boss_fire
                ldaa    dlev
                asla
                staa    dgap
                nega
                adda    #ENV_FIRE
                staa    env_fire
                rts

al_colors:                              ; A = 1: aliens swapped, 0: as drawn
                cmpa    al_flip         ; (col_swap swaps them; a color
                beq     al_colors_r     ; check swap on top still works)
                staa    al_flip
                ldx     #al_sprites
                jmp     col_swap
al_colors_r:    rts

round_banner:                           ; "ROUND n" (the current round)
                ldaa    round
                adda    #'0'
                staa    s_round+2+6
                ldd     #s_round
                jmp     fin_banner

fin_bonus:                              ; 10000 for every ship left: those
                ldab    lives           ; in reserve and the one flying
                incb
fin_bonus_b1:   ldaa    score           ; (score+0 holds the 100000s and
                adda    #1              ; 10000s, BCD)
                daa
                staa    score
                decb
                bne     fin_bonus_b1
fin_bonus_f1:   ldaa    #1
                staa    status_t
                ldd     #s_bonus
                jmp     fin_banner

; ---------------------------------------------------------------- warp
warp_x:                                 ; A = the ship's x on the warp
                ldaa    ship+O_X        ; sprite's shift (3), inside the
                oraa    #3              ; ship's range
                cmpa    #SHIP_XMAX
                bls     warp_x_r
                suba    #4
warp_x_r:       rts

ship_align:                             ; holding still before the warp:
                ldaa    frame_count     ; glide a pixel every other frame
                anda    #1              ; onto warp_x (no jump at blast-off)
                bne     ship_align_r
                bsr     warp_x
                cmpa    ship+O_X
                beq     ship_align_r
                bhi     ship_align_f1
                dec     ship+O_X
                rts
ship_align_f1:  inc     ship+O_X
ship_align_r:   rts

warp_begin:
                ldaa    #MODE_WARP
                staa    mode
                clr     wp_wrapped
                ldx     #ship
                jsr     obj_erase       ; (the flame version is a new shape)
                ldx     #ship
                ldd     #shipw1_dsc
                std     O_SPR,x
                bsr     warp_x          ; compiled for shift 3 only (the
                staa    O_X,x           ; arrival x, (128-ship_W)/2, is on
                ldaa    O_Y,x           ; it): x on it (the salute has
                suba    #shipw1_PADY-ship_PADY ; glided there already), and
                staa    O_Y,x           ; the art on the same rows (a
                                        ; taller halo above it)
                ldx     #fx_warp        ; (a jingle's priority: the roar
                ldaa    #9              ; must not lose to a tune's last
                jmp     snd_play        ; notes)

warp_logic:                             ; blast off: up, behind the status bar
                ldx     #ship
                bsr     wp_flame
                ldd     O_DY,x          ; accelerate to 4 rows a frame
                subd    #$0018
                cmpa    #$FC
                bge     warp_logic_f1
                ldd     #$FC00
warp_logic_f1:  std     O_DY,x
                ldaa    frame_count     ; the stars speed up
                anda    #7
                bne     warp_logic_f2
                ldaa    warpf
                cmpa    #6
                bcc     warp_logic_f2
                inc     warpf
warp_logic_f2:  ldaa    O_Y,x           ; wholly above the top (-32..-22)?
                cmpa    #224
                bcs     wp_r
                cmpa    #235
                bcc     wp_r
                jsr     obj_erase       ; gone
                ldx     #ship
                ldd     #0
                std     O_SPR,x
                std     O_DY,x
                ldaa    #MODE_COAST
                staa    mode
                ldaa    #COAST_TIME
                staa    mode_t
wp_r:           rts

wp_flame:                               ; X = ship: the afterburner flickers
                ldaa    frame_count
                anda    #2
                beq     wp_flame_f1
                ldd     #shipw2_dsc
                bra     wp_flame_f2
wp_flame_f1:    ldd     #shipw1_dsc
wp_flame_f2:    std     O_SPR,x
                rts

coast_logic:                            ; just stars for a moment, then the
                dec     mode_t          ; next area: the map, then the ship
                bne     wp_r            ; rises in from the bottom
                inc     area
                ldaa    area
                cmpa    #NAREAS
                bcs     coast_logic_f1
                clr     area            ; after the last: round again
coast_logic_f1: jsr     area_begin
                jsr     map_show
                ldx     #ship
                ldaa    #(128-ship_W)/2
                staa    O_X,x
                ldaa    #224-shipw1_H   ; in the bottom gutter (rows 192-223:
                                        ; past 223 is BSS, so all of it fits)
                staa    O_Y,x
                clr     O_XF,x
                clr     O_YF,x
                ldd     #0
                std     O_DX,x
                ldd     #$FC00
                std     O_DY,x
                bsr     wp_flame
                ldaa    #4
                staa    warpf
                ldaa    #MODE_ARRIVE
                staa    mode
                rts

arrive_logic:                           ; rise in and brake to a stop
                ldx     #ship
                bsr     wp_flame
                ldaa    O_Y,x
                cmpa    #200
                bcc     wp_r            ; still below the screen
                ldaa    frame_count     ; the stars slow down
                anda    #3
                bne     arrive_logic_f1
                ldaa    warpf
                cmpa    #1
                beq     arrive_logic_f1
                dec     warpf
arrive_logic_f1:
                ldd     O_DY,x
                addd    #$0028
                bmi     arrive_logic_f2
                jsr     obj_erase       ; stopped: back to the normal ship
                ldx     #ship           ; (its art on the same rows)
                ldaa    O_Y,x
                adda    #shipw1_PADY-ship_PADY
                staa    O_Y,x
                ldd     #ship_dsc
                std     O_SPR,x
                ldd     #0
                std     O_DY,x
                ldaa    #1
                staa    warpf
                clr     mode            ; play: the area's waves begin
                ldaa    #1
                staa    status_t
                rts
arrive_logic_f2:
                std     O_DY,x
                rts

; ---------------------------------------------------------------- map
; The map screen: PLAYER 1, the area, a strip of the areas with their
; checkpoints, and the ship at its progress.  Play is paused meanwhile
; (sound goes on).
map_show:
                jsr     cls
                ldaa    #TXT_WHITE
                staa    txt_col
                ldx     #TXT_AT(16,12)
                ldd     #s_player
                jsr     txt_str
                ldaa    col_o
                staa    txt_col
                ldx     #TXT_AT(28,13)
                ldd     #s_area
                jsr     txt_str
                ldaa    area
                adda    #'1'
                jsr     txt_char
                ldx     #TXT_AT(MAP_BOTTOM-NAREAS*MAP_SEG,MAP_COL) ; the strip
map_show_b1:    ldaa    col_b
                anda    #$30
                staa    0,x
                ldab    #ROW_BYTES
                abx
                cpx     #TXT_AT(MAP_BOTTOM,MAP_COL)
                bne     map_show_b1
                clra                    ; the areas' labels
                jsr     map_label
                ldaa    #1
                jsr     map_label
                ldaa    #2
                jsr     map_label
                ldaa    #3
                jsr     map_label
                ldaa    col_o           ; a checkpoint at the top of each area
                staa    txt_col
                ldx     #TXT_AT(MAP_BOTTOM-1*MAP_SEG,MAP_COL)
                bsr     map_mark
                ldx     #TXT_AT(MAP_BOTTOM-2*MAP_SEG,MAP_COL)
                bsr     map_mark
                ldx     #TXT_AT(MAP_BOTTOM-3*MAP_SEG,MAP_COL)
                bsr     map_mark
                ldx     #TXT_AT(MAP_BOTTOM-4*MAP_SEG,MAP_COL)
                bsr     map_mark
                ldaa    area            ; the ship: area base + progress
                inca
                ldab    #MAP_SEG
                mul
                stab    mp_t
                ldaa    #MAP_BOTTOM+MAP_SEG
                suba    mp_t
                suba    #ship_H-ship_PADY
                ldab    wv_index        ; 3 rows per wave, up to the area's
                cmpb    #AREA_WAVES     ; 8 (a boss's escort waves count on,
                bls     map_show_f4     ; but the ship stays at the
                ldab    #AREA_WAVES     ; checkpoint)
map_show_f4:    stab    mp_t
                aslb
                addb    mp_t
                stab    mp_t
                suba    mp_t
                tab
                ldaa    #MAP_COL*4-3    ; centred on the strip
                ldx     #ship_hr
                jsr     spr_art
                ldaa    #MAP_TIME
                staa    mp_t
                jsr     ovl_need        ; this area's boss, if not in memory
                tsta                    ; (A = frames the load took): the
                beq     map_show_b2     ; map's time includes it
                if      DEBUG
                jsr     ld_show
                ldaa    ld_t
                endif
                cmpa    #MAP_TIME
                bcs     map_show_f3
                ldaa    #MAP_TIME-1
map_show_f3:    nega
                adda    #MAP_TIME
                staa    mp_t
map_show_b2:    jsr     frame_wait
                jsr     snd_frame
                dec     mp_t
                bne     map_show_b2
                jsr     cls             ; back to play: everything redraws
                jsr     stars_init
                ldaa    #1
                staa    status_t
                rts

map_mark:                               ; X = row start: a checkpoint marker
                ldaa    #$FC            ; (a 3-pixel bar, 3 rows)
                anda    col_o
                staa    0,x
                staa    ROW_BYTES,x
                staa    2*ROW_BYTES,x
                rts                     ; (what waits there is a mystery)

; A = area number (0-3): its label to the left of the strip, white for
; the current area, blue for the others
map_label:
                psha
                ldab    col_b
                cmpa    area
                bne     map_label_f1
                ldab    #TXT_WHITE
map_label_f1:   stab    txt_col
                inca                    ; row = bottom - (n + 1/2) segments
                ldab    #MAP_SEG
                mul
                subb    #MAP_SEG/2
                negb
                addb    #MAP_BOTTOM-2
                clra
                aslb                    ; D = row * 32
                rola
                aslb
                rola
                aslb
                rola
                aslb
                rola
                aslb
                rola
                addd    #SCREEN+MAP_COL-7
                std     mp_a
                ldx     mp_a
                ldd     #s_area
                jsr     txt_str
                pula
                adda    #'1'
                jmp     txt_char

score_1000:                             ; score += 1000 (BCD)
                ldaa    score+1
                adda    #$10
                daa
                staa    score+1
                ldaa    score
                adca    #0
                daa
                staa    score
                ldaa    #1
                staa    status_t
                rts

; ---------------------------------------------------------------- score
score_alien:                            ; an alien: 10 x the round (rounds
                ldaa    round           ; 1-9: the BCD tens digit)
                asla
                asla
                asla
                asla
                adda    score+2
                bra     sc_lo
score_10:                               ; score += 10 (BCD)
                ldaa    score+2
                adda    #$10
sc_lo:          daa
                staa    score+2
                ldaa    score+1
                adca    #0
sc_mid:         daa
                staa    score+1
                ldaa    score
                adca    #0
                daa
                staa    score
                ldaa    #1              ; show it at once
                staa    status_t
                rts

; The status bar (rows 0-6: SCORE 000000 ... SHIPS 3) is rendered into
; status_buf when the score or ships change (status_t set), and copied
; to the screen after the sprites whenever any sprite touched it, so it is
; always in front: aliens slide out from under it.
BUF_AT          function row,col,status_buf+(row)*ROW_BYTES+(col)

status_labels:                          ; a game's start: the bar from
                ldx     #status_buf     ; scratch (blank, the labels, then
                clra                    ; every figure); afterwards only the
                clrb                    ; figures change
status_labels_b1:
                std     0,x
                inx
                inx
                cpx     #status_buf+BAND*ROW_BYTES
                bne     status_labels_b1
                ldaa    col_o
                staa    txt_col
                ldx     #BUF_AT(1,0)    ; SCORE 000000  HI 000000  SHIPS 3
                ldd     #s_score
                jsr     txt_str
                ldx     #BUF_AT(1,14)
                ldd     #s_hi
                jsr     txt_str
                ldx     #BUF_AT(1,25)
                ldd     #s_ships
                jsr     txt_str
                bsr     su_hi
                ldaa    #1
                staa    status_t
status_update:                          ; the figures, when they changed
                tst     status_t        ; (only the digits: cheap on the
                beq     su_done         ; frames a kill already makes busy)
                clr     status_t
                ldaa    #TXT_WHITE
                staa    txt_col
                ldx     #BUF_AT(1,6)
                ldaa    #3
                staa    tx_n
                ldd     #score
                jsr     txt_bcd
                jsr     bonus_check     ; an extra ship?
                ldaa    lives
                adda    #'0'
                ldx     #BUF_AT(1,31)
                jsr     txt_char
                jsr     hi_check        ; a new record?  HI follows it
                bcc     su_shown
                bsr     su_hi
su_shown:       inc     sm_dirty        ; and show it
su_done:        rts
su_hi:          ldaa    #TXT_WHITE      ; the high score's digits
                staa    txt_col
                ldx     #BUF_AT(1,17)
                ldaa    #3
                staa    tx_n
                ldd     #hiscore
                jmp     txt_bcd

; Repair the status bar (rows 0-6) if sprites touched it (or it changed):
; rows 1-5 (the text) are copied from status_buf, rows 0 and 6 (always
; blank) are cleared.  Each row is a stack blast with interrupts off for
; that row only: S points at the row's end, and LDD n,X / PSHB / PSHA
; writes two bytes backwards (5 cycles a byte; ~3 for the blank rows).
status_repair:
                tst     sm_dirty
                bne     sr_go
                rts
sr_go:          clr     sm_dirty
                sts     sr_sp
                ldd     #SCREEN+ROW_BYTES-1     ; row 0: blank
                jsr     sr_blank
                ldx     #SCREEN+2*ROW_BYTES-1   ; rows 1-5: the text
                stx     sr_dst
                ldx     #status_buf+ROW_BYTES
                ldaa    #5
                staa    sr_n
sr_row:
                sei
                lds     sr_dst
k               set     ROW_BYTES-2
                rept    ROW_BYTES/2
                ldd     k,x
                pshb
                psha
k               set     k-2
                endm
                lds     sr_sp
                cli
                ldab    #ROW_BYTES
                abx
                pshx
                ldd     sr_dst
                addd    #ROW_BYTES
                std     sr_dst
                pulx
                dec     sr_n
                beq     sr_last
                jmp     sr_row
sr_last:        ldd     #SCREEN+7*ROW_BYTES-1   ; row 6: blank
                ; fall through
sr_blank:                               ; D = a row's last byte: clear the row
                std     sr_dst
                sts     sr_bsp          ; (its own S: a JSR may have called it)
                sei
                lds     sr_dst
                clra
                clrb
                rept    ROW_BYTES/2
                pshb
                psha
                endm
                lds     sr_bsp
                cli
sr_done:        rts

; ---------------------------------------------------------------- banner
; D = banner (fdb screen address, then the text): show it for BANNER_TIME
banner_show:
                std     banner_p
                ldaa    #BANNER_TIME
                staa    banner_t
                clr     banner_fl       ; steady unless the caller says
                ldx     #0              ; (one line unless the caller says)
                stx     banner_p2
                rts

banner_update:                          ; redraw it every 4th frame while up
                ldaa    banner_t        ; (the aliens fly across it), clear
                beq     bu_done         ; it at the end
                dec     banner_t
                beq     bu_clear
                tst     banner_fl       ; flashing: off every other 16 frames
                beq     bu_on
                ldaa    banner_t
                bita    #16
                bne     bu_on
                anda    #15             ; (off: cleared once, as it goes off,
                cmpa    #15             ; not every frame: 13 rows of clear
                beq     bu_clear        ; are expensive)
                rts
bu_on:          ldaa    banner_t
                anda    #3
                bne     bu_done
bu_draw:        ldaa    #TXT_WHITE
                staa    txt_col
                ldx     banner_p
                bsr     bu_line
                ldx     banner_p2       ; a second line?
                beq     bu_done
bu_line:        ldd     0,x             ; X = fdb screen, then the text
                pshb
                psha
                inx
                inx
                stx     bu_s
                pulx
                ldd     bu_s
                jmp     txt_str
bu_clear:
                ldx     #TXT_AT(BANNER_ROW+5,0) ; the rows in use: one line's,
                ldd     banner_p2               ; or two lines'
                beq     bu_clear_f1
                ldx     #TXT_AT(BANNER_ROW+13,0)
bu_clear_f1:    stx     bu_s
                ldx     #TXT_AT(BANNER_ROW,0)
                clra
                clrb
bu_clear_b1:    std     0,x
                inx
                inx
                cpx     bu_s
                bne     bu_clear_b1
bu_done:        rts

                if      DEBUG
ld_show:                                ; debug builds: "LOAD n" on the map
                ldaa    #TXT_WHITE      ; (frames the boss load took), for
                staa    txt_col         ; timing real SD cards
                ldx     #TXT_AT(186,1)
                ldd     #s_load
                jsr     txt_str
                ldaa    ld_t
                ldab    #100
                bsr     ld_digit
                ldab    #10
                bsr     ld_digit
                ldab    #1
ld_digit:                               ; A = the rest, B = 100/10/1: one
                stab    tx_n            ; digit at X; A = what's left
                ldab    #'0'
ld_digit_b1:    cmpa    tx_n
                bcs     ld_digit_f1
                suba    tx_n
                incb
                bra     ld_digit_b1
ld_digit_f1:    psha
                tba
                jsr     txt_char
                pula
                rts
                endif

; ---------------------------------------------------------------- high score
; The high score lives in STARFALL.HI on the SD card: "SF", the score
; (3 BCD bytes), a checksum (the sum of the five).  It's read at start-up
; and written when a game ends with a new record, through the BIOS's
; data-file calls (as BASIC's OPEN / PRINT# / CLOSE).  A missing or bad
; file means 0; card errors are ignored (the game never stops for it).

; The sortie bonus: a wave destroyed whole, of its own type only (another
; type's kill ends it), none of it leaving through the bottom, the kills
; at most SORTIE_GAP frames apart, the ship not lost, not a boss's
; escorts: 10 x an alien's value (100 x the round), and a ba-BING.
sortie_new:                             ; X = a wave launching its first: a
                tst     sortie_on       ; new sortie (unless the last one is
                beq     sortie_new_f1   ; still being finished off)
                tst     sortie_hit
                bne     sortie_r0
sortie_new_f1:  ldaa    W_COUNT,x
                staa    sortie_left
                ldd     W_DESC,x
                std     sortie_dsc
                clr     sortie_hit
                clr     sortie_t
                clr     sortie_on
                tst     boss_state      ; (not a boss's escorts)
                bne     sortie_r0
                inc     sortie_on
                rts
sortie_kill:                            ; X = the alien a shot destroyed
                tst     sortie_on
                beq     sortie_r0
                ldd     O_SPR,x
                subd    sortie_dsc
                beq     sortie_kill_f1
                tst     sortie_hit      ; another type: the run is broken
                beq     sortie_r0       ; (once it has begun: a straggler
                clr     sortie_on       ; from the last wave doesn't count)
sortie_r0:      rts
sortie_kill_f1:
                clr     sortie_t
                inc     sortie_hit
                dec     sortie_left
                bne     sortie_r
                ldx     #aliens         ; all of them?  Not while another of
sortie_cnt_b1:  cpx     ht_b            ; that type still flies (a straggler
                beq     sortie_cnt_f1   ; counted from the last wave, say):
                ldd     O_SPR,x         ; then it waits for those too
                subd    sortie_dsc      ; (sortie_left counts them; the one
                bne     sortie_cnt_f1   ; just hit, ht_b, isn't exploding
                ldd     AN_PTR,x        ; yet, so it's skipped)
                bne     sortie_cnt_f1
                inc     sortie_left
sortie_cnt_f1:  ldab    #OBJ_SIZE
                abx
                cpx     #aliens_end
                bne     sortie_cnt_b1
                ldx     wv_ptr          ; and its wave's still to launch, if
                ldd     W_DESC,x        ; that wave is still launching
                subd    sortie_dsc
                bne     sortie_cnt_f2
                ldaa    sortie_left
                adda    wv_left
                staa    sortie_left
sortie_cnt_f2:  tst     sortie_left
                bne     sortie_r0
                clr     sortie_on       ; all of them: the bonus
                ldaa    round           ; (100 x the round: score+1 holds
                adda    score+1         ; the hundreds, BCD)
                daa
                staa    score+1
                ldaa    score
                adca    #0
                daa
                staa    score
                ldaa    #1
                staa    status_t
                ldx     #fx_bing
                ldaa    #8
                jmp     snd_play
sortie_leave:                           ; X = an alien leaving the bottom
                tst     sortie_on
                beq     sortie_r
                ldd     O_SPR,x
                subd    sortie_dsc
                bne     sortie_r
sortie_off:     clr     sortie_on
sortie_r:       rts

; Extra ships: one at 10,000, then one at every 25,000 (25,000, 50,000
; ...), up to 9 (the bar shows one digit).  next_bonus is BCD.
bonus_check:
                ldaa    score
                cmpa    next_bonus
                bhi     bonus_f1
                bne     bonus_r
                ldaa    score+1
                cmpa    next_bonus+1
                bhi     bonus_f1
                bne     bonus_r
                ldaa    score+2
                cmpa    next_bonus+2
                bcs     bonus_r
bonus_f1:       ldaa    next_bonus+1    ; the next one: 25,000, or 25,000
                cmpa    #$00            ; more (10,000 -> 25,000)
                bne     bonus_f2
                ldaa    next_bonus
                cmpa    #$01
                bne     bonus_f2
                ldd     #$0250
                std     next_bonus
                bra     bonus_f3
bonus_f2:       ldaa    next_bonus+1
                adda    #$50
                daa
                staa    next_bonus+1
                ldaa    next_bonus
                adca    #$02
                daa
                staa    next_bonus
bonus_f3:       ldaa    lives
                cmpa    #9
                bcc     bonus_check     ; (at most 9: the next threshold)
                inc     lives
                ldx     #fx_extra       ; three high beeps (above every game
                ldaa    #8              ; sound, below the jingles: in the
                jsr     snd_play        ; finale's bonus the song plays on)
                bra     bonus_check     ; (a big bonus may pass several)
bonus_r:        rts

hi_check:                               ; score above the record: it's the
                                        ; record now (carry set) (compared as
                ldaa    score           ; BCD, high byte first)
                cmpa    hiscore
                bhi     hi_check_f1
                bne     hi_check_r
                ldaa    score+1
                cmpa    hiscore+1
                bhi     hi_check_f1
                bne     hi_check_r
                ldaa    score+2
                cmpa    hiscore+2
                bls     hi_check_r
hi_check_f1:    ldd     score
                std     hiscore
                ldaa    score+2
                staa    hiscore+2
                ldaa    #1
                staa    hi_new
                sec                     ; (carry: a new record)
                rts
hi_check_r:     clc
                rts

hi_pb:                                  ; the parameter block: zero, then the
                ldx     #ovl_pb         ; name and A = access | file number
                ldab    #PB_SIZE
hi_pb_b1:       clr     0,x
                inx
                decb
                bne     hi_pb_b1
                staa    ovl_pb+PB_MODE
                ldd     #s_hifile
                std     ovl_pb+PB_NAME
                ldaa    #S_HIFILE_LEN
                staa    ovl_pb+PB_NLEN
                ldd     #hi_buf
                std     ovl_pb+PB_BUF
                ldd     #HI_SIZE
                std     ovl_pb+PB_LEN
                rts

hi_bios:                                ; B = function: call the BIOS (SD)
                clra
                ldx     #ovl_pb
                jmp     MCX_BIOS

hi_load:
                ldaa    #HI_FILE        ; (close the handle first, as BASIC
                jsr     hi_pb           ; does; errors ignored)
                ldab    #BIOS_CLOSE
                jsr     hi_bios
                ldaa    #PB_IN|HI_FILE
                jsr     hi_pb
                ldab    #BIOS_OPEN
                jsr     hi_bios
                bcs     hi_load_r       ; no file (the first run): 0
                ldab    #BIOS_READ      ; (a short read is an error: then
                jsr     hi_bios         ; the checks below fail)
                ldaa    #HI_FILE
                staa    ovl_pb+PB_MODE
                ldab    #BIOS_CLOSE
                jsr     hi_bios
                ldaa    hi_buf          ; ours, and intact?
                cmpa    #'S'
                bne     hi_load_r
                ldaa    hi_buf+1
                cmpa    #'F'
                bne     hi_load_r
                bsr     hi_sum
                cmpa    hi_buf+5
                bne     hi_load_r
                ldd     hi_buf+2
                std     hiscore
                ldaa    hi_buf+4
                staa    hiscore+2
hi_load_r:      rts

hi_sum:                                 ; A = the sum of hi_buf's first five
                ldx     #hi_buf
                clra
                ldab    #5
hi_sum_b1:      adda    0,x
                inx
                decb
                bne     hi_sum_b1
                rts

hi_save:
                ldd     #'S'*256+'F'    ; the file's bytes
                std     hi_buf
                ldd     hiscore
                std     hi_buf+2
                ldaa    hiscore+2
                staa    hi_buf+4
                bsr     hi_sum
                staa    hi_buf+5
                ldaa    #HI_FILE
                jsr     hi_pb
                ldab    #BIOS_CLOSE
                jsr     hi_bios
                ldaa    #PB_OUT|HI_FILE ; open for output (the BIOS creates it
                jsr     hi_pb           ; first if it's new)
                ldab    #BIOS_OPEN
                jsr     hi_bios
                bcs     hi_save_r
                ldab    #BIOS_WRITE
                jsr     hi_bios
                ldaa    #PB_OUT|HI_FILE ; close (an output file: 'E')
                staa    ovl_pb+PB_MODE
                ldab    #BIOS_CLOSE
                jsr     hi_bios
hi_save_r:      rts

; ---------------------------------------------------------------- overlays
; This area's boss (hull and envoy sprites) into the overlay area, unless
; it's there already: LOADM "SFBOSSn" from the SD card through the
; MCX32-SD BIOS.  Interrupts stay on, so the frame tick goes on counting:
; A = frames it took (0: nothing loaded).  If the file can't be loaded
; the game stops with a message (it can't go on without its boss).
ovl_need:
                ldab    area
                ldaa    #BT_SIZE
                mul
                addd    #boss_tab+BT_OVL
                std     bm_xy
                ldx     bm_xy
                ldaa    0,x
                cmpa    ovl_cur
                bne     ovl_need_f1
                clra
                rts
ovl_need_f1:    staa    ovl_cur
                adda    #'0'
                staa    ovl_name+6
                ldx     #ovl_pb         ; the parameter block: all zero but
                ldab    #PB_SIZE        ; the name, its length and the mode
ovl_need_b1:    clr     0,x             ; (load offset 0, no callback)
                inx
                decb
                bne     ovl_need_b1
                ldd     #ovl_name
                std     ovl_pb+PB_NAME
                ldaa    #7
                staa    ovl_pb+PB_NLEN
                ldaa    #PB_LOADM
                staa    ovl_pb+PB_MODE
                ldaa    frame_count
                staa    ld_t
                clra                    ; the SD card
                ldab    #BIOS_LOAD
                ldx     #ovl_pb
                jsr     MCX_BIOS
                bcs     ovl_err
                ldaa    frame_count
                suba    ld_t
                staa    ld_t
                ldaa    col_o           ; colors swapped?  The new sprites
                cmpa    #TXT_ORANGE     ; too
                beq     ovl_need_f2
                ldx     #OVL_BASE
                jsr     col_swap
ovl_need_f2:    ldaa    ld_t
                bne     ovl_need_f3     ; (at least 1: something was loaded)
                inca
ovl_need_f3:    rts
ovl_err:        stab    ld_t            ; the BIOS's error code
                clr     ovl_cur
                jsr     snd_stop
                ldaa    #TXT_WHITE
                staa    txt_col
                ldx     #TXT_AT(186,4)
                ldd     #s_sderr
                jsr     txt_str
                bra     *
ovl_name:       fcc     "SFBOSS1"       ; (the digit is set as it loads)

; ---------------------------------------------------------------- title
title_draw:
                jsr     cls
                ldaa    #TXT_WHITE      ; the logo's colors (after any swap)
                ldab    col_o
                std     bg_cols
                ldaa    col_b
                staa    bg_cols+2
                ldd     #bg_band
                std     bg_bandp
                ldx     #TXT_AT(12,4)   ; the name, big: 8 letters of 3 bytes
                ldd     #s_title
                jsr     big_str
                ldaa    col_o
                staa    txt_col
                ldx     #TXT_AT(56,5)
                ldd     #s_cast
                jsr     txt_str
                ldx     #cast           ; the aliens and their names
td_cast:        ldd     0,x
                beq     td_cast_f1
                stx     bu_s
                ldaa    2,x             ; the sprite
                ldab    3,x
                ldx     0,x
                jsr     spr_art
                ldaa    #TXT_WHITE
                staa    txt_col
                ldx     bu_s
                ldd     6,x             ; its name
                pshb
                psha
                ldx     4,x
                pula                    ; (D = name, X = where)
                pulb
                jsr     txt_str
                ldx     bu_s
                ldab    #8
                abx
                bra     td_cast
td_cast_f1:     ldaa    col_o           ; the challenge
                staa    txt_col
                ldx     #TXT_AT(128,9)
                ldd     #s_canyou
                jsr     txt_str
                ldx     #TXT_AT(136,6)
                ldd     #s_canyou2
                jsr     txt_str
                ldaa    col_b
                staa    txt_col
                ldx     #TXT_AT(150,6)
                ldd     #s_start
                jsr     txt_str
                ldaa    #TXT_WHITE
                staa    txt_col
                ldx     #TXT_AT(165,2)
                ldd     #s_keys
                jsr     txt_str
                ldaa    col_o
                staa    txt_col
                ldx     #TXT_AT(182,CREDIT_COL)
                ldd     #s_credit
                jmp     txt_str

; The cast on the title: sprite table, x, y, name's screen address, name
CAST_X          equ     36
CAST_TXT        equ     14
cast:           fdb     saucer_hr
                fcb     CAST_X, 68
                fdb     TXT_AT(72,CAST_TXT), s_swooper
                fdb     dart_hr
                fcb     CAST_X, 88
                fdb     TXT_AT(92,CAST_TXT), s_zagger
                fdb     orbiter_hr
                fcb     CAST_X, 108
                fdb     TXT_AT(112,CAST_TXT), s_warper
                fdb     0

#include "logo.inc"            ; big_str: the logo

; the logo's color bands, a row each (0 white, 1 orange, 2 blue): blue
; at the top brightening through dithered scanlines into white, as if lit
; from below (the owner's choice, B in bench/logos.asm)
bg_band:        fcb     2, 2, 2, 2, 2, 2, 2, 2, 2, 2
                fcb     2, 0, 2, 2, 0, 2, 0, 2, 0, 0
                fcb     2, 0, 0, 0, 0, 0, 0, 0, 0, 0
col_draw:                               ; the color check screen
                jsr     cls
                ldx     #TXT_AT(70,14)  ; a block that should look orange
                ldab    #12
col_draw_b1:    ldaa    col_o
                staa    0,x
                staa    1,x
                staa    2,x
                staa    3,x
                pshb
                ldab    #ROW_BYTES
                abx
                pulb
                decb
                bne     col_draw_b1
                ldaa    #TXT_WHITE
                staa    txt_col
                ldx     #TXT_AT(92,2)
                ldd     #s_sample1
                jsr     txt_str
                ldx     #TXT_AT(102,1)
                ldd     #s_sample2
                jsr     txt_str
                ldaa    col_b
                staa    txt_col
                ldx     #TXT_AT(130,8)
                ldd     #s_cont
                jmp     txt_str

key_c:                                  ; A = 1 while C is held
                ldaa    #$FF-$08        ; column 3: C is row 0
                staa    P1DAT
                ldaa    KBD
                ldab    #$FF
                stab    P1DAT
                anda    #1
                eora    #1
                rts

; ---------------------------------------------------------------- misc
rnd:                                    ; D = a new random 16 bits: the
                ldaa    #8              ; LFSR steps 8 times, so values in a
                staa    rnd_n           ; row aren't shifted copies
                ldd     seed
rnd_b1:         lsrd
                bcc     rnd_f1
                eora    #$B4
rnd_f1:         dec     rnd_n
                bne     rnd_b1
                std     seed
                rts

cls:
                ldx     #SCREEN
                clra
                clrb
cls_b1:         std     0,x
                std     2,x
                inx
                inx
                inx
                inx
                cpx     #SCREEN_END
                bne     cls_b1
                rts

; ---------------------------------------------------------------- data
; Flight paths (designed with tools/pathsim.py: they stay inside the side
; edges and wrap cleanly).  Jinks and U-turns are P_TURNBY.
path_loopL:                             ; loop left, jink, dive down-right;
                fcb     P_SPEED, 0      ; then the mirror image
                fcb     P_HEAD, 64
pl_rep:         fcb     P_FLY, 40, 0
                fcb     P_EVENT, 1
                fcb     P_FLY, 16, 4
                fcb     P_EVENT, 1
                fcb     P_FLY, 16, 4
                fcb     P_EVENT, 1
                fcb     P_FLY, 16, 4
                fcb     P_EVENT, 1
                fcb     P_FLY, 16, 4
                fcb     P_EVENT, 1
                fcb     P_TURNBY, -48
                fcb     P_FLY, 12, 0
                fcb     P_TURNBY, 48
                fcb     P_FLY, 16, -2
                fcb     P_EVENT, 1
                fcb     P_FLY, 60, 0
                fcb     P_HEAD, 64
                fcb     P_FLY, 40, 0
                fcb     P_EVENT, 1
                fcb     P_FLY, 16, -4
                fcb     P_EVENT, 1
                fcb     P_FLY, 16, -4
                fcb     P_EVENT, 1
                fcb     P_FLY, 16, -4
                fcb     P_EVENT, 1
                fcb     P_FLY, 16, -4
                fcb     P_EVENT, 1
                fcb     P_TURNBY, 48
                fcb     P_FLY, 12, 0
                fcb     P_TURNBY, -48
                fcb     P_FLY, 16, 2
                fcb     P_EVENT, 1
                fcb     P_FLY, 60, 0
                fcb     P_HEAD, 64
                fcb     P_GOTO
                fdb     pl_rep
path_loopR:                             ; the mirror image
                fcb     P_SPEED, 0
                fcb     P_HEAD, 64
pr_rep:         fcb     P_FLY, 40, 0
                fcb     P_EVENT, 1
                fcb     P_FLY, 16, -4
                fcb     P_EVENT, 1
                fcb     P_FLY, 16, -4
                fcb     P_EVENT, 1
                fcb     P_FLY, 16, -4
                fcb     P_EVENT, 1
                fcb     P_FLY, 16, -4
                fcb     P_EVENT, 1
                fcb     P_TURNBY, 48
                fcb     P_FLY, 12, 0
                fcb     P_TURNBY, -48
                fcb     P_FLY, 16, 2
                fcb     P_EVENT, 1
                fcb     P_FLY, 60, 0
                fcb     P_HEAD, 64
                fcb     P_FLY, 40, 0
                fcb     P_EVENT, 1
                fcb     P_FLY, 16, 4
                fcb     P_EVENT, 1
                fcb     P_FLY, 16, 4
                fcb     P_EVENT, 1
                fcb     P_FLY, 16, 4
                fcb     P_EVENT, 1
                fcb     P_FLY, 16, 4
                fcb     P_EVENT, 1
                fcb     P_TURNBY, -48
                fcb     P_FLY, 12, 0
                fcb     P_TURNBY, 48
                fcb     P_FLY, 16, -2
                fcb     P_EVENT, 1
                fcb     P_FLY, 60, 0
                fcb     P_HEAD, 64
                fcb     P_GOTO
                fdb     pr_rep
ZIG_R           macro                   ; zigzag down, drifting right
                fcb     P_HEAD, 40
                fcb     P_FLY, 30, 0
                fcb     P_EVENT, 1
                fcb     P_TURNBY, 48
                fcb     P_FLY, 24, 0
                fcb     P_TURNBY, -48
                fcb     P_FLY, 24, 0
                fcb     P_EVENT, 1
                fcb     P_TURNBY, 48
                fcb     P_FLY, 24, 0
                fcb     P_TURNBY, -48
                fcb     P_FLY, 24, 0
                fcb     P_EVENT, 1
                fcb     P_TURNBY, 24
                fcb     P_FLY, 40, 0
                endm
ZIG_L           macro                   ; zigzag down, drifting left
                fcb     P_HEAD, 88
                fcb     P_FLY, 30, 0
                fcb     P_EVENT, 1
                fcb     P_TURNBY, -48
                fcb     P_FLY, 24, 0
                fcb     P_TURNBY, 48
                fcb     P_FLY, 24, 0
                fcb     P_EVENT, 1
                fcb     P_TURNBY, -48
                fcb     P_FLY, 24, 0
                fcb     P_TURNBY, 48
                fcb     P_FLY, 24, 0
                fcb     P_EVENT, 1
                fcb     P_TURNBY, -24
                fcb     P_FLY, 40, 0
                endm
path_zigRL:                             ; sudden swerves, never upward
                fcb     P_SPEED, 0
pz_rep:         ZIG_R
                ZIG_L
                fcb     P_GOTO
                fdb     pz_rep
path_zigLR:
                fcb     P_SPEED, 0
pzl_rep:        ZIG_L
                ZIG_R
                fcb     P_GOTO
                fdb     pzl_rep
path_circle:                            ; two fast circles, a reversal jink,
                fcb     P_SPEED, 0      ; then a dive; back in from the top
                fcb     P_HEAD, 64      ; somewhere else each time
                fcb     P_EVENT, 2
pc_rep:         fcb     P_FLY, 40, 0
                fcb     P_FLY, 64, 4
                fcb     P_EVENT, 1
                fcb     P_FLY, 64, 4
                fcb     P_TURNBY, 128
                fcb     P_FLY, 10, 0
                fcb     P_TURNBY, 128
                fcb     P_EVENT, 1
                fcb     P_FLY, 70, 0
                fcb     P_HEAD, 64
                fcb     P_GOTO
                fdb     pc_rep
path_circleR:                           ; the mirror image
                fcb     P_SPEED, 0
                fcb     P_HEAD, 64
                fcb     P_EVENT, 3
pcr_rep:        fcb     P_FLY, 40, 0
                fcb     P_FLY, 64, -4
                fcb     P_EVENT, 1
                fcb     P_FLY, 64, -4
                fcb     P_TURNBY, 128
                fcb     P_FLY, 10, 0
                fcb     P_TURNBY, 128
                fcb     P_EVENT, 1
                fcb     P_FLY, 70, 0
                fcb     P_HEAD, 64
                fcb     P_GOTO
                fdb     pcr_rep

;; Wrap-around paths: these fly through the side edges and come in at the
; other side (P_WRAP 1).
path_sweepR:                            ; long shallow diagonals drifting
                fcb     P_WRAP, 1       ; right through the edge, with curves
                fcb     P_SPEED, 0
                fcb     P_HEAD, 20
psr_rep:        fcb     P_FLY, 40, 0
                fcb     P_EVENT, 1
                fcb     P_FLY, 40, 1
                fcb     P_FLY, 30, -1
                fcb     P_EVENT, 1
                fcb     P_FLY, 60, 0
                fcb     P_HEAD, 20
                fcb     P_GOTO
                fdb     psr_rep
path_sweepL:                            ; the mirror image
                fcb     P_WRAP, 1
                fcb     P_SPEED, 0
                fcb     P_HEAD, 108
psl_rep:        fcb     P_FLY, 40, 0
                fcb     P_EVENT, 1
                fcb     P_FLY, 40, -1
                fcb     P_FLY, 30, 1
                fcb     P_EVENT, 1
                fcb     P_FLY, 60, 0
                fcb     P_HEAD, 108
                fcb     P_GOTO
                fdb     psl_rep
path_weave:                             ; fast passes across the screen,
                fcb     P_WRAP, 1       ; round through the sides, then a dive
                fcb     P_SPEED, 0
                fcb     P_HEAD, 64
pwv_rep:        fcb     P_FLY, 30, 0
                fcb     P_HEAD, 6
                fcb     P_FLY, 70, 0
                fcb     P_EVENT, 1
                fcb     P_TURNBY, 116
                fcb     P_FLY, 50, 0
                fcb     P_EVENT, 1
                fcb     P_TURNBY, -116
                fcb     P_FLY, 50, 0
                fcb     P_TURNBY, 58
                fcb     P_FLY, 60, 0
                fcb     P_HEAD, 64
                fcb     P_GOTO
                fdb     pwv_rep

; Areas: each a list of waves, ending with fdb 0.  At most 10 waves an
; area (the map shows 3 rows per wave).  Later areas launch faster.
areas:          fdb     area1, area2, area3, area4
; (Each wave: descriptor, path; count, launch interval, entry x, x step.)
; The bosses, one row per area: envoys, envoy hits, escort waves, the
; overlay with its hull and envoy sprites (SFBOSSn.BIN), core list, cannon list, the envoys' top row in the hull,
; the hull's x (fixed for a fortress), the row it stops at, whether it
; stays put (1) or sways (0), its box width and height (with the halo),
; and how many escorts may fly at once.  Core lists: a count, then CORE column, row (of its 4x4
; opening's top left), stage, hits.  Cannon lists: a count, then CANNON
; column, row (where the bomb appears).  Columns and rows are in the art.
BT_ENV          equ     0
BT_EHP          equ     1
BT_ESC          equ     2
BT_OVL          equ     4
BT_CORES        equ     5
BT_CANS         equ     7
BT_EDY          equ     9
BT_X            equ     10
BT_STOP         equ     11
BT_STILL        equ     12
BT_W            equ     13
BT_H            equ     14
BT_ALIVE        equ     15
BT_SIZE         equ     16
BOSSROW         macro   env,ehp,esc,ovl,cores,cans,erow,bx,stop,still,bw,bh,amax
                fcb     env, ehp
                fdb     esc
                fcb     ovl
                fdb     cores, cans
                fcb     erow, bx, stop, still, bw, bh, amax
                endm
CORE            macro   col,row,stage,hits
                fcb     boss1_PADX+col-core_PADX, boss1_PADY+row-core_PADY, stage, hits
                endm
CANNON          macro   col,row
                fcb     boss1_PADX+col-bomb_PADX, boss1_PADY+row-bomb_PADY
                endm
BOSS4_X         equ     ((128-boss4_W)/2)&$FC|2 ; on boss4's one shift (2)
boss_tab:       BOSSROW 0, 0, esc1, 1, cores1, cans1, 6, (128-boss1_W)/2, BOSS_Y, 0, boss1_W, boss1_H, MAX_ALIVE
                BOSSROW 2, 4, esc2, 2, cores2, cans23, 4, (128-boss2_W)/2, BOSS_Y, 0, boss2_W, boss2_H, MAX_ALIVE
                BOSSROW 2, 6, esc3, 3, cores3, cans3, 5, (128-boss3_W)/2, BOSS_Y, 0, boss3_W, boss3_H, MAX_ALIVE
                BOSSROW 2, 6, esc4, 4, cores4, cans4, 6, BOSS4_X, 7, 1, boss4_W, boss4_H, FORT_ALIVE
cores1:         fcb     1               ; (in the beetle's maw)
                CORE    10, 10, 0, 8
cores2:         fcb     1
                CORE    10, 10, 0, 10
cores3:         fcb     1
                CORE    10, 10, 0, 12
cores4:         fcb     3               ; the fortress: two side cores, then
                CORE    6, 13, 0, 6     ; the centre one
                CORE    24, 13, 0, 6
                CORE    15, 13, 1, 14
cans1:          fcb     2               ; (the pincers' outer bases: the tips
                CANNON  B1_CAN_L, 14    ; hugged the core's channel, so every
                CANNON  B1_CAN_R, 14    ; spot under the core was bombed)
cans23:         fcb     2
                CANNON  8, 16
                CANNON  14, 16
cans3:          fcb     2               ; (the outer tentacles' tips: clear of
                CANNON  B3_CAN_L, 16    ; the spots under the core)
                CANNON  B3_CAN_R, 16
; Bosses 1 and 3: their cannons must leave every spot under the core
; clear (the ship's gun under columns 10-13 puts its 8-pixel hull over
; columns 7-17): columns 6 or less, or 18 or more.  (Boss 2's sit closer,
; and that's how the owner likes its fight.)
B1_CAN_L        equ     3               ; (the cannon columns: used below
B1_CAN_R        equ     20              ; and checked here)
B3_CAN_L        equ     5
B3_CAN_R        equ     18
                if      (B1_CAN_L>6)||(B1_CAN_R<18)||(B3_CAN_L>6)||(B3_CAN_R<18)
                error   "a boss cannon bombs the spots under its core"
                endif
cans4:          fcb     4
                CANNON  2, 16
                CANNON  21, 16
                CANNON  12, 16
                CANNON  31, 16
esc1:           fdb     saucer_dsc, path_loopL      ; (only WARPERs warp)
                fcb     4, 20, 30, 0
                fdb     dart_dsc, path_zigRL
                fcb     4, 20, 21, 12
                fdb     0
esc2:           fdb     orbiter_dsc, path_circleR  ; (envoy bosses: fewer
                fcb     4, 16, 84, 0               ; escorts, the envoys
                fdb     saucer_dsc, path_loopL     ; bring the danger)
                fcb     4, 16, 30, 0
                fdb     0
esc3:           fdb     dart_dsc, path_zigLR
                fcb     4, 14, 103, -12
                fdb     orbiter_dsc, path_circle
                fcb     4, 14, 35, 0
                fdb     0
esc4:           fdb     saucer_dsc, path_loopR
                fcb     4, 12, 89, 0
                fdb     dart_dsc, path_zigRL
                fcb     4, 12, 15, 12
                fdb     orbiter_dsc, path_circleR
                fcb     4, 12, 84, 0
                fdb     0

; Explosion: frames of 4 game frames each, then the slot is freed
anim_boom:      fdb     boom1_dsc
                fcb     4
                fdb     boom2_dsc
                fcb     4
                fdb     boom3_dsc
                fcb     5
                fdb     boom4_dsc
                fcb     6
                fdb     0

; Text.  Banners: fdb screen address, then the text (centred).
s_score:        fcc     "SCORE"
                fcb     0
s_hi:           fcc     "HI"
                fcb     0
s_hifile:       fcc     "STARFALL.HI"
S_HIFILE_LEN    equ     *-s_hifile
s_ships:        fcc     "SHIPS"
                fcb     0
s_player1:      fdb     TXT_AT(BANNER_ROW,12)
                fcc     "PLAYER 1"
                fcb     0
s_gameover:     fdb     TXT_AT(BANNER_ROW,11)
                fcc     "GAME OVER"
                fcb     0
s_player:       fcc     "PLAYER 1"
                fcb     0
s_area:         fcc     "AREA "
                fcb     0
s_fallen:       fdb     TXT_AT(BANNER_ROW,1)
                fcc     "THE SPACE FORTRESS HAS FALLEN!"
                fcb     0
s_alldone:      fdb     TXT_AT(BANNER_ROW,4)
                fcc     "ALL FOUR BOSSES DEFEATED"
                fcb     0
s_bonus:        fdb     TXT_AT(BANNER_ROW,5)
                fcc     "SHIP BONUS: 10000 EACH"
                fcb     0
s_blorps:       fdb     TXT_AT(BANNER_ROW,4)
                fcc     "...BUT THE ALIEN BLORPS"
                fcb     0
s_blorps2:      fdb     TXT_AT(BANNER_ROW+8,4)
                fcc     "THREATEN ANOTHER GALAXY!"
                fcb     0
s_round:        fdb     TXT_AT(BANNER_ROW,12)
                fcc     "ROUND 2"       ; (the digit is set as it shows)
                fcb     0
s_cleared:      fdb     TXT_AT(BANNER_ROW,10)
                fcc     "AREA CLEARED"
                fcb     0
s_bossin:       fdb     TXT_AT(BANNER_ROW,11)
                fcc     "WARNING!"
                fcb     0
s_title:        fcc     "STARFALL"      ; a working title
                fcb     0
s_cast:         fcc     "MEET THE ALIEN BLORPS"
                fcb     0
s_canyou:       fcc     "CAN YOU DEFEAT"
                fcb     0
s_canyou2:      fcc     "THE SPACE FORTRESS?"
                fcb     0
s_swooper:      fcc     "SWOOPER"
                fcb     0
s_zagger:       fcc     "ZAGGER"
                fcb     0
s_warper:       fcc     "WARPER"
                fcb     0
CREDIT_COL      equ     9               ; (centred: 32 - its length, halved)
s_credit:       fcc     "AN ABENE GAME"
                fcb     0
s_sample1:      fcc     "THIS BLOCK SHOULD BE ORANGE"
                fcb     0
s_sample2:      fcc     "IF IT IS BLUE, PRESS C TO SWAP"
                fcb     0
s_start:        fcc     "PRESS SPACE TO START"
                fcb     0
s_cont:         fcc     "SPACE CONTINUES"
                fcb     0
s_sderr:        fcc     "CANNOT LOAD THE BOSS FILE"
                fcb     0
s_load:         fcc     "LOAD "
                fcb     0
s_keys:         fcc     "ARROWS/WASZ MOVE  SPACE FIRES"
                fcb     0

; Every artifact sprite, for the color swap
al_sprites:     fdb     saucer_dsc, dart_dsc, orbiter_dsc, 0
all_sprites:    fdb     ship_dsc, saucer_dsc, dart_dsc, orbiter_dsc, shot_dsc
                fdb     bomb_dsc, boom1_dsc, boom2_dsc, boom3_dsc, boom4_dsc
                fdb     shipw1_dsc, shipw2_dsc, core_dsc, corehit_dsc
                fdb     coreshut_dsc, 0         ; (bosses: as they load)

; The ship's explosion: bigger and longer than an alien's
anim_shipboom:  fdb     boom1_dsc
                fcb     6
                fdb     boom2_dsc
                fcb     6
                fdb     boom3_dsc
                fcb     6
                fdb     boom2_dsc
                fcb     5
                fdb     boom3_dsc
                fcb     8
                fdb     boom4_dsc
                fcb     14
                fdb     0

#include "sounds.inc"            ; the sound effects and jingles

; Star field: 16 stars in three speed layers (rows per frame x 256)
#define NSTAR 18
star_tab:
i               set     0
                rept    NSTAR
                fdb     SCREEN
                fcb     0, 0
                if      i#3 == 0
                fcb     $40             ; far: 1/8 row a frame (updated every
                                        ; other frame: S_SPD is per 2 frames)
                elseif  i#3 == 1
                fcb     $80             ; middle: 1/4
                else
                fcb     $FF             ; near: 1/2
                endif
i               set     i+1
                endm
star_end:

; Objects, in priority order: aliens, bombs, shots, ship
objs:
boss:           fcb     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
core:           rept    NCORE
                fcb     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                endm
env1:           fcb     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
env2:           fcb     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
aliens:
                rept    NALIEN
                fcb     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                endm
aliens_end:
bombs:
                rept    NBOMB
                fcb     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                endm
bombs_end:
shots:
                rept    NSHOT
                fcb     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                endm
shots_end:
ship:
                fcb     (128-ship_W)/2, 0, 160, 0
                fdb     0, 0, ship_dsc
                fcb     0, 0, 0, 0, 0, 0, 0, 0, 0, 0
objs_end:

#include "frame.asm"
#include "sprite.asm"
#include "sprman.asm"
#include "flight.asm"
#include "input.asm"
#include "sound.asm"
#include "stars.asm"
#include "text.asm"
#include "colswap.asm"
#include "starfall_spr.inc"
; the bosses' hulls and envoys are overlays (game_ovl.inc): only their
; sizes here
#include "boss1_equ.inc"
#include "boss2_equ.inc"
#include "boss3_equ.inc"
#include "boss4_equ.inc"
                if      * > OVL_BASE
                error   "the main segment runs into the boss overlay area (OVL_BASE)"
                endif

; ---------------------------------------------------------------- low
; The low segment ($0400-$1FFF), loaded by LOADM along with the main one:
; the aliens' and explosions' sprite code and the sine table.
                org     LOW
#include "starfall_lo_spr.inc"
; the areas' wave lists (data, here for room in the main segment)
area1:                                  ; gentle: 6 at a time, then 8
                fdb     saucer_dsc, path_loopL
                fcb     6, 14, 30, 0
                fdb     dart_dsc, path_zigRL
                fcb     6, 16, 21, 12
                fdb     orbiter_dsc, path_circle
                fcb     6, 14, 35, 0
                fdb     saucer_dsc, path_sweepR
                fcb     6, 16, 20, 0
                fdb     dart_dsc, path_zigLR
                fcb     6, 16, 103, -12
                fdb     orbiter_dsc, path_circleR
                fcb     6, 14, 84, 0
                fdb     orbiter_dsc, path_sweepL
                fcb     8, 14, 100, 0
                fdb     dart_dsc, path_zigRL
                fcb     8, 14, 15, 12
                fdb     0
area2:
                fdb     saucer_dsc, path_loopR
                fcb     8, 12, 89, 0
                fdb     dart_dsc, path_zigLR
                fcb     8, 14, 103, -12
                fdb     orbiter_dsc, path_circleR
                fcb     8, 12, 84, 0
                fdb     saucer_dsc, path_loopL
                fcb     8, 12, 30, 0
                fdb     orbiter_dsc, path_circle
                fcb     8, 12, 35, 0
                fdb     dart_dsc, path_weave
                fcb     8, 14, 30, 0
                fdb     saucer_dsc, path_sweepR
                fcb     8, 12, 20, 0
                fdb     orbiter_dsc, path_circleR
                fcb     8, 11, 84, 0
                fdb     0
area3:
                fdb     dart_dsc, path_zigRL
                fcb     8, 12, 15, 12
                fdb     orbiter_dsc, path_circle
                fcb     8, 10, 35, 0
                fdb     saucer_dsc, path_loopR
                fcb     8, 10, 89, 0
                fdb     dart_dsc, path_zigLR
                fcb     8, 12, 103, -12
                fdb     saucer_dsc, path_sweepL
                fcb     8, 10, 100, 0
                fdb     orbiter_dsc, path_circleR
                fcb     8, 10, 84, 0
                fdb     dart_dsc, path_weave
                fcb     8, 11, 90, 0
                fdb     saucer_dsc, path_loopR
                fcb     8, 9, 89, 0
                fdb     0
area4:
                fdb     orbiter_dsc, path_circleR
                fcb     8, 9, 84, 0
                fdb     dart_dsc, path_zigRL
                fcb     8, 10, 15, 12
                fdb     saucer_dsc, path_loopL
                fcb     8, 9, 30, 0
                fdb     orbiter_dsc, path_circle
                fcb     8, 9, 35, 0
                fdb     dart_dsc, path_weave
                fcb     8, 10, 30, 0
                fdb     saucer_dsc, path_sweepR
                fcb     8, 9, 20, 0
                fdb     orbiter_dsc, path_sweepL
                fcb     8, 8, 100, 0
                fdb     dart_dsc, path_zigRL
                fcb     8, 9, 15, 12
                fdb     0

#include "sintab.asm"
                LOW_CHECK

; the ship arrives at x (128-ship_W)/2 in its warp sprite, compiled for
; shift 3 only (warp_begin snaps x to it)
                if      (((128-ship_W)/2)&3)<>3
                error   "the arrival x must be on the warp ship's shift (3)"
                endif
; every boss hull has boss1's box (the hit tests and placement use it)
                if      (boss2_W<>boss1_W)||(boss2_H<>boss1_H)||(boss3_W<>boss1_W)||(boss3_H<>boss1_H)
                error   "boss hulls must all be 24x16 (with their halo, as boss1)"
                endif
; boss4 is compiled for shift 2 only, and every hull has a 1-pixel halo
; (the core and cannon offsets use boss1's padding)
                if      (boss2_PADX<>1)||(boss3_PADX<>1)||(boss4_PADX<>1)||(boss4_PADY<>1)
                error   "boss hulls need a 1-pixel halo"
                endif
; the arriving ship starts hidden in the bottom gutter, wholly inside it
; (rows 192-223; a sprite drawn past row 223 writes into BSS)
                if      (224-shipw1_H<192)||(shipw2_H<>shipw1_H)
                error   "the warp ship must fit in the bottom gutter (32 rows)"
                endif
