#!/bin/sh
# shots.sh: screenshot series of StarFall from the headless emulator, for
# docs/ (run from the repository root after "make"): OUT/*.ppm, 320x240.
set -u
OUT=${1:-build/shots}
VMC10=${VMC10:-$HOME/vmc10-linux}; H=$VMC10/build/headless; R=$VMC10/roms; LST=build/starfall.lst
SD=build/sd-shots; mkdir -p "$SD" "$OUT"
cp build/starfall.bin "$SD/STARFALL.BIN"; for n in 1 2 3 4; do cp build/ovl$n.bin "$SD/SFBOSS$n.BIN"; done
sym() { printf '%04X' 0x$(awk '/Symbol Table/{p=1} p' $LST | tr '|' '\n' | awk -v n=$1 '$1==n{print $3}'); }
raw() { $H $R/MC10.BIN mcx32sd:$R/mcx32sd_flash.bin 8k sd:$SD frames:200 'type:LOADM"STARFALL"\nEXEC\n' frames:120 "$@" >/dev/null; }
IV=$(sym invuln); ALIENS=$(sym aliens)
n=$(( 0x$(sym shots_end) - 0x$ALIENS )); z=$(printf '0%.0s' $(seq 1 $((n*2))))
SEEDS="poke:$(sym seed),A5C3 poke:$(sym st_seed),5A3C"
# the title
raw 'type: ' frames:600 ppm:$OUT/title.ppm &
# play: an area's waves, firing, the ship kept invulnerable
a=""; for i in $(seq 1 40); do a="$a poke:$IV,F0 type:\\x20 frames:30 ppm:$OUT/play$i.ppm"; done
raw 'type: ' frames:30 'type: ' $SEEDS frames:200 $a &
# each boss: the waves skipped
for ar in 0 1 2 3; do
  b=""; for i in $(seq 1 30); do b="$b frames:20 poke:$IV,F0 frames:20 ppm:$OUT/boss${ar}_$i.ppm"; done
  raw 'type: ' frames:30 'type: ' $SEEDS frames:100 poke:$(sym area),0$ar "poke:$ALIENS,$z" poke:$(sym area_done),01 poke:$(sym alive),00 $b &
done
# the map between areas, and the finale after the fortress
m=""; for i in $(seq 1 40); do m="$m frames:10 ppm:$OUT/map$i.ppm"; done
raw 'type: ' frames:30 'type: ' $SEEDS frames:100 "poke:$ALIENS,$z" poke:$(sym area_done),01 poke:$(sym alive),00 poke:$(sym boss_state),04 $m &
f=""; for i in $(seq 1 30); do f="$f frames:40 ppm:$OUT/fin$i.ppm"; done
raw 'type: ' frames:30 'type: ' $SEEDS frames:100 poke:$(sym area),03 "poke:$ALIENS,$z" poke:$(sym area_done),01 poke:$(sym alive),00 poke:$(sym boss_state),04 $f &
wait
