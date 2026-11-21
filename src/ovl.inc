; ovl.inc: where src/starfall.asm keeps the current boss.  The bosses'
; hull and envoy sprites (sprites/bossN.spr) are overlays: each is
; assembled at OVL_BASE into build/ovlN.bin, copied to the SD card as
; SFBOSSN.BIN, and loaded by the game (LOADM through the MCX32-SD BIOS)
; during the map screen of the area that needs it.  Only one boss is in
; memory at a time.  An overlay starts with a header: fdb hull_dsc,
; envoy_dsc, 0 (also a color-swap list).  The Makefile reads these two
; lines too.
OVL_BASE        equ     $A200
OVL_END         equ     $ADFF
