#!/bin/sh
# check.sh: headless checks of StarFall (src/starfall.asm).
# Run from the repository root with "make check".  Loads build/starfall.bin
# with LOADM from an SD folder, as a player would.  Needs the VMC10 for
# Linux emulator's headless harness and ROMs (VMC10=..., default
# ~/vmc10-linux).
set -u
VMC10=${VMC10:-$HOME/vmc10-linux}
H=$VMC10/build/headless
R=$VMC10/roms
BIN=build/starfall.bin
LST=build/starfall.lst
SD=build/sd-check
mkdir -p $SD && cp $BIN $SD/STARFALL.BIN
for n in 1 2 3 4; do cp build/ovl$n.bin $SD/SFBOSS$n.BIN; done   # the boss overlays
pass=0; fail=0
check() {   # name, condition (shell test)
    if eval "$2"; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1"; fail=$((fail+1)); fi
}
sym() { printf '%04X' 0x$(awk '/Symbol Table/{p=1} p' $LST | tr '|' '\n' | awk -v n=$1 '$1==n{print $3}'); }
# load the game the way a player does: LOADM from the SD card, then EXEC
# (past the colour check with SPACE, so a test's own SPACE starts a game from the title)
run() { $H $R/MC10.BIN mcx32sd:$R/mcx32sd_flash.bin 8k sd:$SD frames:200 'type:LOADM"STARFALL"\nEXEC\n' frames:120 'type: ' frames:30 "$@"; }
memval() { grep "^mem $1" | sed -n "${2:-1}p" | awk '{print strtonum("0x"$3)}'; }
# fixed random seeds, poked as a game starts (see the budget checks)
SEEDS="poke:$(sym seed),A5C3 poke:$(sym st_seed),5A3C"

SHIP=$(sym ship); MODE=$(sym mode); WARPF=$(sym warpf); AREA=$(sym area)
ALIENS=$(sym aliens); SHOTS_END=$(sym shots_end); AREA_DONE=$(sym area_done); ALIVE=$(sym alive)

# 1. In play, the ship answers the controls (A = left) and the game is in
#    play mode with normal star speed.
out=$(run frames:30 'type: ' frames:220 mem:$SHIP,1 'type:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' frames:60 mem:$SHIP,1 mem:$MODE,1 mem:$WARPF,1)
x0=$(echo "$out" | memval $SHIP 1); x1=$(echo "$out" | memval $SHIP 2)
check "ship moves left when A is held (x $x0 -> $x1)" "[ $x1 -lt $x0 ]"
check "play mode with normal stars" "[ $(echo "$out" | memval $MODE) -eq 0 ] && [ $(echo "$out" | memval $WARPF) -eq 1 ]"

# 1a. The colour check comes once, right after loading: an orange block
#     (C swaps it to blue), then SPACE leads to the title, without it.
BLK=48CE    # TXT_AT(70,14): the block's first byte
raw() { $H $R/MC10.BIN mcx32sd:$R/mcx32sd_flash.bin 8k sd:$SD frames:200 'type:LOADM"STARFALL"\nEXEC\n' frames:120 "$@"; }
out=$(raw mem:$BLK,4 type:C frames:90 mem:$BLK,4 'type: ' frames:60 mem:$BLK,4 mem:$SHIP,1)
b0=$(echo "$out" | grep "^mem $BLK" | sed -n 1p | cut -d: -f2 | tr -d ' ')
b1=$(echo "$out" | grep "^mem $BLK" | sed -n 2p | cut -d: -f2 | tr -d ' ')
b2=$(echo "$out" | grep "^mem $BLK" | sed -n 3p | cut -d: -f2 | tr -d ' ')
check "colour check after loading: orange block ($b0), C swaps it ($b1), SPACE goes to the title ($b2)" "[ $b0 = AAAAAAAA ] && [ $b1 = 55555555 ] && [ $b2 = 00000000 ]"

# 1e. The very first title bursts on with the boss explosion's roar; the
#     title after a game over doesn't.
FXD=$(sym fx_bossdie); SPTR=$(sym snd_ptr)
out=$(raw 'type: ' frames:20 mem:$SPTR,2 'type: ' frames:300 poke:$(sym lives),00 poke:$(sym dead),01 poke:$(sym dead_t),02 frames:1200 mem:$(sym mode),1 mem:$SPTR,2)
p1=$(echo "$out" | grep "^mem $SPTR" | sed -n 1p | cut -d: -f2 | tr -d ' '); p2=$(echo "$out" | grep "^mem $SPTR" | sed -n 2p | cut -d: -f2 | tr -d ' ')
check "the first title roars (sound at \$$p1, fx_bossdie \$$FXD), the next one doesn't (\$$p2)" "[ \$((0x$p1)) -ge \$((0x$FXD)) ] && [ \$((0x$p1)) -lt \$((0x$FXD + 20)) ] && { [ \$((0x$p2)) -lt \$((0x$FXD)) ] || [ \$((0x$p2)) -ge \$((0x$FXD + 20)) ]; }"

# 1c. The title's star field passes behind it: after 30 s of stars, every
#     byte the title drew (logo, cast, text) is unchanged.
#     (Title bytes: nonzero in all three snapshots; a lone star rarely is.)
out=$(raw 'type: ' frames:20 mem:4000,6144 frames:900 mem:4000,6144 frames:900 mem:4000,6144)
dmg=$(echo "$out" | grep '^mem 4000' | cut -d: -f2 | awk '{for(i=1;i<=NF;i++) v[NR,i]=$i} END{for(i=1;i<=6144;i++) if(v[1,i]!="00" && v[2,i]!="00" && v[3,i]!="00" && (v[1,i]!=v[2,i] || v[2,i]!=v[3,i])) d++; print d+0}')
check "the title's stars pass behind it (title bytes changed: $dmg)" "[ $dmg -eq 0 ]"

