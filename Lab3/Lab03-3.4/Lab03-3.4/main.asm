;
; Lab03-3.4.asm
;
; Created: 9/11/2018 4:07:37 PM
; Author : balabi
;


.include "m2560def.inc"
.def i = r18
.def j = r19
.def k = r20
.def n = r21


.macro delay	; macro for 1 second delay
	clr i
	clr j
	clr k
	clr n 
loop_1: 
	clr j
	inc i 
	cpi i, 100
	breq finish_delay
loop_2:
	clr k
	inc j
	cpi j, 100
	breq loop_1
loop_3:
	clr n
	inc k
	cpi k, 100
	breq loop_2
loop_4:
	cpi n, 16
	breq loop_3
	nop
	inc n
	rjmp loop_4
finish_delay:
.endmacro
.cseg 
.org 0x100

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


	

	 


