; Lab2C.asm
; Author : Omar Al-Ouf
; Email: o.al-ouf@unsw.edu.au

.include "m2560def.inc"
.def n=r16
.def a=r17
.def b=r18
.def c=r19
.def cou=r22		; final result

.dseg
counter: .byte 1	; global variable

.cseg
ldi n,8
ldi a,1
ldi b,3
ldi c,2

ldi xl,low(counter)
ldi xh,high(counter)
ldi cou,low(counter)

clr r20
clr cou
st x,r20
ldi r21,1

main:
	ldi yl,low(RAMEND-4)	; start address at 4 bytes before end of SRAM
	ldi yh,high(RAMEND-4)	; leave 4 bytes at the end for the variables
	out SPL,yl		; adjust the stack pointer so that it points to the
	out SPH,yh		; new stack top

	std y+4,n		; address of n is y+4
	std y+3,a		; address of a is y+3
	std y+2,b		; address of b is y+2
	std y+1,c		; address of c is y+1
	
	rcall move		; call the function move

end: 
	rjmp end


; prologue, frame size=4 (excluding the stack frame
; space for storing return address and registers) 
move:								
	push r28		; Save r28 and r29 on top of the stack
	push r29		
	in r28,SPL		; Stack pointer (high)
	in r29,SPH
	sbiw r28,4		; Compute the stack frame top for move
					; Notice that 4 bytes are needed to store
					; the actual parameters n, a, b, c

	out SPH,r29		; Adjust the stack frame pointer to point to
	out SPL,r28		; the new stack frame

	std y+4,n		; Pass the actual parameter n to y+4
	std y+3,a
	std y+2,c
	std y+1,b

	; if statement
	cp n,r21
	brne else	; if n != 1, go to else
	
	add cou,r21
	st x,cou	; st same as std, but for index space x

epilogue:
	adiw r28,4		; Deallocate the stack frame
	out SPH,r29
	out SPL,r28
	pop r29			; Restore Y 
	pop r28
	ret				; Return 
	
else:
	ldd n,y+4		; first recursive move call
	ldd a,y+3		; ldd same as ld, but for y index
	ldd b,y+2
	ldd c,y+1
	sub n,r21
	rcall move

	ldd n,y+4		; second recursive move call
	ldd a,y+3
	ldd c,y+2
	ldd b,y+1
	mov n,r21
	rcall move

	ldd n,y+4		; third recursive move call
	ldd b,y+3
	ldd c,y+2
	ldd a,y+1
	sub n,r21
	rcall move

	rjmp epilogue	; go to epilogue
