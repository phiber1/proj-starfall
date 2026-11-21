# StarFall

A vertical space shooter for the TRS-80 MC-10, in NTSC artifact color.
Four areas of alien waves, each ending in a boss, the last of them the
space fortress; extra ships, sortie bonuses, rounds that get harder, and a
high score kept on the SD card.  Built on
[mc10-game-engine](https://github.com/phiber1/mc10-game-engine).

**Needs:** an MC-10 with the 8K internal RAM mod and an MCX32-SD (or the
[VMC10 for Linux](https://github.com/phiber1/vmc10-linux) emulator with
`--8k --mcx32sd`).

## Playing

Copy `STARFALL.BIN` and `SFBOSS1.BIN` .. `SFBOSS4.BIN` to the SD card and
type `RUNM"STARFALL"`.  The game keeps its high score in
`STARFALL.HI` on the card.  Arrows (W A S Z) move, SPACE fires; a
PI-KEY10's joystick 1 works as it is.

## Building

    git clone --recurse-submodules https://github.com/phiber1/proj-starfall.git
    cd proj-starfall
    make            # build/starfall.bin (STARFALL.BIN) and build/ovl1-4.bin (SFBOSS1-4.BIN)
    make run        # in the emulator (VMC10=path to vmc10-linux, default ~/vmc10-linux)
    make check      # headless checks
    make DEBUG=0    # release build

Needs `asl` (the Macroassembler AS), a C compiler, cpp and Python 3.
`docs/starfall.pdf` is a one-pager on the game (`make docs` renders it
from `docs/onepager.html` with headless Chromium; `make docs-img` retakes
its screenshots).  Also: `make run-sfx` (the sound board), `make run-logos` (logo color
schemes), `make run-view VIEW=sprites/NAME.spr` (a sprite file's sprites).
See `NOTES.md` for the design history.

## Licence

Public domain (Unlicense): see `LICENSE`.
