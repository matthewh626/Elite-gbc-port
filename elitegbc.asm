INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]

	jp EntryPoint;

	ds $150 - @, 0

SECTION "init", ROM0
EntryPoint:
ld hl, rIE
ld [hl], %00000001 
halt
nop
ld hl, rLCDC
ld [hl], %01101000
ld hl, rSPD
set 0, [hl]
halt
ld hl, _SCRN0 ;initalsing BG tilemap 
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
ld hl, _HRAM
: ld a, 0
ld [hl+], a
ld a, l
cp a, $fe
jr !z, :-
ld hl, rBGPI ;initalising the pallet
ld [hl], %10000000
ld hl, rBGPD
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
ld [hl], 2
inc hl
ld [hl], 6
inc hl
ld [hl], 10 ;points loaded
ld hl, $C000
call DrawLine
ld hl, rHDMA1
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
ld hl, rLCDC
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

SECTION "rendering vars", HRAM
x0:: db
y0:: db
x1:: db
y1:: db
dx:: dw
dy:: dw
Dif:: dw

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
.angled  	;this uses the vars from the rendering vars section and b&c for x&y
ld a, [hld] 	;at this point its loading the values from the input area in memory into the linedrawing working memory ($FF80 - $FF89)
ldh [y1], a 	;because hl is left pointing to the last value of the input after the previous checks the values are loaded last to first
ld a, [hld]
ldh [x1], a
ld a, [hld]
ldh [y0], a
ld a, [hl]
ldh [x0], a
ld a, [hl]
ldh [x0], a ;points loaded into render mem
ldh a, [x1]
ld b, a
ldh a, [x0]
sub b
jr !c, :+
call TwosCompA
: ld b, a ;b = abs(x1 - x0)
ldh a, [y1]
ld c, a
ldh a, [y0]
sub c
jr !c, :+
call TwosCompA
: ld c, a ;c = abs(y1 - y0)
ld a, b
sub c ;the C flag now contain abs(y1 - y0) < abs(x1 - x0)
jp c, .steep 

.shallow:
ldh a, [y1]
ld hl, y0
cp a, [hl] 
jp !c, .shallowpos

.shallowneg
ldh a, [x1] 
ld b, 0
ld c, a
ldh a, [x0]
ld h, 0
ld l, a
call TwosCompHL
add hl, bc
ld a, l
ldh [dx], a
ld a, h
ldh [dx+1], a ; dx = x1 - x0
ldh a, [y1] 
ld b, 0
ld c, a
ldh a, [y0]
ld h, 0
ld l, a
call TwosCompHL
add hl, bc
call TwosCompHL
ld a, l
ldh [dy], a
ld a, h
ldh [dy+1], a ; dy = y1 - y0
ld b, h
ld c, l
add hl, bc ; hl = 2*dy
ld b, h
ld c, l
ldh a, [dx]
ld l, a
ldh a, [dx+1]
ld h, a
call TwosCompHL ; hl = -dx, bc = 2*dy
add hl, bc
ld a, l
ldh [Dif], a
ld a, h
ldh [Dif+1], a ; Dif = 2*dy - dx
ldh a, [y0]
ld c, a ; y = y0
ldh a, [x0]
ld b, a ; x = x0, finaly ready for loop
: push bc ; start of loop
call DrawPixel
pop bc
ldh a, [Dif+1] ; start of if block 
cpl
bit 7, a
jr z, :+
ldh a, [Dif]
ld hl, Dif+1
or a, [hl]
jr z, :+ ; first jump is branching on Dif < 0 second is branching on Dif = 0, if neather are taken then Dif > 0. end of if block check
dec c ; y = y - 1
ldh a, [dx]
ld l, a
ldh a, [dx+1]
ld h, a
ld d, h
ld e, l
add hl, de
call TwosCompHL
ldh a, [Dif]
ld e, a
ldh a, [Dif+1]
ld d, a
add hl, de ; hl = Dif - 2*dx 
ld a, l
ldh [Dif], a
ld a, h
ldh [Dif+1], a; *now* Dif = Dif - 2*dx
jr :++
: ; end of if block 
ldh a, [dy]
ld l, a
ldh a, [dy+1]
ld h, a
ld d, h
ld e, l
add hl, de ;hl = 2*dy
ldh a, [Dif]
ld e, a
ldh a, [Dif+1]
ld d, a
add hl, de ; hl = Dif + 2*dy
ld a, l
ldh [Dif], a
ld a, h
ldh [Dif+1], a; *now* Dif = Dif + 2*dy
:
inc b
ldh a, [x1]
cp a, b
jr !c, :---
RET

