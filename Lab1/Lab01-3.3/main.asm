; Lab1C.asm
; Author : Omar Al-Ouf
; Email: o.al-ouf@unsw.edu.au

.include "m2560def.inc"

.def counter = r19	; define a counter (i)

.dseg
array: .byte 20	; set array size (2 bytes x 10)
sum: .byte 2	; set a 16-bit variable for summation
temp: .byte 2	; temporary variable

.cseg
; set registers
ldi r16, low(temp)
ldi r17, high(temp)

ldi zl, low(array)
ldi zh, high(array)

ldi r21, low(sum)
ldi r22, high(sum)

; initialise value
ldi r20, 200
clr r16
clr r17
clr counter
clr r21
clr r22

; initialise the value of the array
initialise_array:

	mul counter,r20
	mov r16,r0
	mov r17,r1
	st z+,r16	; store the low byte into r16 (low(temp)) and point to the next element in the array
	st z+,r17
	inc counter
	cpi counter,10

	; if counter less than 10, loop again
	brlt initialise_array

	; reload the value
	clr counter
	clr r0
	clr r1
	ldi zl, low(array)
	ldi zh, high(array)

; do the summation
summation:
	; load values from array a
	ld r0,z+
	ld r1,z+

	add r21,r0
	adc r22,r1

	inc counter
	cpi counter,10

	brlt summation

end:
	rjmp end

; 9000 = 0x2328


