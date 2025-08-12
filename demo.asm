INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]

	jp EntryPoint;

	ds $150 - @, 0

SECTION "init", ROM0
EntryPoint:
ld hl, $ffff 
ld [hl], %00000001 
halt
nop
ld hl, $FF40
ld [hl], %01101000
ld hl, $ff4d
set 0, [hl]
stop
ld hl, $97f2 ;initalsing BG tilemap 
ld b, 0
ld d, 12
: ld e, 18
ld a, 14
call AddtoHl
: ld [hl], b
inc hl
inc b
dec e
jr !z, :-
dec d
jr !z, :-- ;the BG tile map should now have a 18x12 area where each position uses subsequent tile ids
ld hl, $c000; cleaning up some ram just for development (so i can fucking see whats happening)
: ld a, 0
ld [hl+], a
ld a, h
cp a, $d0
jr !z, :-
ld hl, $ff80
: ld a, 0
ld [hl+], a
ld a, l
cp a, $fe
jr !z, :-
ld hl, $ff68 ;initalising the pallet
ld [hl], %10000000
ld hl, $ff69
ld [hl], $00
ld [hl], $00
ld [hl], $0c
ld [hl], $07
ld [hl], $00
ld [hl], $00
ld [hl], $00
ld [hl], $00 ;end of first pallet 
ld [hl], $00
ld [hl], $00
ld [hl], $00
ld [hl], $00
ld [hl], $0c
ld [hl], $07
ld [hl], $00
ld [hl], $00  ;pallets should be initalised, a buffer will use the first and the b pallet will use the second
ld hl, $C000 ;loading the 2 test points
ld [hl], 0
inc hl
ld [hl], 4
inc hl
ld [hl], 8
inc hl
ld [hl], 4 ;points loaded
ld hl, $C000
call DrawLine
ld hl, $ff51
ld [hl], $c0
inc hl
ld [hl], $20
inc hl
ld [hl], $80
inc hl
ld [hl], $00
inc hl
ld [hl], $8f
nop
ld hl, $FF40
set 7, [hl]
jp End

SECTION "utils", ROM0

AddtoHl: ;takes input with a regester
add l
ld l, a
adc h
sub l
ld h, a
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

;code copied from the 16 bit linedrawing test
TwosCompHL: ;uses hl and a
ld a, $FF
xor l
ld l, a
ld a, $FF
xor h
ld h, a
inc hl
RET

TwosCompA: ;uses just a
cpl
inc a
RET

SECTION "rendering", ROM0

DrawLine: ;takes input with hl (which should point to the first of 2 points repesented by 2 bytes each), will try to read one endpoint pair from memory
ld a, [hl] ;hl points to x1
inc hl
inc hl
cp a, [hl] ;hl points to x2
jr z, .vertical ;this code handles both vertical lines and single points (where x1=x2 and y1=y2)
dec hl
ld a, [hl] ;hl points to y1
inc hl
inc hl
cp a, [hl] ;hl points to y2
jr z, .horisontal
jr .angled
.vertical
dec hl
ld c, [hl] ;hl points to y1
dec hl
ld b, [hl] ;hl points to x1
inc hl
inc hl
ld d,[hl] ;hl points to x2
inc hl
ld e,[hl] ;hl points to y2
: PUSH bc
PUSH de
call DrawPixel
POP de
POP bc
ld a, c
cp a, e
jr z, :++
jr c, :+
dec c
jr :-
: inc c
jr :--
: RET
.horisontal
ld e, [hl] ;hl points to y2
dec hl
ld d, [hl] ;hl points to x2
dec hl
ld c, [hl] ;hl points to y1
dec hl
ld b, [hl] ;hl points to x1
: PUSH bc
PUSH de
call DrawPixel
POP de
POP bc
ld a, b
cp a, d
jr z, :++
jr c, :+
dec b
jr :-
: inc b
jr :--
: RET
.angled  	;memory addresses (the screen cords are unsigned 8 bit, calcualtion vars are little endian signed 16 bit)
		; b=x c=y $FF00=x0 $FF01=y0 $FF02=x1 $FF03=y1 $FF04-5=dx $FF06-7=dy $FF08-9=D
ld a, [hld] 	;at this point its loading the values from the input area in memory into the linedrawing working memory ($FF80 - $FF89)
ldh [$FF83], a 	;because hl is left pointing to the last value of the input after the previous checks the values are loaded last to first
ld a, [hld]
ldh [$FF82], a
ld a, [hld]
ldh [$FF81], a
ld a, [hl]
ldh [$FF80], a
ld a, [hl]
ldh [$FF80], a
ldh a, [$FF82]
ld b, a
ldh a, [$FF80]
sub b
ld b, a
ldh a, [$FF83]
ld c, a
ldh a, [$FF81]
sub c
sub b ;the C flag now contain abs(y1 - y0) < abs(x1 - x0)
jr c, .shallow

.shallow:
ldh a, [$FF82]
ld hl, $FF80
cp a, [hl] 
jr c, .shallowpos
.shallowneg
RET

.shallowpos
ldh a, [$ff82] 
ld b, 0
ld c, a
ldh a, [$ff80]
ld h, 0
ld l, a
call TwosCompHL
add hl, bc
ld a, h
ldh [$ff84], a
ld a, l
ldh [$ff85], a ; dx = x1 - x0
ldh a, [$ff83] 
ld b, 0
ld c, a
ldh a, [$ff81]
ld h, 0
ld l, a
call TwosCompHL
add hl, bc
ld a, h
ldh [$ff86], a
ld a, l
ldh [$ff87], a ; dy = y1 - y0
ld b, h
ld c, l
add hl, bc ; hl = 2*dy
ld b, h
ld c, l
ldh a, [$ff84]
ld h, a
ldh a, [$ff85]
ld l, a
call TwosCompHL ; hl = -dx, bc = 2*dy
add hl, bc
ld a, h
ldh [$ff88], a
ld a, l
ldh [$ff89], a ; D = 2*dy - dx
ldh a, [$ff81]
ld c, a ; y = y0
ldh a, [$ff80]
ld b, a ; x = x0, finaly ready for loop
: push bc ; start of loop
call DrawPixel
pop bc
ldh a, [$ff88] ; start of if block 
bit 7, a
jr z, :+
ldh a, [$ff89]
cp a, 0
jr z, :+ ; first jump is branching on D < 0 second is branching on D = 0, if neather are taken then D > 0. end of if block check
inc c ; y = y + 1
ldh a, [$ff84]
ld h, a
ldh a, [$ff85]
ld l, a
ld d, h
ld e, l
add hl, de
call TwosCompHL
ldh a, [$ff88]
ld d, a
ldh a, [$ff89]
ld e, a
add hl, de ; D = D - 2*dx
: ; end of if block 
ldh a, [$ff86]
ld h, a
ldh a, [$ff57]
ld l, a
ld d, h
ld e, l
add hl, de
ldh a, [$ff88]
ld d, a
ldh a, [$ff89]
ld e, a
add hl, de ; D = D + 2*dy
inc b
ldh a, [$ff82]
cp a, b
jr !c, :--
RET

DrawPixel: ;takes input with b and c regesters
ld d, b
ld e, c
srl d
srl d
srl d
srl e
srl e
srl e
ld a, b
and a, %00000111
ld b, a
ld a, c
and a, %00000111
ld c, a ;b and c are now the sub-tile co-ords and d and e are the tile co-ords
ld a, d
cp a, 0
jr z, .tileid
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
rl d
ld hl, $C020
call AddtoHl
ld a, b
call MaskGen
xor a, [hl]
ld [hl], a
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
