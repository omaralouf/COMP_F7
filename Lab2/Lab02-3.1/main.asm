; Lab2A.asm
; Author : Omar Al-Ouf
; Email: o.al-ouf@unsw.edu.au

.include "m2560def.inc"

.cseg

ldi r25,low(3217)	; dividend (according to specs)
mov r15,r25
clr r25
ldi r16,high(3217) 
ldi r17,low(16)		; divisor
ldi r18,high(16)
ldi r19,0			; quotient
ldi r20,0
ldi r23,1			; bit_position (low and high)
ldi r24,0

while1:
	cp r15,r17
	cpc r16,r18
	brlo while2 ; if the dividend is lower than or equal to the divisor (basically skips first while)
	breq while2

	mov r21,r17
	mov r22,r18

	; avoid overflow
	andi r21,low(0x8000)
	andi r22,high(0x8000)
	add  r21,r22
	cpi r21,0
	brlo while2

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
