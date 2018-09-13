; Lab3B.asm
; Author : Omar Al-Ouf
; Email: o.al-ouf@unsw.edu.au

.include "m2560def.inc" 
.def temp = r16
.def i = r17
.def j = r18
.def k = r19
.def n = r20

;.equ F_CPU = 16000000
;.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead


.macro buff		
clr i;
clr j;
clr k;
clr n;	

first_delay0: 
	clr j;
	inc i; 
	cpi i, 100;
	breq finish_delay0
second_delay0:
	clr k;
	inc j;
	cpi j, 100;
	breq first_delay0;
third_delay0:
	clr n;
	inc k;
	cpi k, 50;
	breq second_delay0
fourth_delay0:
	cpi n, 8;
	breq third_delay0
	nop;
	inc n;
	rjmp fourth_delay0;
finish_delay0:
	clr i;
	clr j;
	clr k;
	clr n;
.endmacro

.cseg 
.org 0x00 
jmp RESET 
.org INT0addr    ; INT0addr is the address of EXT_INT0  
jmp EXT_INT0 
.org INT1addr    ; INT1addr is the address of EXT_INT1 
jmp EXT_INT1 
 
RESET: 
	ldi temp, low(RAMEND) ; Let the stack pointer point to the starting address
	out SPL, temp 
	ldi temp, high(RAMEND) 
	out SPH, temp
 
	ser temp 
	ldi temp, 0b1111
	out DDRC, temp	; Set Port C as the output
	clr temp
	out PORTC, temp ; Write zeroes to LEDs 6-9
	out PORTD, temp ; Write zeroes to PB0 and PB1
 
	out DDRD, temp	; PB0 and PB1 are the inputs

	ldi temp, (1 << ISC01) | (1 << ISC11)	; Set the falling edge mode
	sts EICRA, temp ; temp = 0b00000010; First 4 are nothing, next 2 are for EICRB Store it into EICRA register

	in temp, EIMSK	; Choose the right INT
	ori temp, (1<<INT0) | (1<<INT1) ; Logical or 
	out EIMSK, temp 
	sei				; Enable global interrupt
	jmp main 


EXT_INT0: 
	push temp 
	in temp, SREG	; Get value from the status register
	push temp 

	in temp, PORTC; 
	dec temp;		; Decrememt value by one
	out PORTC, temp

	buff

	pop temp 
	out SREG, temp	; Set value
	pop temp 

	sbi EIFR,0		; Set bit 0 of interrupt flag to 1
	reti
 

EXT_INT1: 
	push temp 
	in temp, SREG	;get value from the status register
	push temp 

	in temp, PORTC
	inc temp		;set value
	out PORTC, temp

	buff

	pop temp 
	out SREG, temp 
	pop temp 

	sbi EIFR,1
	reti
 
 
main:               
	rjmp main 

/*
first_delay0: 
	clr j;
	inc i; 
	cpi i, 100;
	breq finish_delay0
second_delay0:
	clr k;
	inc j;
	cpi j, 100;
	breq first_delay0;
third_delay0:
	clr n;
	inc k;
	cpi k, 100;
	breq second_delay0
fourth_delay0:
	cpi n, 8;
	breq third_delay0
	nop;
	inc n;
	rjmp fourth_delay0;
finish_delay0:
	clr i;
	clr j;
	clr k;
	clr n;
	reti
*/
/*
sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
	rjmp delayloop_1ms

delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	reti
 */

/*
switch1:
	sbic PIND, 1 ; Skip the next instruction if PB1 is pushed
	rjmp switch0 ; If not pushed, check the other switch
	buff
	inc count ; Store count to the LEDs if the switch was pushed
	andi count, 0b1111
	out PORTC, count
	rjmp switch0 ; Now check PB0 again
*/


