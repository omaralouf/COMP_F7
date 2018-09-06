;
; Lab.asm
;
; Created: 9/6/2018 1:52:00 PM
; Author : balabi
;



.include "m2560def.inc"
.def count = r16	; holds current number
.def i = r21
.def j = r18
.def k = r19
.def n = r20


.macro buff			; macro for buffering the button between presses
	clr i			; handles software bouncing 
	clr j
	clr k
	clr n
first_delay0: 
	clr j
	inc i
	cpi i, 100
	breq finish_delay0
second_delay0:
	clr k
	inc j
	cpi j, 50
	breq first_delay0
third_delay0:
	clr n
	inc k
	cpi k, 20
	breq second_delay0
fourth_delay0:
	cpi n, 8
	breq third_delay0
	nop
	inc n
	rjmp fourth_delay0
finish_delay0:
.endmacro

.cseg
.org 0x0

ldi r16, 0b1111		; stores current number
ser r17

out PORTC, count ; Write ones to all the LEDs
out DDRC, r17 ; PORTC is all outputs
out PORTD, r17 ; Enable pull-up resistors on PORTD
clr r17
out DDRD, r17 ; PORTD is all inputs

switch0:
	sbic PIND, 0 ; Skip the next instruction if PB0 is pushed
	rjmp switch1 ; If not pushed, check the other switch
	buff
	dec count	; decrement
	andi count, 0b1111; and to get only 4 bit representation 
	out PORTC, count

switch1:
	sbic PIND, 1 ; Skip the next instruction if PB1 is pushed
	rjmp switch0 ; If not pushed, check the other switch
	buff
	inc count ; Store count to the LEDs if the switch was pushed
	andi count, 0b1111
	out PORTC, count
	rjmp switch0 ; Now check PB0 again
