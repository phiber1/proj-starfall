# proj-starfall: StarFall, a vertical space shooter for the MC-10 (8K
# internal RAM mod + MCX32-SD required), built on mc10-game-engine (the
# engine/ git submodule: `git submodule update --init` after cloning).
#
#   make                 build the game, its boss overlays and the tools
#   make run             run the game in the emulator (also: make run-game;
#                        run-gamek: with the CPU meter)
#   make check           headless checks (needs the VMC10 for Linux emulator)
#   make run-sfx         the sound board: every game sound, up/down, SPACE
#   make run-logos       the title logo in several colour schemes
#   make run-view        a still display of a sprite file's sprites
#                        (VIEW=sprites/NAME.spr, default sprites/starfall.spr)
#   make DEBUG=0         release build: no debug-port writes, no LOAD timing
#   make docs            docs/starfall.pdf, the one-pager (headless Chromium;
#                        docs-img first retakes its screenshots, emulator)
#
# On the SD card the game is STARFALL.BIN (LOADM"STARFALL"), with its boss
# overlays SFBOSS1-4.BIN; it keeps its high score in STARFALL.HI there.

ENGINE  ?= engine
VMC10   ?= $(HOME)/vmc10-linux
EMU     ?= $(VMC10)/vmc10
DEBUG   ?= 1
CPPDEFS ?=
CC      ?= cc
CFLAGS  ?= -O2 -Wall -Wextra -std=c11

