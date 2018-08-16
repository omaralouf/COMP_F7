; Lab1A.asm
; Author : Omar Al-Ouf
; Email: o.al-ouf@unsw.edu.au

.include "m2560def.inc"

.cseg				; initiate code segment
rjmp start			; jump to start

start:				; load two 2-byte integers
	ldi r16, LOW(550) ; a_low
	ldi r17, HIGH(550); a_high
	ldi r18, LOW(350) ; b_low
	ldi r19, HIGH(350); b_high

while:
	cp r16, r18		; compare low bytes 
	cpc r17, r19	; compare high bytes
	brne not_equal	; branch to 'not_equal' if integers are Not Equal
	rjmp end

not_equal:
	;cp r16, r18	; no need to compare again since 
	;cpc r17, r19
	brsh a_soh_b	; branch to a_soh_b if Same or Higher (a > b)
	rjmp a_less_b	; otherwise jump to a_less_b

a_less_b:			; b = b-a
	sub r18, r16
	sbc r19, r17 
	rjmp while

a_soh_b:			; a = a-b
	sub r16, r18
	sbc r17, r19
	rjmp while

end:
	rjmp end

; brsh/brlo for unsigned
; brge/brlt for signed