.shallowpos
ldh a, [x1] 
ld b, 0
ld c, a
ldh a, [x0]
ld h, 0
ld l, a
call TwosCompHL
add hl, bc
ld a, l
ldh [dx], a
ld a, h
ldh [dx+1], a ; dx = x1 - x0
ldh a, [y1] 
ld b, 0
ld c, a
ldh a, [y0]
ld h, 0
ld l, a
call TwosCompHL
add hl, bc
ld a, l
ldh [dy], a
ld a, h
ldh [dy+1], a ; dy = y1 - y0
ld b, h
ld c, l
add hl, bc ; hl = 2*dy
ld b, h
ld c, l
ldh a, [dx]
ld l, a
ldh a, [dx+1]
ld h, a
call TwosCompHL ; hl = -dx, bc = 2*dy
add hl, bc
ld a, l
ldh [Dif], a
ld a, h
ldh [Dif+1], a ; Dif = 2*dy - dx
ldh a, [y0]
ld c, a ; y = y0
ldh a, [x0]
ld b, a ; x = x0, finaly ready for loop
: push bc ; start of loop
call DrawPixel
pop bc
ldh a, [Dif+1] ; start of if block 
cpl
bit 7, a
jr z, :+
ldh a, [Dif]
ld hl, Dif+1
or a, [hl]
jr z, :+ ; first jump is branching on Dif < 0 second is branching on Dif = 0, if neather are taken then Dif > 0. end of if block check
inc c ; y = y + 1
ldh a, [dx]
ld l, a
ldh a, [dx+1]
ld h, a
ld d, h
ld e, l
add hl, de
call TwosCompHL
ldh a, [Dif]
ld e, a
ldh a, [Dif+1]
ld d, a
add hl, de ; hl = Dif - 2*dx 
ld a, l
ldh [Dif], a
ld a, h
ldh [Dif+1], a; *now* Dif = Dif - 2*dx
jr :++
: ; end of if block 
ldh a, [dy]
ld l, a
ldh a, [dy+1]
ld h, a
ld d, h
ld e, l
add hl, de ;hl = 2*dy
ldh a, [Dif]
ld e, a
ldh a, [Dif+1]
ld d, a
add hl, de ; hl = Dif + 2*dy
ld a, l
ldh [Dif], a
ld a, h
ldh [Dif+1], a; *now* Dif = Dif + 2*dy
:
inc b
ldh a, [x1]
cp a, b
jr !c, :---
RET

.steep:
ldh a, [x0]
ld hl, x1
cp a, [hl] 
jp c, .steeppos

