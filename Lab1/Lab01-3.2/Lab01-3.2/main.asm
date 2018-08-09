; Lab 01, Task 3.2 
;
; Author: Ihor Balaban
; zID: z5229133
; Date: 9/8/2018
; Version: .1

.include "m2560def.inc"	; Definition file for Mega64

.def char_i = r17		; define char to register 17
.def ten = r16			; r16 used to store byte of ten 
.def n_byte0 = r13
.def n_byte1 = r14
.def n_byte2 = r15		; define 3 registers for holding n


.dseg					; define data segment 
.org 0x200				; set starting address to 0x200
int_val: .byte 4		; allocate 3 bytes of data memory to store the integer 

.cseg 
num_str: .db "325658"	; define number string "325658" which is stored in program memory 

ldi zl, low(num_str<<1)		; low byte of the address of "325658"
ldi zh, high(num_str<<1)	; high byte of "325658"

clr char_i				; i = 0
clr r19;				; r19 used for sign extension 
clr n_byte0
clr n_byte1
clr n_byte2				; clear n; n = 0
ldi ten, 10

main:
	mul n_byte0, ten	
	mov r20, r0
	mov r21, r1
	clr r22
	clr r23				; r23:r22:r21:r20 stores the result of n_byte0 * 10

	mul n_byte1, ten
	mov r26, r1
	mov r25, r0			; store the result of n_0 * 10
	clr	r27
	clr r24				; r27:26:25:24 store n_1 * 10
	
	add r24,r20
	adc r25, r21
	adc r26, r22
	adc r27, r23		; stores the result of n_1 * 10 + n_0 * 10

	mul n_byte2, ten
	mov r11, r0
	mov r12, r1
	clr r10
	clr r9				; r12:r11:r10:r9 store n_3 * 10 
	
	add r9, r24
	adc r10, r25
	adc r11, r26		; add the result of the third multiplication to r12-r9

	mov n_byte0, r9
	mov n_byte1, r10
	mov n_byte2, r11	; move the total into n 

	lpm r18, z+			; Load a character from Flash memory
	subi r18, 48		; subtract the ascii value of zero from the string
	add n_byte0, r18
	adc n_byte1, r19
	adc n_byte2, r19	; sign extend the character 

	ldi yl, low(int_val)
	ldi yh, high(int_val)	; y pointer points to start of int_val

	st y+, n_byte0
	st y+, n_byte1
	st y+, n_byte2		; store the integer in data memory 

	inc char_i			; increment the counter
	cpi char_i, 6
	brlt main

loop:
	rjmp loop

