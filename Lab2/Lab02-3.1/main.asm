; Lab2A.asm
; Author : Omar Al-Ouf
; Email: o.al-ouf@unsw.edu.au

.include "m2560def.inc"

.cseg

ldi r25,low(64501)	; dividend (according to specs)
mov r15,r25
clr r25
ldi r16,high(64501) 
ldi r17,low(6000)	; divisor
ldi r18,high(6000)
ldi r19,0			; quotient
ldi r20,0
clr r21
clr r22
ldi r23,1			; bit_position (low and high)
ldi r24,0

while1:
	cp r15,r17
	cpc r16,r18
	brlo while2		; if the dividend is lower than or equal to the divisor (basically skips first while)
	breq while2

	;mov r21,r17
	mov r22,r18

	; avoid overflow
	//ldi r21,high(0x8000)
	//andi r22,high(0x8000)	; purely checking the highest bit in the high byte
	//cp r22, r21
	sbrc r22,7
	//breq while2	; if 0 is lower than r22
	rjmp while2	; rjmp since no compare

	; shift one bit left
	lsl r17
	rol r18

	lsl r23
	rol r24

	rjmp while1

while2:
	cp r23,r7
	cpc r24,r7
	brlo end
	breq end		; only continue if bit_position is > 0

	cp r15,r17
	cpc r16,r18
	brlo shiftback	; if dividend is lower than divisor, skip this part

	; dividend = dividend - divisor
	sub r15,r17
	sbc r16,r18

	; quotient = quotient + bit_position
	add r19,r23
	adc r20,r24

shiftback:
	; shift one bit right
	lsr r18
	ror r17

	lsr r24
	ror r23

	rjmp while2

end:
	rjmp end