# 1d. The high score: no STARFALL.HI on the card (a first run) means 0;
#     a game ending with a record writes the file ("SF", the BCD score, a
#     checksum); the next start reads it back (and shows it).
HS=build/sd-hi; mkdir -p $HS && cp $BIN $HS/STARFALL.BIN && for n in 1 2 3 4; do cp build/ovl$n.bin $HS/SFBOSS$n.BIN; done
rm -f $HS/STARFALL.HI
HSV=$(sym hiscore)
hrun() { $H $R/MC10.BIN mcx32sd:$R/mcx32sd_flash.bin 8k sd:$HS frames:200 'type:LOADM"STARFALL"\nEXEC\n' frames:120 'type: ' frames:30 "$@"; }
out=$(hrun mem:$HSV,3 'type: ' frames:300 poke:$(sym score),012340 poke:$(sym status_t),01 frames:5 mem:$HSV,3 \
      poke:$(sym lives),00 poke:$(sym dead),01 poke:$(sym dead_t),02 frames:500)
h0=$(echo "$out" | grep "^mem $HSV" | sed -n 1p | cut -d: -f2 | tr -d ' ')
h1=$(echo "$out" | grep "^mem $HSV" | sed -n 2p | cut -d: -f2 | tr -d ' ')
file=$(od -An -tx1 $HS/STARFALL.HI 2>/dev/null | tr -d ' \n')
out=$(hrun mem:$HSV,3 'type: ' frames:300 mem:$(sym status_buf),224)
h2=$(echo "$out" | grep "^mem $HSV" | cut -d: -f2 | tr -d ' ')
check "high score: first run $h0, beaten $h1, saved ($file), read back $h2" "[ $h0 = 000000 ] && [ $h1 = 012340 ] && [ \"$file\" = 5346012340fd ] && [ $h2 = 012340 ]"

# 1b. The status bar is on screen: rows 0-6 match status_buf (sampled a
#     few times during play, as sprites cross it).
SB=$(sym status_buf); BAND_BYTES=224
bad=0
for t in 300 900 1500; do
    out=$(run frames:30 'type: ' frames:$t mem:4000,224 mem:$SB,224)
    scr=$(echo "$out" | grep '^mem 4000' | cut -d: -f2); buf=$(echo "$out" | grep "^mem $SB" | cut -d: -f2)
    [ -n "$scr" ] && [ "$scr" = "$buf" ] || bad=$((bad+1))
done
check "the status bar is on screen and intact ($bad of 3 samples wrong)" "[ $bad -le 1 ]"
out=$(run frames:30 'type: ' frames:400 mem:$(printf '%04X' $((0x$SB + 32))),32)
check "the status bar has text in it" "[ \"\$(echo \"$out\" | grep '^mem' | cut -d: -f2 | tr -d ' 0')\" != '' ]"

# 2. Normal play: the area's waves come one after another, and neither
#    the area's end nor the boss comes before the last wave (area 1 has
#    3).  Sampled every second over a minute of firing while sweeping.
WVI=$(sym wv_index); BSTATE=$(sym boss_state)
mv=""; for i in $(seq 1 20); do mv="$mv A A A A A A A A A A S S S S S S S S S S S S S S S S S S S S A A A A A A A A A A"; done
samples=""; for i in $(seq 1 60); do samples="$samples frames:60 mem:$WVI,1 mem:$AREA_DONE,1 mem:$BSTATE,1 mem:$AREA,1"; done
early=$(run frames:30 'type: ' frames:200 poke:$(sym lives),09 "type:$mv$mv" $samples | grep '^mem' | paste - - - - | \
        awk '{w=strtonum("0x"$3); d=strtonum("0x"$6); b=strtonum("0x"$9); a=strtonum("0x"$12); if(a==0 && (d||b) && w<3) e++} END{print e+0}')
check "no early area end or boss in normal play (bad samples: $early)" "[ $early -eq 0 ]"

# 2a. At most 8 live aliens fly at once (a sliding window: the rest of a
#     wave waits its turn), sampled every 10 frames over two minutes.
samples=""; for i in $(seq 1 700); do samples="$samples frames:10 mem:$ALIVE,1"; done
mv2=""; for i in $(seq 1 60); do mv2="$mv2 A A A A A A A A A A S S S S S S S S S S S S S S S S S S S S A A A A A A A A A A"; done
most=$(run frames:30 'type: ' frames:250 poke:$(sym lives),09 "type:$mv2" $samples | grep '^mem' | awk '{a=strtonum("0x"$3); if(a>m)m=a} END{print m+0}')
check "never more than 8 aliens flying (most seen: $most)" "[ $most -le 8 ] && [ $most -ge 6 ]"

# 2c. Staggered-lane waves never put an alien off the side, even when
#     more aliens launch than the wave has lanes (relaunched survivors):
#     area 2's dart wave (lanes from x 103, step -12) is given 14
#     launches with the alive counter held open so all 10 slots fill.
#     (The bug: lane 10 entered at x 251 and stuck, wrapping onto the
#     next rows, unshootable.)
A2=$(sym area2); W2=$(printf '%04X' $((0x$A2 + 8)))
samples=""; for i in $(seq 1 40); do samples="$samples frames:15 poke:$ALIVE,00 mem:$ALIENS,200"; done
offside=$(run frames:30 'type: ' frames:300 poke:$(sym lives),09 poke:$(sym wv_ptr),$W2 poke:$(sym wv_x),67 poke:$(sym wv_left),0E poke:$(sym wv_timer),01 $samples | \
    grep "^mem $ALIENS" | awk '{for(i=0;i<10;i++){b=3+i*20; x=strtonum("0x"$(b)); s=$(b+8)$(b+9); f=strtonum("0x"$(b+16)); if(s!="0000" && x>=118 && !(f%2)) o++}} END{print o+0}')
check "aliens stay on screen when launches outnumber lanes (samples off: $offside)" "[ $offside -eq 0 ]"

