; Lab 01, Task 3.5
;
; Author: Ihor Balaban
; zID: z5229133
; Date: 14/8/2018
; Version: .1

.include "m2560def.inc" 

.def char_i = r16
.def char_j = r17
.def char_k = r18	; define 3 registers for storing i, j, k
.def C_byte0 = r7
.def C_byte1 = r8	; r8:r7 used to store  C += A*B
.def C_byte2 = r9
.def C_byte3 = r10
.def a_ij_low = r19		; used to store a[i][j] temporarily
.def a_ij_high = r20
.def b_ij_low = r21		; used to store b[i][j] temporarily 
.def b_ij_high = r22
.def num_low = r23
.def num_high = r24

.equ n_max = 5		; defines the max size of the arrays

.dseg				; define data segment
.org 0x200			; set starting address
A_array: .byte 50	; allocate 50 bytes for array A 
B_array: .byte 50	; allocate 50 bytes for array B
C_array: .byte 100	; allocate 100 bytes for array C 

.cseg
.org 0x100			; set the origin of the code to 0x100

; initialize A,B,C
ldi xl, low(A_array)
ldi xh, high(A_array)	; set x to point to array A
ldi yl, low(B_array)
ldi yh, high(B_array)	; set y to point to array B
ldi zl, low(C_array)
ldi zh, high(C_array)	; set z to point to array C

ldi num_low, low(1024)
ldi num_high, high(1024)

clr char_i		; i = 0
main_loop:
	clr char_j	; j = 0 
loop_1:
	; store A[i][j]
	mov a_ij_low, char_i
	add a_ij_low, char_j	; a[i][j] = i + j
	mul a_ij_low, num_low
	mov r5, r0
	mov r6, r1
	mul a_ij_low, num_high
	add r6,r0 

	st x+, r5	; store in data memory 
	st x+, r6
	st y+, r5
	st y+, r6

	; store C[i][j] 
	clr C_byte0
	clr C_byte1	; C[i][j] = 0
	clr C_byte2
	clr C_byte3
	st z+, C_byte0
	st z+, C_byte1	; store C[i][j] in little endian order
	st z+, C_byte2
	st z+, C_byte3

	inc char_j		; j++
	cpi char_j, n_max
	brlt loop_1		; branches to inner loop 	

	inc char_i		; i++
	cpi char_i, n_max
	brlt main_loop	; branches to outer loop 

	; reinitialize array pointers 
	ldi xl, low(A_array)
	ldi xh, high(A_array)	; set x to point to array A
	ldi zl, low(C_array)
	ldi zh, high(C_array)	; set z to point to array C

	

	clr char_i		; i = 0
second_loop:
	clr char_j		; j = 0
	
	ldi yl, low(B_array)
	ldi yh, high(B_array)	; reset y to point to start of B array

loop_2:
	clr char_k		; k = 0
	clr C_byte0
	clr C_byte1		; reset running sum of C 

loop_3:
	ld a_ij_low, x+	; load A[i][k] and increment x
	ld b_ij_low, y+	; load B[i][k] and increment y

	muls a_ij_low, b_ij_low	; multiply a[i][k] * b[k][j]

C_p_e:				; calculates the running sum
	add C_byte0, r0
	adc C_byte1, r1

	; Properly increment B 
	adiw y, 4	; move y pointer to next position 

	inc char_k
	cpi char_k, n_max
	brlt loop_3

	; store C[i][j]
	st z+, C_byte0
	st z+, C_byte1

	sbiw y, 24	; set the pointer to point to next column in array B
	sbiw x, 5

	inc char_j
	cpi char_j, n_max
	brlt loop_2

	adiw x, 5	; move x pointer to point to next row in A 

	inc char_i
	cpi char_i, n_max
	brlt second_loop
	
loop:
	rjmp loop