.steepneg
ldh a, [y1] 
ld b, 0
ld c, a
ldh a, [y0]
ld h, 0
ld l, a
call TwosCompHL
add hl, bc
ld a, l
ldh [dy], a
ld a, h
ldh [dy+1], a ; dy = y1 - y0
ldh a, [x1] 
ld b, 0
ld c, a
ldh a, [x0]
ld h, 0
ld l, a
call TwosCompHL
add hl, bc
call TwosCompHL
ld a, l
ldh [dx], a
ld a, h
ldh [dx+1], a ; dx = x1 - x0
ld b, h
ld c, l
add hl, bc ; hl = 2*dx
ld b, h
ld c, l
ldh a, [dy]
ld l, a
ldh a, [dy+1]
ld h, a
call TwosCompHL ; hl = -dy, bc = 2*dx
add hl, bc
ld a, l
ldh [Dif], a
ld a, h
ldh [Dif+1], a ; Dif = 2*dx - dy
ldh a, [y0]
ld c, a ; y = y0
ldh a, [x0]
ld b, a ; x = x0, finaly ready for loop
: push bc ; start of loop
call DrawPixel
pop bc
ldh a, [Dif+1] ; start of if block 
cpl
bit 7, a
jr z, :+
ldh a, [Dif]
cp a, 0
jr z, :+ ; first jump is branching on Dif < 0 second is branching on Dif = 0, if neather are taken then Dif > 0. end of if block check
dec b ; x = x - 1
ldh a, [dx]
ld l, a
ldh a, [dx+1]
ld h, a
ld d, h
ld e, l
ldh a, [dy]
ld l, a
ldh a, [dy+1]
ld h, a
call TwosCompHL
add hl, de ; hl = dx - dy
ld d, h
ld e, l
add hl, de ; hl = 2(dx-dy)
ldh a, [Dif]
ld e, a
ldh a, [Dif+1]
ld d, a
add hl, de 
ld a, l
ldh [Dif], a
ld a, h
ldh [Dif+1], a ; Dif = Dif + 2(dx-dy)
jr :++
: ; end of if block 
ldh a, [dx]
ld l, a
ldh a, [dx+1]
ld h, a
ld d, h
ld e, l
add hl, de
ldh a, [Dif]
ld e, a
ldh a, [Dif+1]
ld d, a
add hl, de 
ld a, l
ldh [Dif], a
ld a, h
ldh [Dif+1], a ; Dif = Dif + 2*dx
:inc c
ldh a, [y1]
cp a, c
jr !c, :---
RET

.steeppos
ldh a, [y1] 
ld b, 0
ld c, a
ldh a, [y0]
ld h, 0
ld l, a
call TwosCompHL
add hl, bc
ld a, l
ldh [dy], a
ld a, h
ldh [dy+1], a ; dy = y1 - y0
ldh a, [x1] 
ld b, 0
ld c, a
ldh a, [x0]
ld h, 0
ld l, a
call TwosCompHL
add hl, bc
ld a, l
ldh [dx], a
ld a, h
ldh [dx+1], a ; dx = x1 - x0
ld b, h
ld c, l
add hl, bc ; hl = 2*dx
ld b, h
ld c, l
ldh a, [dy]
ld l, a
ldh a, [dy+1]
ld h, a
call TwosCompHL ; hl = -dy, bc = 2*dx
add hl, bc
ld a, l
ldh [Dif], a
ld a, h
ldh [Dif+1], a ; Dif = 2*dx - dy
ldh a, [y0]
ld c, a ; y = y0
ldh a, [x0]
ld b, a ; x = x0, finaly ready for loop
: push bc ; start of loop
call DrawPixel
pop bc
ldh a, [Dif+1] ; start of if block 
cpl
bit 7, a
jr z, :+
ldh a, [Dif]
cp a, 0
jr z, :+ ; first jump is branching on Dif < 0 second is branching on Dif = 0, if neather are taken then Dif > 0. end of if block check
inc b ; x = x + 1
ldh a, [dx]
ld l, a
ldh a, [dx+1]
ld h, a
ld d, h
ld e, l
ldh a, [dy]
ld l, a
ldh a, [dy+1]
ld h, a
call TwosCompHL
add hl, de ; hl = dx - dy
ld d, h
ld e, l
add hl, de ; hl = 2(dx-dy)
ldh a, [Dif]
ld e, a
ldh a, [Dif+1]
ld d, a
add hl, de 
ld a, l
ldh [Dif], a
ld a, h
ldh [Dif+1], a ; Dif = Dif + 2(dx-dy)
jr :++
: ; end of if block 
ldh a, [dx]
ld l, a
ldh a, [dx+1]
ld h, a
ld d, h
ld e, l
add hl, de
ldh a, [Dif]
ld e, a
ldh a, [Dif+1]
ld d, a
add hl, de 
ld a, l
ldh [Dif], a
ld a, h
ldh [Dif+1], a ; Dif = Dif + 2*dx
:inc c
ldh a, [y1]
cp a, c
jr !c, :---
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
