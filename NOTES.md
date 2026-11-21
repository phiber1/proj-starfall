# StarFall: design notes

StarFall is a vertical space shooter for the TRS-80 MC-10 with the 8K
internal RAM mod and an MCX32-SD, in NTSC artifact colour (128x192, four
colours).  It was developed inside mc10-game-engine (github
phiber1/mc10-game-engine) and split out on 2026-11-20 at engine commit
709f5ff; that repository's history holds every commit up to then.  The
engine is the `engine/` git submodule here.  For the engine itself (the
timing model, sprites, sound, the toolchain, the memory segments and
loading) read `engine/NOTES.md`.

Below: the game's design history, as it was written during development
(file names updated to this repository's layout).

### Game prototype (`src/starfall.asm`)

* Title screen (working title STARFALL) with a colour sample: C runs
  `col_swap` (engine/colswap.asm: decodes each sprite's halo routines and
  swaps the bit pairs of every data byte) and swaps the text colour masks.
* "PLAYER 1" banner at the start and after each lost ship; status line
  (SCORE in BCD via DAA, SHIPS) redrawn every 12 frames because sprites and
  stars cross it.
* Bombs and collisions with aliens destroy the ship (bigger, longer
  explosion and sound); respawn flashing and untouchable for 2 s; GAME
  OVER after the last ship, then back to the title.
* engine/text.asm + font.asm: a 3x5 artifact font, one byte per
  character (32 per line), normal and double height; generated from glyph
  art by tools/mkfont.py.
* Tested headless: swap, start, three deaths, game over, title.  Fire
  held: median 9.5K cycles, 0.6% of frames over budget.

### Areas, map, victory warp, jingles

* Four areas, each a wave list (later areas launch faster); when an
  area's waves are done and no alien is left: AREA CLEARED, +1000, the
  victory salute, then the warp: the ship (afterburner sprites shipw1/2,
  alternating flame, halo 1 across / 6 down so each frame covers the
  other's flame tip at 4 rows a frame) accelerates up, flies off the top,
  through both gutters, back in at the bottom, and brakes to a stop while
  the stars streak (stars_update called up to 6 times a frame; it now
  alternates halves per call).  Then the map and the next area (after the
  last: round again).  Bosses will go at each area's end.
* Map screen at the start, after a lost ship and on arriving in an area:
  PLAYER 1, AREA n, a strip of the areas with boss markers, the ship at
  its progress.  Play pauses; sound continues.
* Jingles: start fanfare, fresh-ship phrase, victory salute; a rising
  noise roar for the afterburner.
* **Memory is getting tight:** the game ends at $A707 (~2.3K left below
  $AFFF).  Next step for space: move tables, text and the font to the
  MCX32-SD's low SRAM ($0400-$1FFF, ~7K), copied there at start.
* **Owner playtest:** finished all four areas to the restart on the third
  try ("challenging").  Fixes from it: the blast-off now slides behind the
  status bar (a solid band redrawn after the sprites during the climb),
  the ship disappears above the top and only rises in from the bottom
  after the map screen (modes WARP -> COAST -> map -> ARRIVE); waves only
  launch during play; stars no longer start in a diagonal (st_rnd steps
  its LFSR 8 bits per byte: single steps made consecutive bytes shifted
  copies); the colour question appears only before the first game.
* **Bug (owner report): stars rushing, ship stuck and flickering, aliens
  slow.**  Two causes: (1) the game's direct-page variables had grown
  into the engine's hit_test scratch at $F8, so every collision test
  overwrote warpf (star updates per frame) and its neighbours; (2) a
  nameless `+` label: new `+` labels inserted between `beq +` and its
  target sent play mode into the arrival code every frame.  Fixes: less
  frequently used variables moved to BSS ($5C00-$5EFF, between the gutter
  and the stack); DP_CHECK / BSS_CHECK macros fail the assembly on an
  overflow; named labels for multi-way dispatch.
* **`make check`** (tests/game_check.sh): headless checks run before
  handing over a build: the ship answers the controls in play, a forced
  area clear reaches the next area back in play, and the frame budget
  holds with fire held.
* **Status bar in front (owner request):** the VDG always shows from
  $4000 and the gutters need hidden memory above the playfield, so the
  playfield can't simply start below the bar.  Instead the bar (rows 0-6)
  is rendered into a buffer when the score or ships change, and copied
  over the screen after the sprites on any frame a sprite touched it
  (sprman flags objects over rows < sm_band or above the top).  The copy
  is a per-row stack blast (LDAA n,X / PSHA, ~240 cycles a row with
  interrupts off).  Shots end under the bar; stars stay below it
  (STAR_TOP).  Aliens now slide out from under the bar.

### Memory segments and loading (2026-11-17)

* The 8K mod + MCX32-SD are required, so programs ship as a DECB `.BIN`
  loaded with the MCX32-SD's `LOADM` (no `.C10`, which is one contiguous
  block).  `tools/p2decb` reads ASL's object file and writes one segment
  per contiguous block, failing the build for any byte outside
  `$0400-$1FFF` (low) and `$6000-$ADFF` (main).
* What LOADM itself uses (measured in the emulator): the direct page,
  `$0103-$0104`, `$022A-$0283`, `$0316-$0317` (BASIC's variables beside
  the interrupt hooks), and BASIC's stack at ~`$AF2C` with string space
  above.  No RAM sector buffer: the BIOS copies straight to the target.
* Game: low `$0400-$1E6B` (alien and explosion sprites, sine table, 6.7K),
  main `$6000-$8E53` (11.6K): ~8K free in main, ~400 bytes in low.
  LOW_CHECK / CODE_CHECK fail the assembly on overflow.
* `make run-NAME` uses `build/sd` as the SD card; `make check` loads the
  game with LOADM too.  Both segments verified byte-exact by checksum.

### Bosses (first: the mothership)

* After an area's waves: WARNING!, a siren, and the boss descends from
  under the status bar, then sways at half a pixel a frame (halo 1 1:
  ~570 cycles to draw) while its two cannons fire (sharing the bomb
  rhythm via `bomb_at`) and escort waves loop around it.
* Weak spot: a separate core sprite in the hull's opening, moved with it;
  only core hits count (8/12/16/20 by area).  The art has a channel under
  the core and shots in the core's column pass the hull's hit box (the
  core sits inside the hull's rectangle, so without that every shot
  pinged off the hull).  Core flashes white, clang; hull hits ping.
* Defeat: the escorts explode, bursts across the hull for 2 s, +5000,
  then the salute and warp.
* Cost: boss fight median ~11.1K cycles/frame, <1% over budget, after
  lowering the ping (a 2 kHz tone cost ~30% CPU while playing) and a
  quick reject before the boss hit tests.  Main segment ends ~$9AE0.
* make check covers the boss: arrival after the waves, kill, warp.
* **Bug (owner report): the boss came after one wave.**  Another nameless
  label: new `+` labels inserted into wave_logic retargeted a `bne +`, so
  every "start the next wave" went to "the area's waves are done".  Fix:
  `tools/nameless.py` converted every nameless label in src/starfall.asm to
  a named one (the binary came out byte-identical, proving the conversion
  exact), then the fix was made with named labels.  New check: in normal
  play neither the area's end nor the boss comes before area 1's third
  wave (it flags the buggy build: 52 bad samples of 60).
* Rule from now on: no new nameless labels in the game; convert engine
  files the same way when next touching them.
* **Playtest round (owner):** losing a ship now clears the field (aliens,
  bombs, shots); survivors are relaunched along the current wave's path
  and still count toward the area.  Areas doubled to 8 waves each
  (remixed types and paths, later areas faster; the map shows 3 rows per
  wave).  Boss theatrics: ~4 s of eight low falling wails, a flashing
  WARNING!, a slow descent, escorts only after the warning.  The map
  no longer labels the checkpoints: the bosses are a mystery.
* Next bosses (owner's design): envoys on either side that bomb heavily,
  the core shielded until all envoys are destroyed; later bosses with
  more envoys and several weak spots that must all be destroyed.

### Envoy bosses (areas 2-4)

* Boss table per area: core hits, envoys (0 or 2), hits per envoy,
  escorts.  Area 1: the plain mothership; areas 2-4: two envoys (4/6/8
  hits) flanking the hull (moving with it; the sway range narrows to keep
  them on screen), bombing every 16 frames outside the spray rhythm
  (`bomb_force`).  The core shows a closed hatch (coreshut) and pings
  until both envoys are destroyed (+500 each); then it opens (a rising
  chime) and takes damage.  Same hull as boss 1 (a new hull is ~3K).
* Collisions: envoys get a quick horizontal reject; the core and hull
  tests use simple column/row checks (the quick reject already put the
  shot in the boss's rows).  Escort waves are smaller in envoy fights.
* Frame budget (worst case: fire held, test ship kept invulnerable and
  flashing): ~6-9% of frames over in envoy fights, a brief slowdown like
  arcade boss fights.  Normal play: 0%.
* make check: the shut core takes no hits, both envoys die, then the core.
* **Regression (owner report): slowdowns in normal waves with rapid fire.**
  Found by comparing against the last good build (8f4866e) in a
  two-minute sweep-and-fire run: heavy frames had grown (p95 12.9K ->
  14.3K, 1% -> 3.5% over), mostly from the 8-alien waves (up to 10 on
  screen), which multiplied collision work and status-bar repairs.  Fixes:
  each shot meets the aliens only every other frame (alternating), and
  the ship meets bombs and aliens on alternate frames (the overlap
  windows are deeper than two frames' movement; shots against the boss
  stay every frame, the core's window is shallow); the status bar repair
  copies with LDD/PSHB/PSHA and clears its blank rows.  Now: median 7.2K,
  p95 11.1K, 0.6% over, better than the old build.  The budget check now
  uses that sweep-and-fire scenario (limit 2%).
* **Sliding window (owner's idea):** at most MAX_ALIVE = 8 live aliens fly
  at once; the rest of a wave (and relaunched survivors, and escorts) wait
  their turn and slip in as others die.  The area's tally is unchanged.
  make check: never more than 8 seen in two minutes of play.
* **Bug (owner report): the status bar vanished.**  The faster bar repair
  called a row-clearing routine with JSR, but that routine restored S to
  the value its caller had saved (before the JSR pushed a return
  address), so its RTS returned out of the whole repair, skipping the
  text rows.  Fix: the routine saves its own S.  New checks: the screen's
  rows 0-6 match status_buf during play, and the buffer holds text (the
  broken build fails them).
* **Bug (owner report): a dart stuck half off the right edge, wrapping
  onto the left, unshootable.**  Staggered-lane waves step the entry x
  per launch; when relaunched survivors made more launches than lanes,
  the x ran off the screen (lane 10 of the dart wave entered at x 251),
  and the side-edge mirror can't recover an alien that is already off
  screen and diving straight down.  Fixes: entry lanes wrap back to the
  first one; any live alien found off the side is put back inside and
  turned round.  Reproduced deterministically (14 launches, alive held
  open: the old build puts an alien at x 251) and added to make check.

### Wrap-around aliens (owner's request, Galaxian-style)

* `P_WRAP 1` in a flight script lets an alien fly through the side edges
  (flight.asm F_FLAGS / FF_WRAP; objects are now 20 bytes, AN_BASE 7).
  While straddling an edge its spilled part draws at the other side one
  row lower (the screen's rows are laid end to end); when the next move
  would cross, the old image is erased (the halo can't bridge the jump:
  a one-frame flicker) and x flips by 128 (x < 128, so toggle bit 7).
  Edge mirroring and off-side recovery skip wrapping aliens.
* New paths (pathsim: crossings, no climbing off the top): sweepR /
  sweepL (long shallow diagonals with curves), weave (fast horizontal
  passes with U-turns, then a dive).  A wrap wave or two in every area.
* make check: forced sweep wave, aliens cross right -> left (6 in 10 s),
  none stays straddling.  Main segment ends $A3A6 (~2.6K free).

### State and next steps (2026-11-17, before a context compaction)

* Owner playtest: hard but fair ("will definitely challenge folks"); not
  yet past the area 3 boss; beat the area 2 envoy boss.  Wrapping darts
  are a great surprise but too rare: add more sweep/weave waves.
* Owner request: **physically different bosses** (story: the area 1
  mothership is dead by area 2).  Memory now: main ends $A3A6 (~2.6K
  free), low ~400 bytes free.  A 24x12 halo 1 1 hull costs ~2.8K.
* **Done: the "pizza break" (owner's report).**  An unmoving ship at
  the start lasted 90 s+ (minutes) in area 1: the first wave (saucers,
  path_loopL) dropped bombs only at fixed P_EVENT points, so its bombs
  fell in four narrow columns (x 30-34, 48-51, 73-76, 91-93) and the
  start spot (x 59) lay between them; the dives cross the middle below
  the drop limit.  Fixed with three changes: (1) path bombs are thrown:
  they keep half the alien's sideways speed (bomb sprite now halo 1 3;
  bombs leaving a side are freed), so they land spread along the dive
  and loop lines; (2) more drop points around the loops (every quarter
  turn); (3) aimed drops: an alien whose bomb would leave within 2 px of
  the ship's nose (AIM_W) drops straight down; the spray rhythm and
  BOMB_GAP still gate every drop.  The drop limit is now relative to the
  ship (BOMB_WARN: 36 rows above it, 12 frames to dodge) instead of a
  fixed y 112.  An unmoving ship is now lost in 3-21 s anywhere
  (slowest: the start and the centre, 16-21 s); a sweeping player loses
  ships at the old rate and the frame budget is unchanged.  make check
  4c guards it (six positions, 30 s each); it fails on the old build.
* **Done: circling aliens come back somewhere new (owner's request).**
  path_circle/circleR (the orange orbiters, and area 1's escorts) dived
  in the same columns every pass, so on a boss screen the player could
  ignore them and wait for the boss.  Now the paths start with P_EVENT 2
  (left circles) or 3 (right): the game sets F_FLAGS bit FF_HOPL/FF_HOPR,
  and each time such an alien comes through the bottom it re-enters at a
  random x (1-96, or 22-117 for left circles, so the circles stay on
  screen; pathsim: the circle spans x0-21..x0 / x0..x0+20).  Events on a
  path's first commands are now seen at launch too (wave_logic runs the
  first fl_step).  rnd steps its LFSR 8 bits per call (one bit gave runs
  of near-equal values: x 103, 103, 103).  make check 2e.
  Then (owner: the instant jump "almost seems like a minor error") each
  hop waits out of sight: at the new x above the top, velocity zero, a
  count of HOP_WAIT (24) in F_FLAGS bits 3-7 (FF_WAIT1 = $08) counted
  down on alternate frames (col_par); at zero fl_velocity resumes the
  path where it was.  Out of sight ~55 frames per hop (check 2e).
  The owner saw no pause at first: the orbiters fly in a column 14
  frames apart, so as one left the bottom an earlier one re-entered at
  the top, which reads as an instant swap.  So each alien now waits its
  own random time: HOP_WAIT + 0-15 counts of 4 frames (spray_t & 3),
  i.e. 40-100 frames; out of sight 46-109 frames, staggered.
  Still too close for the owner, so now the whole column empties first:
  aliens_logic counts hopping aliens on screen (hop_vis) and waiting
  (hop_park) each frame; the waiting ones count down only once none is
  on screen (hop_rel latches until none is waiting).  Out of sight
  85-198 frames; check 2e verifies an empty screen before every
  re-entry.
* **Boss 1 hull: antennae (owner's idea).**  The top corners are
  notched (a dome between flat shoulders) and a diagonal antenna rises
  from each shoulder, up and outward, orange-tipped: 24x16 (4 rows added
  on top, BOSS_TOP).  BOSS_Y, ENV_DY, CORE_DY and the cannon offset add
  BOSS_TOP, so the hull, core, envoys and cannons sit where they did.
  +551 bytes main.
* **Bosses 2 and 3 (owner's designs, 2026-11-18).**  sprites/boss2.spr
  (a classic flying saucer with portals, low segment) and boss3.spr (a
  glass dome with a one-eyed occupant, main segment) are the owner's
  files; each also holds its envoy (drafts by Claude: envoy2 a mini
  saucer drone, envoy3 a floating eyeball with tendrils).  boss_tab rows
  (BOSSROW macro, BT_SIZE 13) now pick the hull, envoy sprite, the core
  opening's row, the envoys' row and the cannon columns per area; all
  hulls must be 24x16 with the opening in columns 10-13 (assembly-time
  check).  Area 4 uses boss 1 until the owner designs the finale (bigger,
  several cores/channels).  Memory after: low ends $1EE5 (~280 bytes
  free), main $A8A8 (~1.4K free): boss 4 will need room (candidates:
  moving tables or code to low/main, fewer shifts for slow parts).
* **Boss 4, the fortress (first draft by Claude, 2026-11-18; the owner
  may rework the art).**  sprites/boss4.spr: 34x18 art (36x20 box), a
  battlement with a spire and antennae, three pods with cores, four
  cannons; compiled for shift 2 only (it descends, then never moves
  across: x 46); envoy4 (a spiked mine drone) is shift 0 only, as the
  envoys don't move either (x 34 and 84).  Bosses are now data: boss_tab
  rows (BOSSROW, BT_SIZE 18) give envoys, escorts, hull, envoy, a core
  list (CORE column, row, stage, hits; up to NCORE = 3 core objects), a
  cannon list (CANNON column, row; fired in turn), envoy row, x, stop
  row, still/sway, box size.  Core stages: 0 opens when the envoys are
  gone, 1 when every stage 0 core is destroyed; a destroyed core
  explodes (the last one ends the boss as before).  Fortress: side cores
  6 hits each, centre 14.  make check 4d.  Memory is now full: main ends
  $ADA8 (87 bytes free), low $1FED (18 free); the area wave lists moved
  to the low segment to make room.  Next: free memory (see the options
  discussed with the owner) before the title and colour screens.
* **Colour check screen (owner's request, 2026-11-18).**  Its own screen,
  once, right after loading (colour_check, falling through from start):
  an orange block, "C" swaps orange and blue, SPACE (let go first) goes
  on to the title, which no longer shows the sample and stays the same;
  game over returns to the title only.  col_ok is gone.  make check 1a;
  the tests' run() passes the check with a SPACE first.  Main segment
  now ends $ADEE (17 bytes free).
* **Boss overlays from the SD card (2026-11-18, owner: "worth a shot").**
  Each boss's hull and envoy (sprites/bossN.spr; boss 1's moved out of
  game.spr) is assembled by src/ovl/boss.asm at OVL_BASE ($A200-$ADFF,
  src/ovl.inc) into build/ovlN.bin, copied to the SD card as
  SFBOSSN.BIN (make run-game and make check do it).  Header: fdb hull_dsc,
  envoy_dsc, 0 (boss_start reads it; it's also the col_swap list, applied
  after a load if the colours were swapped).  map_show calls ovl_need:
  if the area's overlay (boss_tab BT_OVL) isn't the one in memory
  (ovl_cur), LOADM "BOSSn" through the MCX32-SD BIOS (JSR $2000, fn 22,
  mode 2; hw.inc names the parameter block), interrupts on so the frame
  tick times it (ld_t, frames), and the map waits only what's left of
  MAP_TIME.  Debug builds show "LOAD nnn" on the map: 4 frames in the
  emulator (the real BIOS byte loop runs there) - check it on hardware.
  boss_start calls ovl_need too (a safety net).  A failed load stops the
  game with "CANNOT LOAD THE BOSS FILE" (error code in ld_t).  The BIOS
  writes only its parameter block and the stack (checked by breakpoints
  around the call).  spritec -e gives the game the bosses' constants.
  Memory after: main ends $9451 (~3.5K free below OVL_BASE), low $15FA
  (~2.5K free); overlays 3036 (boss 1, the biggest), 2553, 2766, 982
  bytes.  make check 3a.  Distribution is now STARFALL.BIN + SFBOSS1-4.BIN (+ STARFALL.HI, made by the game).
* **Fixed: the arriving ship wrote into BSS.**  It started at y 208 in
  the 30-row warp sprite, so rows 224-237 went past the bottom gutter
  ($5800-$5BFF) into BSS at $5C00 (zeroing a strip of variables at every
  arrival; found when ovl_cur was cleared).  It now starts at
  224-shipw1_H (an assembly-time check).  Rule: nothing may be drawn
  past row 223 from below (aliens wrap and bombs end before 192).
* **Fixed, from the owner's two play-throughs (2026-11-18):**
  * Boss cores/envoys vibrating: boss_attach set their x/y but not the
    pixel fractions, so a stale fraction (left by an earlier boss's
    objects) made their steps drift against the hull's: a pixel back and
    forth every other frame.  ba_place now copies the hull's fractions
    (make check 4e pokes stale fractions and samples at the loop top).
  * Ship climbing the map in a long boss fight: the escort waves loop and
    count on in wv_index; the map caps it at AREA_WAVES (8) (check 4f).
  * After the fortress, the map showed area 2, garbled text, a mangled
    score: boss_die explodes every flying alien, and one exploding low
    while diving drifted past row 223 into BSS ($5C00: col_o/col_b, area,
    wv_index ...).  Exploding aliens now stop drifting down at
    192-AL_H (check 4d reads col_o/col_b after the fall).  Same rule as
    the arrival fix: nothing may be drawn past row 223 from below.
  * Status bar holes: obj_erase over the band didn't set sm_dirty, so an
    explosion ending over the bar left a hole until something else
    crossed it; obj_erase now counts like a drawing (engine/sprman.asm).
  * Fortress envoys unbeatable: stationary, their bombs fell in one
    column exactly where the ship had to be to shoot them (one exact x
    worked).  A still boss's envoys now patrol +/-ENV_PATROL (8) px at
    ENV_PATROL_V (env_ofs/env_v, added in ba_patrol; started on arrival);
    envoy4 is back to four shifts (overlay 4: 1453 bytes).
* **Fortress fight slowdown (owner's play-through, 2026-11-18).**  31%
  of frames over budget sweeping under it: the fortress alone (hull
  ~1040 cycles a frame, three cores, two patrolling envoys, four cannons)
  takes ~11K of the 14.9K cycles, and each escort ~700 more.  Escorts
  flying at once are now per boss (alive_max, BT_ALIVE; MAX_ALIVE 8 for
  bosses 1-3, FORT_ALIVE 1 for the fortress): 4-6% over (check 5b).
  The envoys patrol outwards only, mirrored (0..ENV_PATROL 12 px out:
  they overlapped the hull before); a surviving envoy keeps its own
  pace (it used to take its partner's turns: every boss); the fortress's
  envoys take 6 hits.  Profiling note: DBGA markers clobber A, so put
  them only where A is dead.
* **Ships count (owner):** it drops when the fresh ship appears (before
  its phrase), or to 0 with GAME OVER after the last, not at the hit
  (check 2f).
* **The finale (owner: "a lot more pomp and circumstance").**  Beating
  the last area's boss runs MODE_FINALE instead of the salute: fx_finale
  (an original ~9.5 s victory march), fireworks (a burst every 4 frames
  in free alien slots, anywhere), banners on a countdown (fin_t from
  FIN_TIME 600): THE FORTRESS HAS FALLEN! (flashing), ALL FOUR BOSSES
  DEFEATED, SHIP BONUS: 10000 EACH (added: +1 to score's top BCD byte
  per ship), ROUND n (round, from 1, shown up to 9; nothing else changes
  per round yet), then warp_begin into the next round.  check 4g.
  Then (owner): the first banner stays ~3.3 s; FIN_TIME 720 (the song
  is ~680 frames: snd_frame spends a frame loading each segment, and a
  NOTE is two), so its priority 9 no longer silences the warp's roar;
  fx_warp now plays at priority 9 anyway.  A game starts with a ROUND 1
  banner (round_banner).  check 4h.
* **Title screen (draft, 2026-11-18).**  The name big (big_str /
  big_char: the 3x5 font magnified, each pixel 3 artifact pixels by 6
  rows, a letter 3 bytes by 30 rows, in colour bands bg_band through
  bg_cols = white/col_o/col_b, so it follows the colour swap), "MEET
  THE ALIENS" with the three aliens' real sprites and names (Claude's
  names, the owner's choice: SWOOPER the saucer (was LOOPER), ZAGGER the dart, WARPER
  the orbiter; the cast table), the start prompt, the controls and the
  credits line "AN ABENE GAME".  Bosses and envoys stay off it
  (mysteries).  The name STARFALL sticks (owner: no well-known game has
  it) unless something better comes up.  The title has the star field behind it (stars.asm st_behind: a star
  plots only into an empty byte, else stays undrawn with bit 15 of
  S_ADDR set and erases nothing; the game keeps plain stars).  check 1c.
  Only WARPERs warp: boss 1's escort saucers fly path_loopL, not
  path_circle (the owner noticed LOOPER and WARPER sharing moves).
* **TODO (owner, 2026-11-18), if the code fits:**
  * **Done (2026-11-19): high score file.**  STARFALL.HI on the card:
    "SF", the BCD score, a checksum (sum of the five), 6 bytes.  Read
    once at start-up (hi_load; missing or bad: 0), written when a game
    with a record ends (hi_save, from title), through the BIOS's
    data-file calls as BASIC's OPEN/PRINT#/CLOSE do (close 'D' first,
    open fn 2 with B=$42, PB_IN/PB_OUT | file 1, read fn 6 / write fn
    12, close fn 0); card errors ignored.  Status bar: SCORE 000000  HI
    000000  SHIPS 3 (exactly 32 columns; HI follows a new record live,
    hi_check in status_update); only there (the owner: the title was
    crowded with it).  check 1d.  The bar's labels are drawn once per game (status_labels); a score
    change rewrites only the digits (HI only when beaten): drawing HI
    too had pushed the normal-play budget to 2.3% over; now 0.5%.  A top-five table with initials could follow.
  * **Done: PI-KEY10.**  It drives a switch matrix in place of the MC-10's
    keyboard, so joysticks arrive as key presses; its default for
    Joystick 1 is W, A, S, Z and SPACE (the owner checked pikey.tech),
    exactly what kbd_read reads.  Supported as is, nothing to change.
  * **Done (2026-11-19): difficulty rising each round.**  set_diff (at a
    game's start and each new round in the finale): dlev = round - 1, at
    most DIFF_MAX 4.  Per step: bomb spray window +12 frames (48 -> 96 of
    128), bombs 1 frame closer (7 -> 3), cannons 3 frames (22 -> 10),
    envoy bombs 2 (16 -> 8), wave launches 2 frames closer (min 6), +2
    hits per boss core, +1 per envoy.  Bomb speed unchanged (the bomb's
    halo is 3 rows).  Round 1 as designed.  Checks 4i and 5c (hardest
    settings 3.4% over budget in normal play, limit 5% like the boss
    fights; if it feels slow, bomb_gap min 4).  Even rounds swap the
    aliens' orange and blue (owner: the old arcade trick): al_colours
    runs col_swap on al_sprites (saucer, dart, orbiter) when the round's
    parity differs from al_flip; the title resets it, so the cast shows
    its own colours; a colour-check swap on top still combines right.
  * **Done (2026-11-20): file names.**  On the card the game is
    STARFALL.BIN (LOADM"STARFALL"), its bosses SFBOSS1-4.BIN, its high
    score STARFALL.HI.  The source stays src/starfall.asm (make run-game);
    the Makefile's sdname maps it.
  * **Boss 4's look:** the fortress art is still Claude's first draft;
    the owner hasn't decided on changes yet.
* **Owner's play-through notes (2026-11-19), done:**
  * Blast-off nudge: the warp sprite's halo is 4 rows taller above the
    ship (PADY 6 vs 2), so swapping sprites at one y dropped the art,
    and its one shift snapped x right.  warp_begin/arrival adjust y by
    shipw1_PADY-ship_PADY; the salute and finale glide x onto the warp
    shift (ship_align, a pixel every other frame).  Check 3b.
  * Extra ships at 10,000, 25,000 and every 25,000 after (owner: round
    numbers), up to 9 (bonus_check, next_bonus BCD; a big jump awards
    each threshold).  Check 4j.
  * Aliens worth 10 x the round (score_alien; round shown up to 9).
  * Fortress: once both envoys are gone it sends 3 escorts (alive_max
    +2): ~4.9% over budget, like the other fights.
  * "THE SPACE FORTRESS HAS FALLEN!"; the title asks CAN YOU DEFEAT THE
    / SPACE FORTRESS? (the cast moved up 4-12 rows to fit it).
* **Bosses 1 and 3 re-imagined (2026-11-19, with the owner).**  Boss 1
  is a stag beetle seen from above (wing cases, legs, pincer mandibles
  around the core: core row 10, cannons at the pincer tips, columns 7
  and 16); boss 3 a cephalopod (bulbous head, one wide orange eye,
  tentacles; cannons at columns 9 and 14, its own list cans3).  Drafts
  were made with tools in $TMPDIR and viewed with make run-view.  The
  owner's favourites stay: boss 2 and the space fortress.  The hardest
  rounds' bomb gap now stops at 4 frames (3 sat on the edge of the
  budget: 3.4-5.9% over between builds; now 1.2%).
* **Extra ship beeps and a sound board (2026-11-19).**  fx_extra: E6
  three times (priority 8: over game sounds, under jingles).  The sound
  effects live in src/sounds.inc; src/sfx.asm (make run-sfx) plays
  any of them from a list.  Budget checks now fix the random seeds at
  game start and remove STARFALL.HI first, so every build plays the same
  game (the figures had wandered 0.4-2.3% with no real change).
* **SHIPS counts the reserve (owner, 2026-11-19):** lives no longer
  includes the ship flying.  START_SHIPS 2 (3 ships in all); losing a
  ship with 0 in reserve ends the game; extra ships up to 9 in reserve;
  the finale's ship bonus counts lives + 1 (the one flying too).
* **Fixed (2026-11-20): boss 1 unbeatable-ish after the redesign.**  The
  beetle's cannons at its pincer tips (columns 7 and 16) bombed every
  spot from which the ship can hit the core (its gun under columns
  10-13 puts the 8-pixel hull over 7-17); the old mothership's (4, 18)
  left them clear.  Now the pincers' outer bases (3, 20); the squid's
  outer tentacles (5, 18, were 9 and 14).  An assembly check (B1_CAN_*,
  B3_CAN_*) keeps them at 6 or less / 18 or more.  The waves were
  verified unchanged (yesterday's and today's builds play the same game
  frame for frame).  Boss 2's (8, 14) stay: the owner likes its fight.
* **Round 1 made gentler (owner, 2026-11-20: "can't get to Area 4").**
  Bombs 2 rows a frame in round 1 (bomb_spd, +1/4 a round to 3 by round
  5; BOMB_SPEED $0200), spray window 36 of 128 frames (+15 a round to
  96), at least 9 frames between bombs (-1 a round to 5).  The scripted
  sweep loses ~4 ships in two minutes instead of 8-9 (three seeds); a
  parked ship is still lost within 30 s.  The normal-play budget sits at
  1.8% (slower bombs stay on screen longer).
* **Sortie bonus (owner's idea, 2026-11-20).**  A wave destroyed whole,
  of its own type only, none of it leaving through the bottom, the kills
  at most SORTIE_GAP (180 frames) apart, the ship not lost, not a boss's
  escorts: 10 x the alien's value (100 x the round) and fx_bing
  ("ba-BING!", A5 then a ringing D6; on the sound board).  A sortie
  starts at its wave's first launch (sortie_new; it doesn't cancel one
  still being finished off); another type's kill breaks it only after
  its first kill (stragglers from the last wave don't).  Tracked by
  alien type (no spare byte per alien), so a straggler of the same type
  from the previous wave can count towards the next.  Check 4k.
  Then (owner: the bonus came with one alien left): when the count runs
  out, sortie_kill also counts any alien of that type still flying (not
  the one just hit) and, if the sortie's wave is still launching, those
  still to launch; the bonus waits for them.  fx_bing is now two quick
  rising beeps (D6, E6).
* **Logo letters (owner, 2026-11-20):** straight diagonals for the
  curves of S, R and A.  logo_font: the six letters as 9x15 bitmaps
  (rows drawn twice: 45-degree chamfers), expanded through lg_expand;
  the font magnification is gone (letters not in logo_font stay blank).
* **Boss fights with rapid fire (owner, 2026-11-20: slowdowns, worst at
  bosses 2-3).**  Measured with a firing, moving ship: bosses 2/3/4
  ran 22.5/18.2/12.3% of frames over budget, but 0% without firing.
  The cost was the sounds rapid fire plays constantly: every half-period
  is an interrupt (~64 cycles), and the zap (450), the hull's ping (480),
  explosions (noise 400-600) and the core's clang (noise 250) ran 2-4K
  cycles a frame.  Now zap 900, ping 900, boom 800/1100, clang 600/900:
  8.2/6.7/2.2% (boss 1 1.0%).  Escort caps didn't help (the firing ship
  keeps the escorts down) and are unchanged.  Rule: keep frequent sounds'
  half-periods long.  Check 5d (boss 2 with fire, limit 10%).
* **Fortress entrance slowdown (owner, 2026-11-20: shooting during the
  siren slowed boss 4's intro).**  11.1% of frames over with fire.  Two
  causes: (1) the flashing WARNING banner cleared its rows every frame
  of its off phase, and the Blorps change had made that 13 rows (~2.7K
  cycles a frame): now cleared once as it goes off, only the rows in use
  (5, or 13 with a second line), and redrawn every 4th frame while on;
  (2) the fortress's cores and envoys rode down with it over the status
  bar: they now appear when it arrives (fort_hide/fort_show).  Intro
  with fire: boss 2/3/4 0.7/0.7/0.0%.  Check 5e.  The hop check (2e)
  keeps its ship invulnerable (a lost ship wiped the field mid-sample).
* **Agreed plan, in order:**
  1. Done: memory pass.  spritec "shift S" compiles one shift and points
     every table entry at it (the game keeps x on that shift and never
     moves the sprite across).  Warp ship shipw1/2: shift 3, the arrival
     x (128-ship_W)/2 = 59 is on it (an assembly-time check guards that);
     warp_begin snaps x to it (x|3, minus 4 past SHIP_XMAX) after its
     erase.  Explosions boom1-4: shift 0; every explosion starts through
     boom_start (obj_anim_start, then x &= $FC, DX = 0: debris drifts
     only vertically).  Main $6000-$9B73 (was $A54C: -2521 bytes, ~4.7K
     free), low $0400-$14F2 (was $1E6B: -2425 bytes, ~2.8K free).
  2. A new hull for the area 2 boss (envoys + shielded core as now).
  3. More wrap-around waves in the areas.
  4. Later: bosses 3 and 4 distinct (smaller hulls, parts reuse, more
     engine tables to low memory); the owner designs them (mysteries).
* Then: more alien types / personalities, title screen polish, a name.
* Process: `make check` (18 tests) before every handover; named labels
  only in game.asm; realistic performance tests (sweep + rapid fire) vs
  the last build the owner liked.