# 2d. Wrap-around paths: area 1's sweep wave (saucers drifting right
#     through the edge) is forced; aliens are seen crossing from the right
#     edge to the left, and none is left stuck straddling the edge.
W4=$(printf '%04X' $((0x$(sym area1) + 3*8)))
samples=""; for i in $(seq 1 600); do samples="$samples frames:1 mem:$ALIENS,200"; done
res=$(run frames:30 'type: ' frames:300 poke:$(sym lives),09 poke:$(sym wv_ptr),$W4 poke:$(sym wv_x),14 poke:$(sym wv_left),06 poke:$(sym wv_timer),01 $samples | \
    grep "^mem $ALIENS" | awk '{for(i=0;i<10;i++){b=3+i*20; x=strtonum("0x"$(b)); s=$(b+8)$(b+9); f=strtonum("0x"$(b+16)); if(s!="0000" && f%2){ if(px[i]>110 && x<15) cr++; if(x>=118){st[i]++; if(st[i]>mx) mx=st[i]} else st[i]=0; px[i]=x } else {px[i]=0; st[i]=0} }} END{printf "%d %d", cr+0, mx+0}')
set -- $res
check "wrapping aliens cross from one side to the other ($1 crossings)" "[ $1 -ge 2 ]"
check "none stays straddling the edge (longest: $2 frames)" "[ $2 -le 30 ]"

# 2e. Circling aliens (area 1's orbiter wave, forced) come back in from
#     the top at a new random x after each dive (owner: they used to dive
#     in the same columns, so a player could wait them out), stay on
#     screen, and wait out of sight first (an instant jump looked like a
#     glitch) until the whole column has left the screen.  (An alien that
#     explodes, say against the ship, counts as gone: its slot is reused.)
W3=$(printf '%04X' $((0x$(sym area1) + 2*8)))
samples=""; for i in $(seq 1 1800); do samples="$samples frames:1 poke:$(sym invuln),F0 mem:$ALIENS,200"; done   # (a lost ship wipes the field mid-sample)
res=$(run frames:30 'type: ' frames:300 poke:$(sym lives),09 poke:$(sym wv_ptr),$W3 poke:$(sym wv_x),23 poke:$(sym wv_left),06 poke:$(sym wv_timer),01 $samples | \
    grep "^mem $ALIENS" | awk '{nv=0; for(i=0;i<10;i++){b=3+i*20; if($(b+8)$(b+9)!="0000" && $(b+17)$(b+18)=="0000" && int(strtonum("0x"$(b+16))/2)%4 && strtonum("0x"$(b+2))<190) nv++} if(!nv) le=NR;
      for(i=0;i<10;i++){b=3+i*20; x=strtonum("0x"$(b)); y=strtonum("0x"$(b+2)); s=$(b+8)$(b+9); if($(b+17)$(b+18)!="0000") s="0000"; f=strtonum("0x"$(b+16)); if(s!="0000" && int(f/2)%4){ if(py[i]!="" && py[i]<200 && y>=224){n++; if(!mn||x<mn)mn=x; if(x>mx)mx=x} if(y<192 && x>=118) off++; v=(y<190); if(pv[i]=="1" && !v) g[i]=NR; if(pv[i]=="0" && v && g[i]){d=NR-g[i]; if(!gm||d<gm)gm=d; if(le<g[i]) ov++; g[i]=0} pv[i]=v } else {pv[i]=""; g[i]=0} py[i]=(s!="0000")?y:""}} END{printf "%d %d %d %d %d", n+0, mx-mn, off+0, gm+0, ov+0}')
set -- $res
check "circling aliens re-enter at new spots ($1 re-entries spread over $2 pixels)" "[ $1 -ge 8 ] && [ $2 -ge 50 ]"
check "and stay on screen (samples off: $3)" "[ $3 -eq 0 ]"
check "they stay out of sight a moment before coming back (shortest: $4 frames)" "[ $4 -ge 40 ]"
check "and only after the whole column has left the screen (early: $5)" "[ $5 -eq 0 ]"

# 2b. Losing a ship clears the field: with aliens flying, the ship is
#     lost (dead set, its countdown about to end); right after the respawn
#     no alien is left, and later the survivors come back.
DEAD=$(sym dead); DEADT=$(sym dead_t); LIVESV=$(sym lives); ALIVEV=$(sym alive)
out=$(run frames:30 'type: ' frames:400 poke:$LIVESV,09 mem:$ALIVEV,1 poke:$DEAD,01 poke:$DEADT,02 frames:10 mem:$ALIVEV,1 frames:300 mem:$ALIVEV,1 mem:$DEAD,1)
a0=$(echo "$out" | memval $ALIVEV 1); a1=$(echo "$out" | memval $ALIVEV 2); a2=$(echo "$out" | memval $ALIVEV 3)
check "aliens flying ($a0) are cleared when the ship is lost ($a1 after the respawn)" "[ $a0 -gt 0 ] && [ $a1 -eq 0 ] && [ $(echo "$out" | memval $DEAD) -eq 0 ]"
check "and they come back afterwards ($a2)" "[ $a2 -gt 0 ]"

# 2f. SHIPS counts the reserve (not the ship flying): 2 at the start; it
#     drops when the next ship appears, not when the ship is lost; losing
#     a ship with 0 in reserve ends the game.
GO=$(sym gover)
out=$(run frames:30 'type: ' frames:300 mem:$LIVESV,1 poke:$DEAD,01 poke:$DEADT,30 frames:10 mem:$LIVESV,1 frames:300 mem:$LIVESV,1 mem:$DEAD,1 \
      poke:$LIVESV,00 poke:$(sym invuln),00 poke:$DEAD,01 poke:$DEADT,05 frames:30 mem:$LIVESV,1 mem:$GO,1 mem:$(sym snd_ptr),2)
l0=$(echo "$out" | memval $LIVESV 1); l1=$(echo "$out" | memval $LIVESV 2); l2=$(echo "$out" | memval $LIVESV 3)
l3=$(echo "$out" | memval $LIVESV 4); go=$(echo "$out" | memval $GO 1)
check "ships: $l0, still $l1 while the ship is lost, $l2 once the next appears; last one lost: $l3, game over $go" "[ $l0 -eq 2 ] && [ $l1 -eq 2 ] && [ $l2 -eq 1 ] && [ $l3 -eq 0 ] && [ $go -eq 1 ]"
gp=$(echo "$out" | grep "^mem $(sym snd_ptr)" | cut -d: -f2 | tr -d ' '); FXG=$(sym fx_gameover)
check "game over plays its jingle (sound at \$$gp, fx_gameover \$$FXG)" "[ \$((0x$gp)) -ge \$((0x$FXG)) ] && [ \$((0x$gp)) -lt \$((0x$FXG + 120)) ]"

