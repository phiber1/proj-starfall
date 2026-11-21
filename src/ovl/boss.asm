; boss.asm: one boss overlay for src/starfall.asm: its hull and envoy
; sprites at OVL_BASE, behind a header the game reads (the descriptors,
; then 0: the game also hands it to col_swap).  Built by the Makefile
; for each boss: -DHULL=boss1 -DENVOY=envoy -DSPRINC='"boss1_spr.inc"'.
; syms.inc gives the game's spr_art / spr_mono (the descriptors
; name them).

#include "layout.inc"
#include "ovl.inc"
#include "syms.inc"

#define CAT(a, b) a##b
#define DSC(n) CAT(n, _dsc)

                org     OVL_BASE
                fdb     DSC(HULL), DSC(ENVOY), 0
#include SPRINC
                if      * > OVL_END+1
                error   "this boss doesn't fit in the overlay area (OVL_BASE-OVL_END)"
                endif
