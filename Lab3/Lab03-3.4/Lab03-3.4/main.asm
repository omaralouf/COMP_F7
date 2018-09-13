;
; Lab03-3.4.asm
;
; Created: 9/11/2018 4:07:37 PM
; Author : balabi
;


.include "m2560def.inc"
.def byte_0 = r18
.def byte_1 = r19
.def byte_2= r20
.def zero = r21


.macro delay
	ldi byte_0, low(999999) ;1 cycle
	ldi byte_1, high(999999) ;1 cycle
	ldi byte_2, byte3(999999) ;1 cycle
	clr zero ;1 cycle
oneus: 
	nop ;1 cycle
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	subi byte_0, 1 ;1 cycle
	sbc byte_1, zero ;1 cycle
	sbc byte_2, zero ;1 cycle
	brne oneus ;2 cycles except the last execution which takes 1 cycle 
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
.endmacro

.cseg 
.org 0x0

clr r16
ser r17

out PORTC, r16	; start with no LEDs lit 
out DDRC, r17	; Port C is all outputs
ldi r17, 0b01000000

sec_loop:
	delay
	inc r16
	mov r22, r16
	andi r22, 0b00111111
	cpi r22, 61
	brsh add_min
LED_out: 
	out PORTC, r16	; write out to LEDs
	rjmp sec_loop

add_min:
	add r16, r17
	andi r16, 0b11000000
	rjmp LED_out


	

	 