# 3. A won area (waves cleared, boss defeated) goes through salute, warp,
#    map and arrival to the next area, back in play mode.
n=$(( 0x$SHOTS_END - 0x$ALIENS ))
z=$(printf '0%.0s' $(seq 1 $((n*2))))
out=$(run frames:30 'type: ' frames:300 "poke:$ALIENS,$z" poke:$AREA_DONE,01 poke:$ALIVE,00 poke:$(sym boss_state),04 frames:700 mem:$AREA,1 mem:$MODE,1 mem:$WARPF,1)
check "area clear leads to area 2, back in play" "[ $(echo "$out" | memval $AREA) -eq 1 ] && [ $(echo "$out" | memval $MODE) -eq 0 ] && [ $(echo "$out" | memval $WARPF) -eq 1 ]"

# 3b. The blast-off: from the salute into the warp the ship's art moves at
#     most a pixel across a frame and doesn't drop when the warp sprite
#     takes over (it used to nudge down and right).  Art top = y + PADY.
SD1=$(sym ship_dsc); s=""; for i in $(seq 1 160); do s="$s frames:1 mem:$SHIP,4 mem:$(printf %04X $((0x$SHIP+8))),2"; done
out=$(run frames:30 'type: ' frames:300 poke:$SHIP,3D "poke:$ALIENS,$z" poke:$AREA_DONE,01 poke:$ALIVE,00 poke:$(sym boss_state),04 frames:20 $s)
jm=$(echo "$out" | grep '^mem' | paste - - | awk -v sd=$SD1 '{x=strtonum("0x"$3); y=strtonum("0x"$5); d=$9$10; t=y+(d==sd?2:6); if(NR>1 && py<150){dx=x-px; if(dx<0)dx=-dx; if(dx>mx)mx=dx; dy=t-pt; if(pd==sd && d!=sd && (dy>1||dy< -5)) bad++} px=x; py=y; pt=t; pd=d} END{print mx+0, bad+0}')
set -- $jm
check "the ship blasts off without a nudge (largest step across $1, drops $2)" "[ $1 -le 1 ] && [ $2 -eq 0 ]"