LOAD     := 6000
SEGMENTS := 0400-1FFF 6000-ADFF
CPPFLAGS := -E -P -w -x assembler-with-cpp -I$(ENGINE)/engine -Ibuild -Isrc -DDEBUG=$(DEBUG)
ENGSRC   := $(wildcard $(ENGINE)/engine/*.asm $(ENGINE)/engine/*.inc)
SRCINC   := $(wildcard src/*.inc)
SPRITES  := $(patsubst sprites/%.spr,build/%_spr.inc,$(wildcard sprites/*.spr))

# The bosses' hulls and envoys are overlays (src/ovl.inc): sprites/bossN.spr
# -> build/ovlN.bin at OVL_BASE, loaded by the game from SFBOSSN.BIN.
BOSSES   := 1 2 3 4
OVL_BINS := $(foreach n,$(BOSSES),build/ovl$(n).bin)
ENVOY_1  := envoy
ENVOY_2  := envoy2
ENVOY_3  := envoy3
ENVOY_4  := envoy4
OVL_BASE := $(shell awk '/^OVL_BASE/{print substr($$3,2)}' src/ovl.inc)
OVL_END  := $(shell awk '/^OVL_END/{print substr($$3,2)}' src/ovl.inc)

.SECONDEXPANSION:
all: build/starfall.bin $(OVL_BINS) build/sfx.bin build/logos.bin

build:
	mkdir -p build

# the engine's tools, built from the submodule
build/spritec: $(ENGINE)/tools/spritec.c | build
	$(CC) $(CFLAGS) -o $@ $<
build/p2decb: $(ENGINE)/tools/p2decb.c | build
	$(CC) $(CFLAGS) -o $@ $<

# compiled sprites (and only their constants, NAME_equ.inc, for the bosses)
build/%_spr.inc: sprites/%.spr build/spritec
	build/spritec $< > $@
build/%_equ.inc: sprites/%.spr build/spritec
	build/spritec -e $< > $@

# cpp handles #include/#define, then ASL assembles; p2decb writes the DECB
# binary, every byte checked to lie in the low or main segment
build/%.s: src/%.asm $(ENGSRC) $(SPRITES) $(SRCINC) | build
	$(CC) $(CPPFLAGS) $(CPPDEFS) $< -o $@
build/starfallk.s: src/starfall.asm $(ENGSRC) $(SPRITES) $(SRCINC) Makefile | build
	$(CC) $(CPPFLAGS) -DMETER=1 $(CPPDEFS) $< -o $@
build/starfall.s build/starfallk.s: $(foreach n,$(BOSSES),build/boss$(n)_equ.inc)
build/%.p: build/%.s
	cd build && asl -q -L -U $*.s
build/%.bin: build/%.p build/p2decb
	build/p2decb $< $@ $(LOAD) $(SEGMENTS)

# the boss overlays: the game's addresses they need, then each assembled at
# OVL_BASE and checked to fit OVL_BASE-OVL_END
build/syms.inc: build/starfall.p
	awk '/Symbol Table/{p=1} p' build/starfall.lst | tr '|' '\n' | \
	    awk '$$1=="spr_art" || $$1=="spr_mono" {printf "%s\tequ\t$$%s\n", $$1, $$3}' > $@
build/ovl%.s: src/ovl/boss.asm src/ovl.inc build/syms.inc build/boss%_spr.inc | build
	$(CC) $(CPPFLAGS) -DHULL=boss$* -DENVOY=$(ENVOY_$*) -DSPRINC='"boss$*_spr.inc"' $< -o $@
build/ovl%.bin: build/ovl%.p build/p2decb
	build/p2decb $< $@ $(OVL_BASE) $(OVL_BASE)-$(OVL_END)
overlays: $(OVL_BINS)

# The sprite viewer (the engine's): build/view_spr.inc and its drawing code
# come from $(VIEW), rebuilt every time (VIEW may change between runs)
VIEW    ?= sprites/starfall.spr
build/view_spr.inc: FORCE build/spritec | build
	build/spritec $(VIEW) > $@
build/view_list.inc: build/view_spr.inc $(ENGINE)/tools/sprview.py
	python3 $(ENGINE)/tools/sprview.py $(VIEW) build/view_spr.inc > $@
build/view.s: $(ENGINE)/bench/view.asm build/view_list.inc build/view_spr.inc $(ENGSRC) | build
	$(CC) $(CPPFLAGS) $(CPPDEFS) $< -o $@
FORCE:

# Run in the emulator: build/sd is the MCX32-SD's SD card.  The game goes
# on it as STARFALL.BIN with SFBOSS1-4.BIN (its high score file stays
# there); the other programs under their own names.
SD      := build/sd
run run-game: build/starfall.bin $(OVL_BINS)
	$(MAKE) --no-print-directory sdrun PROG=starfall NAME=STARFALL
run-gamek: build/starfallk.bin $(OVL_BINS)
	$(MAKE) --no-print-directory sdrun PROG=starfallk NAME=STARFALL
run-%: build/%.bin
	$(MAKE) --no-print-directory sdrun PROG=$* NAME=$(shell echo $* | tr a-z A-Z)
sdrun:
	mkdir -p $(SD)
	cp build/$(PROG).bin $(SD)/$(NAME).BIN
	$(if $(filter STARFALL,$(NAME)),for n in $(BOSSES); do cp build/ovl$$n.bin $(SD)/SFBOSS$$n.BIN; done)
	$(EMU) --mcx32sd --8k --sd $(SD) --type 'LOADM"$(NAME)"\nEXEC\n'

# Headless checks (needs the emulator's harness and ROMs: VMC10=...)
check: build/starfall.bin $(OVL_BINS)
	VMC10=$(VMC10) sh tests/check.sh

# The one-pager: docs/onepager.html -> docs/starfall.pdf.  Its pictures
# (docs/img, kept in the repository) come from the headless emulator.
CHROME  ?= chromium
docs: docs/starfall.pdf
docs/starfall.pdf: docs/onepager.html $(wildcard docs/img/*.png)
	$(CHROME) --headless --disable-gpu --no-pdf-header-footer --print-to-pdf=$@ $<
docs-img: build/starfall.bin $(OVL_BINS)
	sh tools/shots.sh build/shots
	python3 tools/docimg.py build/shots

clean:
	rm -rf build

.PHONY: all clean check docs docs-img overlays run run-game run-gamek sdrun FORCE
.PRECIOUS: build/%.s build/%.p build/%_spr.inc build/%_equ.inc build/%.bin
