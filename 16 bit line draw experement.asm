TwosCompHL: ;uses hl and a
ld a, $FF
xor l
ld l, a
ld a, $FF
xor h
ld h, a
inc hl
RET

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
ld a, [hld] 	;at this point its loading the values from the input area in memory into the linedrawing working memory ($FF00 - $FF09)
ldh [$FF03], a 	;because hl is left pointing to the last value of the input after the previous checks the values are loaded last to first
ld a, [hld]
ldh [$FF02], a
ld a, [hld]
ldh [$FF01], a
ld a, [hl]
ldh [$FF00], a
ld a, [hl]
ldh [$FF00], a
ldh a, [$FF02]
ld b, a
ldh a, [$FF00]
sub b
ld b, a
ldh a, [$FF03]
ld c, a
ldh a, [$FF01]
sub c
sub b ;the C flag now contain abs(y1 - y0) < abs(x1 - x0)
jr c, shallow
jr steep
.shallow:
ldh a, [$FF02]
ld hl, $FF00
cp a, [hl] 
jr c, :+

:
.shallowpos
ldh a, [$FF02]
ld h, 0
ld l, a
call TwosCompHL
ld b, h
ld c, l
ldh a, [$FF00]
ld h, 0
ld l, a
add hl, bc
ld a, h
ldh [$FF04], a
ld a, l
ldh [$FF05], a ;all this from the shallowpos label to do xd = x1 - x0
ldh a, [$FF03]
ld h, 0
ld l, a
call TwosCompHL
ld b, h
ld c, l
ldh a, [$FF01]
ld h, 0
ld l, a
add hl, bc
ld a, h
ldh [$FF06], a
ld a, l
ldh [$FF07], a ;dy = y1 - y0
add hl, hl
ld b, h
ld c, l
ldh a, [$FF04]
ld h, a
ldh a, [$FF05]
ld l, a
call TwosCompHL
add hl, bc