# 3a. Boss overlays: area 1's boss is loaded from SFBOSS1.BIN before play,
#     and the warp to area 2 loads SFBOSS2.BIN during the map screen (its
#     header names boss2's hull).  Without the boss files the game stops
#     with a message (CANNOT LOAD...) instead of running on.
OC=$(sym ovl_cur); B2D=$(awk '/Symbol Table/{p=1} p' build/ovl2.lst | tr '|' '\n' | awk '$1=="boss2_dsc"{print $3}')
out=$(run frames:30 'type: ' frames:200 mem:$OC,1 "poke:$ALIENS,$z" poke:$AREA_DONE,01 poke:$ALIVE,00 poke:$(sym boss_state),04 frames:700 mem:$OC,1 mem:A200,2)
o1=$(echo "$out" | memval $OC 1); o2=$(echo "$out" | memval $OC 2); hd=$(echo "$out" | grep "^mem A200" | cut -d: -f2 | tr -d ' ')
check "boss overlays load: area 1 ($o1), then area 2 ($o2, header $hd = boss2 $B2D)" "[ $o1 -eq 1 ] && [ $o2 -eq 2 ] && [ $hd = $B2D ]"
NB=build/sd-noboss; mkdir -p $NB && rm -f $NB/*BOSS*.BIN && cp $BIN $NB/STARFALL.BIN
out=$($H $R/MC10.BIN mcx32sd:$R/mcx32sd_flash.bin 8k sd:$NB frames:200 'type:LOADM"STARFALL"\nEXEC\n' frames:120 'type: ' frames:30 'type: ' frames:200 mem:$OC,1 mem:$(sym ld_t),1 mem:$MODE,1 frames:200 mem:$(sym ld_t),1)
e1=$(echo "$out" | memval $(sym ld_t) 1); e2=$(echo "$out" | memval $(sym ld_t) 2)
check "missing boss file: the game stops with a message (BIOS error $e1, still $e2)" "[ $(echo "$out" | memval $OC 1) -eq 0 ] && [ $e1 -gt 4 ] && [ $e1 -eq $e2 ]"

# 4. The boss: with the waves cleared it arrives; shots up the channel
#    into its core (boss held still, ship lined up) destroy it, and the
#    victory warp leads to area 2.
BS=$(sym boss_state); HP=$(sym boss_hp); LIVES=$(sym lives); BOSS=$(sym boss)
BDX=$(printf '%04X' $((0x$BOSS + 4)))
sp=$(printf '%*s' 200 '')
out=$(run frames:30 'type: ' frames:300 "poke:$ALIENS,$z" poke:$AREA_DONE,01 poke:$ALIVE,00 frames:200 mem:$BS,1 poke:$HP,03 poke:$LIVES,09 poke:$BOSS,32 poke:$BDX,0000 poke:$SHIP,3A "type:$sp" frames:900 mem:$AREA,1 mem:$MODE,1)
check "the boss arrives after the waves" "[ $(echo "$out" | memval $BS 1) -eq 2 ]"
check "hits on the core destroy it; warp to area 2" "[ $(echo "$out" | memval $AREA) -eq 1 ] && [ $(echo "$out" | memval $MODE) -eq 0 ]"

# 4b. Area 2's boss has envoys: its core stays shut (shots do nothing)
#     until both envoys are destroyed, then it can be killed.  The ship is
#     kept invulnerable (the envoys bomb heavily).
EL=$(sym env_left); IV=$(sym invuln)
keep=""; for i in $(seq 1 10); do keep="$keep frames:20 poke:$IV,F0"; done
out=$(run frames:30 'type: ' frames:300 poke:$AREA,01 "poke:$ALIENS,$z" poke:$AREA_DONE,01 poke:$ALIVE,00 poke:$LIVES,09 $keep frames:130 \
      poke:$BOSS,32 poke:$BDX,0000 poke:$SHIP,3A "type:$sp" $keep mem:$HP,1 mem:$EL,1 \
      poke:$SHIP,26 "type:$sp" $keep poke:$SHIP,4E "type:$sp" $keep mem:$EL,1 \
      poke:$SHIP,3A "type:$sp" $keep $keep mem:$BS,1 mem:$AREA,1)
hp0=$(echo "$out" | memval $HP 1); e0=$(echo "$out" | memval $EL 1); e1=$(echo "$out" | memval $EL 2)
check "shut core takes no hits while envoys fly (core $hp0 of 10, envoys $e0)" "[ $hp0 -eq 10 ] && [ $e0 -eq 2 ]"
check "both envoys destroyed (left: $e1)" "[ $e1 -eq 0 ]"
bs3=$(echo "$out" | memval $BS 1)
check "then the open core is destroyed (boss state $bs3: dying, defeated or won)" "[ $bs3 -ge 3 ] || [ $bs3 -eq 0 ]"

# 4e. A swaying boss's core and envoys move with it without vibrating,
#     even when their objects hold stale pixel fractions (left by an
#     earlier boss: they used to jitter a pixel every other frame).
#     Sampled at the top of the game loop.
LOOP=$(sym loop); CO=$(sym core); E2=$(sym env2)
s=""; for i in $(seq 1 120); do s="$s bp:$LOOP mem:$BOSS,1 mem:$CO,1 mem:$E2,1 poke:$IV,F0"; done
gaps=$(run frames:30 'type: ' frames:300 poke:$AREA,01 "poke:$ALIENS,$z" poke:$AREA_DONE,01 poke:$ALIVE,00 poke:$LIVES,09 \
       poke:$(printf %04X $((0x$CO+1))),80 poke:$(printf %04X $((0x$E2+1))),80 poke:$(printf %04X $((0x$E2+3))),C0 $keep frames:200 $s | \
       grep '^mem' | paste - - - | awk '{b=strtonum("0x"$3); print strtonum("0x"$6)-b, strtonum("0x"$9)-b}' | sort -u | wc -l)
check "a swaying boss's core and envoys keep their places (distinct gaps: $gaps)" "[ $gaps -eq 1 ]"

# 4d. Area 4's fortress: it descends and stays put; its three cores are
#     shut while the envoys fly; with the envoys down the two side cores
#     open but the centre stays shut; with both side cores destroyed the
#     centre opens, and destroying it ends the boss.  (Fortress x 46:
#     ship x 32/82 under the envoys, 50/68 under the side cores, 59 under
#     the centre.)
CS=$(sym core_s)
keep3="$keep $keep $keep"
out=$(run frames:30 'type: ' frames:300 poke:$AREA,03 "poke:$ALIENS,$z" poke:$AREA_DONE,01 poke:$ALIVE,00 poke:$LIVES,09 $keep $keep frames:200 \
      mem:$BOSS,1 mem:$CS,3 \
      poke:$SHIP,3B "type:$sp" $keep3 mem:$HP,3 \
      poke:$SHIP,20 "type:$sp" $keep3 poke:$SHIP,20 "type:$sp" $keep3 \
      poke:$SHIP,52 "type:$sp" $keep3 poke:$SHIP,52 "type:$sp" $keep3 mem:$EL,1 mem:$CS,3 mem:$(sym alive_max),1 \
      poke:$SHIP,3B "type:$sp" $keep3 mem:$HP,3 \
      poke:$SHIP,32 "type:$sp" $keep3 poke:$SHIP,44 "type:$sp" $keep3 mem:$CS,3 mem:$BOSS,1 \
      poke:$SHIP,3B "type:$sp" $keep3 poke:$SHIP,3B "type:$sp" $keep3 poke:$SHIP,3B "type:$sp" $keep3 mem:$BS,1 mem:$AREA,1 \
      frames:900 mem:$(sym col_o),2)
bx0=$(echo "$out" | memval $BOSS 1); bx1=$(echo "$out" | memval $BOSS 2)
cs0=$(echo "$out" | grep "^mem $CS" | sed -n 1p | cut -d: -f2 | tr -d ' ')
hp0=$(echo "$out" | grep "^mem $HP" | sed -n 1p | cut -d: -f2 | tr -d ' ')
el=$(echo "$out" | memval $EL 1)
cs1=$(echo "$out" | grep "^mem $CS" | sed -n 2p | cut -d: -f2 | tr -d ' ')
hp1=$(echo "$out" | grep "^mem $HP" | sed -n 2p | cut -d: -f2 | tr -d ' ')
cs2=$(echo "$out" | grep "^mem $CS" | sed -n 3p | cut -d: -f2 | tr -d ' ')
bs4=$(echo "$out" | memval $BS 1)
check "the fortress stays put (x $bx0, later $bx1) with its cores shut (states $cs0, hits $hp0)" "[ $bx0 -eq 46 ] && [ $bx1 -eq 46 ] && [ $cs0 = 000000 ] && [ $hp0 = 06060E ]"
check "envoys down: the side cores open, the centre stays shut and unhurt (envoys $el, states $cs1, hits $hp1)" "[ $el -eq 0 ] && [ $cs1 = 010100 ] && [ \$(echo $hp1 | cut -c5-6) = 0E ]"
am=$(echo "$out" | memval $(sym alive_max) 1)
check "the unguarded fortress sends three escorts at once ($am)" "[ $am -eq 3 ]"
check "side cores destroyed: the centre opens (states $cs2), and destroying it ends the boss (state $bs4)" "[ $cs2 = 020201 ] && { [ $bs4 -ge 3 ] || [ $bs4 -eq 0 ]; }"
cols=$(echo "$out" | grep "^mem $(sym col_o)" | cut -d: -f2 | tr -d ' ')
check "the fortress's fall leaves the variables alone (text colours $cols)" "[ $cols = AA55 ]"

# 4f. In a long boss fight the escort waves count on, but a lost ship's
#     map shows it at the area's checkpoint, not climbing past it: with
#     wv_index at 48, the ship on area 1's map stays low (its topmost row
#     left of the strip).
DEADV=$(sym dead); DT=$(sym dead_t)
out=$(run frames:30 'type: ' frames:300 poke:$LIVES,09 poke:$(sym wv_index),30 poke:$DEADV,01 poke:$DT,02 frames:40 mem:4000,6144)
top=$(echo "$out" | grep '^mem 4000' | cut -d: -f2 | awk '{for(r=40;r<192;r++) if($(r*32+14+1)!="00"){print r; exit}}')
check "a long boss fight doesn't push the map's ship up (top row ${top:-none})" "[ -n \"$top\" ] && [ $top -ge 130 ]"

# 4g. Beating the last area's boss (the fortress) starts the finale (song,
#     fireworks, banners): a bonus of 10000 for every ship left, round 2,
#     then the warp to area 1 and play.
SC=$(sym score); RD=$(sym round)
out=$(run frames:30 'type: ' frames:300 poke:$AREA,03 "poke:$ALIENS,$z" poke:$AREA_DONE,01 poke:$ALIVE,00 poke:$LIVES,02 poke:$SC,000000 \
      poke:$BS,04 frames:20 mem:$MODE,1 mem:$RD,1 frames:900 mem:$SC,1 mem:$RD,1 frames:1500 mem:$AREA,1 mem:$MODE,1 mem:$RD,1)
m5=$(echo "$out" | memval $MODE 1); r1=$(echo "$out" | memval $RD 1); sc=$(echo "$out" | grep "^mem $SC" | cut -d: -f2 | tr -d ' ')
r2=$(echo "$out" | memval $RD 2); a0=$(echo "$out" | memval $AREA 1); m0=$(echo "$out" | memval $MODE 2)
check "the fortress's fall: finale (mode $m5), ship bonus (score's top byte $sc for 3 ships: 2 in reserve and the one flying), round $r1 -> $r2, then area $a0 in play (mode $m0)" \
      "[ $m5 -eq 5 ] && [ $sc = 03 ] && [ $r1 -eq 1 ] && [ $r2 -eq 2 ] && [ $a0 -eq 0 ] && [ $m0 -eq 0 ]"

# 4h. The finale's song is over when the ship blasts off, so the warp's
#     roar plays (it used to be silent); and a game starts with a ROUND 1
#     banner.
FXW=$(sym fx_warp); FXF=$(sym fx_finale); SPTR=$(sym snd_ptr)
out=$(run frames:30 'type: ' frames:300 poke:$AREA,03 "poke:$ALIENS,$z" poke:$AREA_DONE,01 poke:$ALIVE,00 poke:$BS,04 \
      bp:$(sym warp_begin) frames:5 mem:$SPTR,2)
p=$(echo "$out" | grep "^mem $SPTR" | cut -d: -f2 | tr -d ' ')
check "the warp after the finale roars (sound at \$$p, fx_warp \$$FXW)" "[ \$((0x$p)) -ge \$((0x$FXW)) ] && [ \$((0x$p)) -lt \$((0x$FXW + 16)) ]"
out=$(run frames:30 'type: ' frames:180 mem:$(sym banner_p),2 mem:$(sym s_round),9)
bp=$(echo "$out" | grep "^mem $(sym banner_p)" | cut -d: -f2 | tr -d ' ')
rt=$(echo "$out" | grep "^mem $(sym s_round)" | cut -d: -f2 | awk '{for(i=3;i<=9;i++) printf "%c", strtonum("0x"$i)}')
check "a game begins with a banner: $rt" "[ $bp = $(sym s_round) ] && [ \"$rt\" = 'ROUND 1' ]"

# 4i. Each round is harder, up to round 5: round 1 gentle (bomb spray 36
#     of 128 frames, 9 between bombs, cannons every 22, envoys every 16,
#     bombs 2 rows a frame); the finale's new round 2 takes a step (51, 8,
#     19, 14); from round 5 on, the hardest (96, 5, 10, 8, 3 rows).  Even rounds swap the
#     aliens' colours.
DV=$(sym spray_on)    # spray_on, bomb_gap, boss_fire, env_fire follow it
dvals() { echo "$1" | grep "^mem $DV" | sed -n "${2}p" | cut -d: -f2 | awk '{printf "%d %d %d %d", strtonum("0x"$1), strtonum("0x"$2), strtonum("0x"$3), strtonum("0x"$4)}'; }
AF=$(sym al_flip)
out=$(run frames:30 'type: ' frames:200 mem:$DV,4 mem:$AF,1 poke:$AREA,03 "poke:$ALIENS,$z" poke:$AREA_DONE,01 poke:$ALIVE,00 poke:$BS,04 frames:900 mem:$DV,4 mem:$AF,1)
d1=$(dvals "$out" 1); d2=$(dvals "$out" 2); f1=$(echo "$out" | memval $AF 1); f2=$(echo "$out" | memval $AF 2)
out=$(run frames:30 'type: ' frames:200 poke:$(sym round),05 poke:$AREA,03 "poke:$ALIENS,$z" poke:$AREA_DONE,01 poke:$ALIVE,00 poke:$BS,04 frames:900 mem:$DV,4 mem:$(sym round),1 mem:$AF,1)
d6=$(dvals "$out" 1); f6=$(echo "$out" | memval $AF 1)
check "rounds get harder: round 1 ($d1), round 2 ($d2), round 6 ($d6)" "[ \"$d1\" = '36 9 22 16' ] && [ \"$d2\" = '51 8 19 14' ] && [ \"$d6\" = '96 5 10 8' ]"
check "even rounds swap the aliens' colours (rounds 1, 2, 6: $f1 $f2 $f6)" "[ $f1 -eq 0 ] && [ $f2 -eq 1 ] && [ $f6 -eq 1 ]"

# 4j. Extra ships at 10,000 and every 25,000 (a big jump passes several);
#     aliens are worth 10 x the round (round 3: 30 each).
NB=$(sym next_bonus); SCV=$(sym score); STT=$(sym status_t)
out=$(run frames:30 'type: ' frames:300 mem:$LIVESV,1 poke:$SCV,010000 poke:$STT,01 frames:3 mem:$LIVESV,1 mem:$NB,3 mem:$(sym snd_ptr),2 \
      poke:$SCV,025000 poke:$STT,01 frames:3 mem:$LIVESV,1 poke:$SCV,080000 poke:$STT,01 frames:3 mem:$LIVESV,1 mem:$NB,3)
lv=$(echo "$out" | grep "^mem $LIVESV" | cut -d: -f2 | tr -d ' ' | tr '\n' ' ')
nb=$(echo "$out" | grep "^mem $NB" | cut -d: -f2 | tr -d ' ' | tr '\n' ' ')
sp=$(echo "$out" | grep "^mem $(sym snd_ptr)" | cut -d: -f2 | tr -d ' '); FXE=$(sym fx_extra)
check "extra ships: ships $lv(next at $nb), with their beeps (sound at \$$sp, fx_extra \$$FXE)" "[ \"$lv\" = '02 03 04 06 ' ] && [ \"$nb\" = '025000 100000 ' ] && [ \$((0x$sp)) -ge \$((0x$FXE)) ] && [ \$((0x$sp)) -lt \$((0x$FXE + 40)) ]"
mvk=""; for i in $(seq 1 6); do mvk="$mvk A A A A A A A A A A S S S S S S S S S S S S S S S S S S S S A A A A A A A A A A"; done
out=$(run frames:30 'type: ' frames:250 poke:$(sym round),03 poke:$LIVESV,09 "type:$mvk" frames:1500 mem:$SCV,3)
sc=$(echo "$out" | grep "^mem $SCV" | cut -d: -f2 | tr -d ' '); scn=$(echo $sc | sed 's/^0*//'); scn=${scn:-0}
check "round 3 aliens are worth 30 (score $sc, a multiple of 30)" "[ $scn -gt 0 ] && [ \$(($scn % 30)) -eq 0 ]"

