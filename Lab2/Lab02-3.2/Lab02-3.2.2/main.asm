; Lab02-3.2.asm
;
; Created: 8/23/2018 9:20:16 AM
; Author : Ihor Balaban
; Version : .1

.include "m2560def.inc" 

.macro multo	; macro used to multiply two byte number by on byte
	mul @1, @2	; @0, @1 are first two bytes
	mov @5, r0	; @ 2 is single byte 
	mov @4, r1
	clr @3		; @3, @4, @5 are 3 registers for return 
	mul @0, @2
	add @4, r0
	adc	@3, r1
.endmacro

.dseg
.org 0x200
a_array: .byte 44	; reserve 22 bytes for a_array
.equ n_ = 10
.equ x_ = 3 

.cseg
main:  
	ldi xl, low(a_array)
	ldi xh, high(a_array)		; used to keep track of a_n * x_^n
	ldi r28, low(RAMEND-17)
	ldi r29, high(RAMEND-17)	; reserve 17 bytes for storing i, sum, result and array A
	mov zl, r28
	mov zh, r29					; copy Y pointer into z to use for storing A_array 	
	out SPH, r29
	out SPL, r28

	clr r16
	clr r17			; r18:r17:r16 used to store sum		
	clr r18		
	clr r20			; r20 used for i, i = 0
	std Y+1, r18
	std Y+2, r17	
	std Y+3, r16	; implement sum = 0
	adiw Z, 7		; increment Z pointer to store A array 

loop:
	st Z+, r20		; store a[i] = i
	std Y+6, r20	; store i 
	rcall power		; jump to power function 
	std Y+4, r25
	std Y+5, r24	; store the result
	multo r25, r24, r20, r7, r6, r5	; bultiply two byte number by a[i] 
	st x+, r5
	st x+, r6
	st x+, r7
	; delete later 
	clr r11
	st x+, r11
	;
	add r16, r5
	adc r17, r6		; sum += result * a[i]
	adc r18, r7		; get running sum 
	std Y+1, r18
	std Y+2, r17	; store sum 
	std Y+3, r16
	
	inc r20
	cpi r20, low(n_)
	brlo loop		; i <= n
	breq loop
	rjmp end_loop

power: 
	push r20	; stores power when passed (i)
	push r16
	push r17	; r16:r17 used to store num
	push r18	; used to store i
	push r19	; used to store number(x)
	push r28
	push r29
	in r28, SPL
	in r29, SPH
	sbiw r29:r28, 5	; 5 bytes to store parameters and local variables 
	out SPH, r29
	out SPL, r28		; compute stack frame top
	ldi r19, low(x_)	; store x 	
	std Y+1, r20	; stores power	(i passed)
	std Y+2, r19	; stores number (x passed)
	ldi r24, 1
	clr r25			; num = 1
	ldi r18, 1		; i = 1 
	cpi r20, 0
	breq ep			; handle corner case where power = 0

inner_loop:
	multo r25, r24, r19, r5, r17, r16	; multiply num * number
	mov r24, r16	; power function does not reach 2 byte max, ignore byte 3 (r18)
	mov r25, r17	; *=
	std Y+3, r25
	std Y+4, r24		; store num 
	std Y+5, r18		; store i (local) 

	inc r18
	cp r18, r20
	brlo inner_loop
	breq inner_loop

ep:	
	adiw r29:r28, 5	; deallocate stack frame 
	out SPH, r29
	out SPL, r28
	pop r29
	pop r28
	pop r19
	pop r18
	pop r17
	pop r16
	pop r20
	ret


end_loop:
	rjmp end_loop