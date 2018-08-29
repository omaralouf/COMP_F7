;
; Lab02-3.4.asm
;
; Created: 8/29/2018 1:34:25 PM
; Author : balabi
; zID : 5229133
; Version : .1 


.macro st_tb		; macro used to store a two byte number in memory
	ldi r16, low(@2)
	ldi r17, high(@2)
	st @0+, r16
	st @0+, r17		; store @2 in FLASH 
	st @1+, r16
	st @1+, r17		; store @2 in SRAM
	clr r16
	clr r17
.endmacro

.include "m2560def.inc"

.dseg 
.org 0x200
test_array: .byte 20

.cseg 
ldi xl, low(test_array)
ldi xh, high(test_array)		; x pointer to step through test array 
ldi r28, low(RAMEND-21)
ldi r29, high(RAMEND-21)		; 20 bytes reserved for test array in 
mov zl, r28						;
mov zh, r29
out SPH, r29
out SPL, r28					; adjust stack pointer to point to the top 
adiw r31:r30, 1

; store initial values of test array in FLASH and SRAM memory 
st_tb x, z, 100
st_tb x, z, 209
st_tb x, z, -725
st_tb x, z, -200
st_tb x, z, 500
st_tb x, z, 301
st_tb x, z, 60
st_tb x, z, -400
st_tb x, z, 100
st_tb x, z, 80
sbiw z, 20			; reset z pointer 

ldi r18, 0
ldi r19, 9
rcall quicksort					; call quicksort function

end_loop:
	rjmp end_loop

quicksort:
	push r24			; stores return
	push r18			; stores p
	push r19			; stores r
	push r28
	push r29
	in r28, SPL
	in r29, SPH 
	sbiw r29:r28, 5		; 5 bytes to store variables 
	out SPH, r29
	out SPL, r28

	std Y+1, r18		; store p
	std Y+2, r19		; store r
	std Y+4, zl
	std Y+5, zh		; store pointer (*array)

if: 
	cp r18, r19			; compare p, r
	brge epilogue
	
	rcall partition
	std Y+3, r24			; store q in SRAM 

	ldd r18, Y+1
	ldd r19, Y+3			; load q for into r19 for first recursive call
	subi r19, 1
	ldd zl, Y+4
	ldd zh, Y+5				; reinitialize pointer
	rcall quicksort 

	ldd r18, Y+3			; load q into p slot for second recursive call 
	subi r18, -1			; no add immediate, use sub with negative
	ldd r19, Y+2
	ldd zl, Y+4
	ldd zh, Y+5				; reinitialize pointer 
	rcall quicksort
	
epilogue:
	adiw r29:r28, 5			; add bytes here 
	out SPH, r29
	out SPL, r28
	pop r29
	pop r28
	pop r19
	pop r18
	pop r24
	ret

partition:
	push r18
	push r19
	push r20
	push r21			; r21:r20 used to store pivot 
	push r28
	push r29
	in r28, SPL
	in r29, SPH
	sbiw r29:r28, 8		; reserve SRAM storage for function  
	out SPL, r28
	out SPH, r29

	std Y+1, zl
	std Y+2, zh			; store array pointer 
	std Y+3, r18		; store p
	std Y+4, r19		; store r

	ldi r20, 2			; use r20 to temporarily store 2
	mul r18, r20		; to get proper place for 2 byte array 
	add zl, r0
	adc zh, r1			; find array[p]
	std Y+7, zl
	std Y+8, zh			; store array[p] pointer 

	ld r20, z+
	ld r21, z+			; r21:r20 store pivot
	std Y+5, r20
	std Y+6, r21		; store pivot in SRAM 
	ldd r16, Y+3		; i = p
	ldd r17, Y+4		; j = r
	subi r17, -1		; j + 1

while_1:

do_1: 
	inc r16				; i++
	ldd zl, Y+1
	ldd zh, Y+2			; get beginning of array
	ldi r24, 2
	mul r24, r16		; used for sign extention 
	add zl, r0
	adc zh, r1			; gets array[i]
	ld r22, z+
	ld r23, z+			; store array[i]
	sbiw z, 2			; moves pointer back to array[i] 
	cp r17, r16			; branches when i > r
	brlt do_2
	cp r20, r22
	cpc r21, r23		; r23:r22 stores array[i]
	brlt do_2
	rjmp do_1

do_2:
	dec r17
	ldd xl, Y+1
	ldd xh, Y+2			; use x pointer to keep track of array[j]
	ldi r24, 2
	mul r24, r17		; used to get position of array[j]
	add xl, r0
	adc xh, r1
	ld r22, x+
	ld r23, x+			; store array[j] in r23:r22
	sbiw x, 2			; reset to array[j]	
	cp r20, r22
	cpc r21, r23
	brlt do_2

i_s_h:
	cp r16, r17			; compare i and j 
	brge swap_nums		; breaks

	ld r18, z+
	ld r19, z+			; load array[i] into temp
	sbiw z, 2
	st z+, r22
	st z+, r23			; store array[j] in array[i]
	st x+, r18
	st x+, r19			; store array[i] in array[j]
	sbiw x, 2
	sbiw z, 2			; point back to array[i]/[j]
	rjmp while_1
	
swap_nums: 			
	ldd zl, Y+7
	ldd zh, Y+8			; load array[p] position into z pointer
	st z+, r22
	st z+, r23		; store array[j] in array[p]
	st x+, r20
	st x+, r21			; store array[p] in array[j]
	mov r24, r17		; return j

	adiw r29:r28, 8
	out SPH, r29
	out SPL, r28
	pop r29
	pop r28
	pop r21
	pop r20
	pop r19
	pop r18
	ret