# 4k. The sortie bonus: area 1's first wave (six saucers coming straight
#     down at x 30) destroyed quickly from below, none escaping, earns 10
#     x their value (100 in round 1: 60 + 100), and the next wave gets its
#     own sortie; a boss's escorts get none.
SON=$(sym sortie_on); sps=$(printf '%*s' 250 '')
s=""; for i in $(seq 1 60); do s="$s frames:10 poke:$IV,F0 poke:$SHIP,1C mem:$SON,1 mem:$SCV,3"; done
out=$(run frames:30 'type: ' $SEEDS frames:120 poke:$SHIP,1C "type:$sps" $s)
sb=$(echo "$out" | grep "^mem $SCV" | cut -d: -f2 | tr -d ' ' | grep -c '^000160$')
on2=$(echo "$out" | grep '^mem' | paste - - | awk '{s=$4$5$6; if(s>="000160" && $3=="01") n++} END{print n+0}')
check "a whole sortie destroyed quickly earns its bonus (score 160 seen $sb times; next sortie live $on2 samples)" "[ $sb -gt 0 ] && [ $on2 -gt 0 ]"
out=$(run frames:30 'type: ' frames:300 "poke:$ALIENS,$z" poke:$AREA_DONE,01 poke:$ALIVE,00 poke:$LIVES,09 $keep $keep frames:400 mem:$(sym boss_state),1 mem:$SON,1)
check "no sortie bonus for a boss's escorts (boss state $(echo "$out" | memval $(sym boss_state) 1), sortie $(echo "$out" | memval $SON 1))" "[ $(echo "$out" | memval $(sym boss_state) 1) -eq 2 ] && [ $(echo "$out" | memval $SON 1) -eq 0 ]"

