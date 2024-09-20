INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]

	jp EntryPoint

	ds $150 - @, 0

SECTION "init", ROM0
EntryPoint:
ld hl, $ffff 
ld [hl], %00000001 
halt
nop
ld hl, $FF40
ld [hl], %00000000
ld hl, $9800 ;initalsing BG tilemap 
ld b, 0
ld d, 12
.a
ld e, 18
.b
ld [hl], b
inc hl
inc b
dec e
jr !z, .b
dec d
ld a, $20
call AddtoHl
jr !z, .a ;the BG tile map should now have a 18x12 area where each position uses subsequent tile ids
ld hl, $ff68 ;initalising the pallet
ld [hl], %10000000
ld hl, $ff69
ld [hl], $1f
ld [hl], $00
ld [hl], $e0
ld [hl], $03
ld [hl], $00
ld [hl], $7c
ld [hl], $00
ld [hl], $00 ;first 4 colours of the pallet should now be red, green, blue and white
ld hl, $C000 ;loading the 2 test points
ld [hl], 48
inc hl
ld [hl], 57
inc hl
ld [hl], 137
inc hl
ld [hl], 4 ;points loaded
jp End

SECTION "utils", ROM0

AddtoHl: ;takes input with a regester
add l
ld l, a
adc h
sub l
ld h, a
RET

SECTION "rendering", ROM0

DrawLine: ;takes input with hl, will try to read one endpoint pair from memory
ld a, [hl]
inc l
inc l
cp a, [hl]
jr z, .horisontal
dec l
ld a, [hl]
inc l
inc l
cp a, [hl]
jr z, .vertical
jr .angled
.horisontal
dec l
ld a, [hl]
inc l
inc l
cp a, [hl]
jr !z, .horLend
dec l
dec l
ld c, [hl]
dec l
ld b, [hl]
call DrawPixel
.horLend
RET

.vertical

.angled

RET

DrawPixel: ;takes input with b and c regesters
ld d, b
ld e, c
rr d
rr d
rr d
rr e
rr e
rr e
ld a, b
and a, %00000111
ld b, a
ld a, c
and a, %00000111
ld c, a ;b and c are now the sub-tile co-ords and d and e are the tile co-ords
ld a, d
.loop
dec e
jr z, .tileid
jr c, .tileid
add a, 12
jr .loop
.tileid ;a is now the tile id
rl a
rl a
rl a ;a is now the starting address offset of the tile
add a, c
ld d, a ;d is now the address offset of the byte the pixel will go to, and e & c are now free
ld hl, $C011
call AddtoHl
ld a, b
call MaskGen
xor a, [hl]
ld [hl], a
RET

MaskGen: ;this code is by calc84maniac, big thanks to them (input and output are in a)
sub 4 ; Check if in high or low nibble
	jr nc, .highNibble
	; 0 → $01, 1 → $02, 2 → $04, 3 → $05
	; Overall, these two instructions add 5 to the number (to which 4 was subtracted above)
	; However, the first instruction will generate a carry for inputs of $FE and $FF
	; (which were 2 and 3 before `sub 4`); the `adc` will pick the carry up, and "separate"
	; 0 / 1 from 2 / 3 by an extra 1. Luckily, this yields correct results for 0 ($01),
	; 1 ($02), and 2 ($03 + 1 = $04). We'll see about fixing 3 after the jump.
	add a, 2
	adc a, 3
	jr .fixThree
.highNibble
	; 4 → $10, 5 → $20, 6 → $40, 7 → $50
	; This is basically the same as the above, except that we need a different initial
	; offset to generate a carry as needed.
	add a, -2
	adc a, 3
	swap a ; Switch to the high nibble, though
.fixThree
	; At this point, both inputs are identical, ignoring the nibble swapping.
	; I will describe the process for the low nibble, but it works similarly for the high one.
	; After being shifted left, the inputs are $02, $04, $08 and $0A; all are valid BCD,
	; except for $0A. Since we just performed `add a, a`, DAA will correct the latter to $10.
	; (This should be correctly emulated everywhere, since the inputs are identical to
	; "regular" BCD.)
	; When placing the results back, we'll thus get $01, $02, $04 and $08!
	add a, a
	daa
	rra ; Note that we need this specific rotate, since $A0 gets corrected to $00 with carry set
	RET

GetFreeTile:
RET

TileManager:
RET

FrameHandler:
RET

End:
ld hl, $ffff 
ld [hl], %00000000 
halt