# 4l. The boss's warning siren plays even if a bonus's beeps are still
#     sounding as it arrives (they used to keep it from starting at all).
FXB=$(sym fx_bossin)
out=$(run frames:30 'type: ' frames:300 "poke:$ALIENS,$z" poke:$ALIVE,00 poke:$AREA_DONE,01 bp:$(sym boss_start) \
      poke:$(sym snd_ptr),$(sym fx_bing) poke:$(sym snd_pri),08 frames:3 mem:$(sym snd_ptr),2)
p=$(echo "$out" | grep "^mem $(sym snd_ptr)" | cut -d: -f2 | tr -d ' ')
check "the boss's siren sounds over a bonus's beeps (sound at \$$p, fx_bossin \$$FXB)" "[ \$((0x$p)) -ge \$((0x$FXB)) ] && [ \$((0x$p)) -lt \$((0x$FXB + 80)) ]"

# 4c. No safe spot ("pizza break"): a ship that never moves is lost
#     within 30 seconds of area 1, at the start position and elsewhere.
#     (The bug: area 1's first wave dropped bombs at fixed points of its
#     path, and an unmoving ship between them lasted for minutes.)
DEADV=$(sym dead)
s=""; for i in $(seq 1 120); do s="$s frames:15 mem:$DEADV,1"; done
slow=""
for x in start 0 20 58 100 111; do
    p=""; [ $x != start ] && p="frames:60 poke:$SHIP,$(printf %02X $x) frames:60 poke:$SHIP,$(printf %02X $x)"
    t=$(run frames:30 'type: ' frames:2 $p $s | grep '^mem' | awk '{n++; if(strtonum("0x"$3) && !t) t=n} END{print t? int(t/4) : -1}')
    [ $t -lt 0 ] && slow="$slow x=$x"
    times="${times:-}$x:${t}s "
done
check "an unmoving ship is lost within 30 s ($times)" "[ -z \"$slow\" ]"

# The budget runs play the same game on every build: the random seeds are
# fixed as the game starts (the start-up seed comes from the free-running
# counter, so any code change played a different game and the figure
# wandered by a percent or two), and with no high score file on the card
# (a high score changes what the status bar draws).
rm -f $SD/STARFALL.HI

# 5. The frame budget holds in realistic play: two minutes of sweeping
#    side to side with fire held, through the area's full waves (the
#    old test, firing straight up from the centre, missed a regression).
mv=""; for i in $(seq 1 60); do mv="$mv A A A A A A A A A A S S S S S S S S S S S S S S S S S S S S A A A A A A A A A A"; done
over=$(run dbgport:BE00 frames:30 'type: ' $SEEDS frames:250 "type:$mv" frames:7200 | grep 'val=\$BB' | sed 's/.*dt=\([0-9]*\).*/\1/' | \
       awk '$1>14700 && $1<100000 {o++} END{printf "%.1f", 100*o/NR}')
check "frames over budget, sweeping with fire held: ${over}% (limit 2%)" "awk 'BEGIN{exit !($over <= 2.0)}'"

rm -f $SD/STARFALL.HI
# 5b. The fortress fight stays within budget too (the busiest boss: one
#     escort at a time), sweeping under it; and its patrolling envoys never
#     enter the hull's box.
mvf=""; for i in $(seq 1 25); do mvf="$mvf A A A A A A A A A A S S S S S S S S S S S S S S S S S S S S A A A A A A A A A A"; done
k90=""; for i in $(seq 1 90); do k90="$k90 frames:20 poke:$IV,F0"; done
over=$(run frames:30 'type: ' $SEEDS frames:300 poke:$AREA,03 "poke:$ALIENS,$z" poke:$AREA_DONE,01 poke:$ALIVE,00 poke:$LIVES,09 frames:500 \
       dbgport:BE00 "type:$mvf" $k90 | grep 'val=\$BB' | sed 's/.*dt=\([0-9]*\).*/\1/' | \
       awk '$1>14700 && $1<100000 {o++} {n++} END{printf "%.1f", 100*o/n}')
check "the fortress fight: frames over budget ${over}% (limit 8%)" "awk 'BEGIN{exit !($over <= 8.0)}'"
E1=$(sym env1)
s=""; for i in $(seq 1 100); do s="$s frames:3 mem:$BOSS,1 mem:$E1,1 mem:$E2,1 poke:$IV,F0"; done
ov=$(run frames:30 'type: ' frames:300 poke:$AREA,03 "poke:$ALIENS,$z" poke:$AREA_DONE,01 poke:$ALIVE,00 poke:$LIVES,09 $keep frames:200 $s | \
     grep '^mem' | paste - - - | awk '{b=strtonum("0x"$3); l=strtonum("0x"$6); r=strtonum("0x"$9); if(l+10>b+1 || r<b+35) o++; if(l<mn||!mn) mn=l; if(r>mx) mx=r} END{printf "%d %d %d", o+0, mn, mx}')
set -- $ov
check "the fortress's envoys patrol beside it, never into it (overlaps $1; left x from $2, right x to $3)" "[ $1 -eq 0 ] && [ $2 -lt 34 ] && [ $3 -gt 84 ]"

rm -f $SD/STARFALL.HI
# 5c. The hardest rounds stay within budget in normal play (more bombs):
#     the round-5 settings, sweeping with fire held, two minutes.
over=$(run dbgport:BE00 frames:30 'type: ' $SEEDS frames:250 poke:$(sym dlev),04 poke:$(sym dgap),08 poke:$DV,60050A08 poke:$(sym bomb_spd),0300 poke:$LIVES,09 "type:$mv" frames:7200 | \
       grep 'val=\$BB' | sed 's/.*dt=\([0-9]*\).*/\1/' | awk '$1>14700 && $1<100000 {o++} END{printf "%.1f", 100*o/NR}')
check "the hardest rounds: frames over budget ${over}% (limit 5%: as the boss fights)" "awk 'BEGIN{exit !($over <= 5.0)}'"

# 5d. The envoy bosses' fights with rapid fire stay within reason (fire
#     plays the zap, the hull's ping and explosions constantly: their tones
#     and noise are kept slow, every half-period being an interrupt; boss
#     2 and 3 ran 18-23% over before).  Boss 2, the ship firing and moving.
rm -f $SD/STARFALL.HI
spf=$(printf '%*s' 900 ''); mvb=""; xx=20; dd=4; for i in $(seq 1 270); do mvb="$mvb frames:6 poke:$IV,F0 poke:$SHIP,$(printf %02X $xx)"; xx=$((xx+dd)); [ $xx -ge 100 ] && dd=-4; [ $xx -le 16 ] && dd=4; done
over=$(run frames:30 'type: ' $SEEDS frames:300 poke:$AREA,01 "poke:$ALIENS,$z" poke:$AREA_DONE,01 poke:$ALIVE,00 poke:$LIVES,09 frames:500 \
       dbgport:BE00 "type:$spf" $mvb | grep 'val=\$BB' | sed 's/.*dt=\([0-9]*\).*/\1/' | awk '$1>14700 && $1<100000 {o++} END{printf "%.1f", 100*o/NR}')
check "boss 2 with rapid fire: frames over budget ${over}% (limit 10%)" "awk 'BEGIN{exit !($over <= 10.0)}'"

# 5e. The fortress's entrance (descending under the status bar while the
#     WARNING banner flashes) stays within budget with the ship firing: its
#     cores and envoys appear when it arrives, and the flashing banner
#     clears once per flash, not every frame (it ran 11% over).
rm -f $SD/STARFALL.HI
over=$(run frames:30 'type: ' $SEEDS frames:300 poke:$AREA,03 "poke:$ALIENS,$z" poke:$AREA_DONE,01 poke:$ALIVE,00 poke:$LIVES,09 poke:$IV,F0 \
       bp:$(sym boss_start) dbgport:BE00 "type:$(printf '%*s' 400 '')" frames:300 | grep 'val=\$BB' | sed 's/.*dt=\([0-9]*\).*/\1/' | \
       awk '$1>14700 && $1<100000 {o++} END{printf "%.1f", 100*o/NR}')
check "the fortress's entrance with the ship firing: frames over budget ${over}% (limit 3%)" "awk 'BEGIN{exit !($over <= 3.0)}'"

echo "----"
echo "$pass passed, $fail failed"
[ $fail -eq 0 ]
