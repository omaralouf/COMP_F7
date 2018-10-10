
; Lab4.3_test_code.asm
;
; Created: 10/8/2018 8:59:11 PM
; Author : balabi
;
;Board settings: 
;Connect the four columns C0~C3 of the keypad to PL3~PL0 of PORTL and the four rows R0~R3 to PL7~PL4 of PORTL.
;Connect LED0~LED7 of LEDs to PC0~PC7 of PORTC. 
; For I/O registers located in extended I/O map, "IN", "OUT", "SBIS", "SBIC", 
; "CBI", and "SBI" instructions must be replaced with instructions that allow access to 
; extended I/O. Typically "LDS" and "STS" combined with "SBRS", "SBRC", "SBR", and "CBR".

.include "m2560def.inc"
.def CalcR = r3	; register used to store several different flags
; bit 0 (= pressed), 1 (- pressed), 2 (+ pressed), 3 (overflow), 4 (negative), 5 (previous result stored), 6 (incorrect exp), 7 (other than zero printed)
.def nl1 = r4
.def nh1 = r5
.def ncount = r6
.def temp3 = r7
.def temp4 = r8
.def flag = r15	; stores flag
.def temp =r16
.def temp2 =r17
.def row =r18
.def col =r19
.def mask =r20
.def n_chars = r21 ; number of characters printed
.def lcd_temp = r22
.def numl = r24
.def numh = r25	; low and high byte for number


;Keypad Equations
.equ PORTLDIR = 0xF0
.equ INITCOLMASK = 0xEF
.equ INITROWMASK = 0x01
.equ ROWMASK = 0x0F

;LCD Equations
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4
.equ HOB_NUM = 0b00110000		;high order bit for numbers

.dseg 
running_num: .byte 2	; stores expression results

					; and answer [First num, second num, Result]
.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data
	mov r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro do_lcd_data_l	; for printing letters to lcd
	ldi r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro lcd_set
	sbi PORTA, @0
.endmacro

.macro lcd_clr
	cbi PORTA, @0
.endmacro

.macro divide_10	; divides number by 10 for printing
	clr temp2
	clr temp3	; temp2, temp3 are used as a counter
	clr temp4
begin_loop:
	ldi temp, 10
	cp @0, temp
	cpc @1, temp4	; sign extension
	brlo end
	sub @0, temp
	sbc @1, temp4
	ldi temp, 1
	add temp2, temp
	adc temp3, temp4
	rjmp begin_loop
end:
	mov @0, temp2
	mov @1, temp3
.endmacro

.macro sub_by_mul10 
	mov temp, @0
l_start:
	cpi temp, 0
	breq finished
	sub @3, @1
	sbc @4, @2
	subi temp, 1
	rjmp l_start
finished:
.endmacro

.macro store_result		; stores result if none is stored
	st @2+, @0
	st @3, @1
.endmacro

.macro Load_from_zp
	ldi zl, low(running_num)
	ldi zh, high(running_num)
	ld @0, z+
	ld @1, z
.endmacro

.macro Store_to_zp
	ldi zl, low(running_num)
	ldi zh, high(running_num)
	st z+, @0
	st z, @1
.endmacro

.cseg
jmp RESET
.org 0x72

RESET:
ldi temp, low(RAMEND)
out SPL, temp
ldi temp, high(RAMEND)
out SPH, temp
ldi temp, PORTLDIR ; columns are outputs, rows are inputs
STS DDRL, temp     ; cannot use out

; used to get buts out to LED bar
ser temp
out DDRC, temp ; Make PORTC all outputs

out DDRA, temp ; Port A output
out DDRF, temp ; Port F output

clr temp
out PORTC, temp ; Turn off all the LEDs

out PORtA, temp
out PORTF,temp

do_lcd_command 0b00111000 ; 2x5x7
rcall sleep_5ms
do_lcd_command 0b00111000 ; 2x5x7
rcall sleep_1ms
do_lcd_command 0b00111000 ; 2x5x7
do_lcd_command 0b00111000 ; 2x5x7
do_lcd_command 0b00001000 ; display off?
do_lcd_command 0b00000001 ; clear display
do_lcd_command 0b00000110 ; increment, no display shift
do_lcd_command 0b00001101 ; no cursor, bar blinks
clr n_chars
clr numl
clr numh
clr CalcR
	
; main keeps scanning the keypad to find which key is pressed.
main:
	cpi n_chars, 16
	brne clear_check
	rcall next_or_clear

clear_check:
	cpi n_chars, 32
	brne no_clear
	rcall next_or_clear

no_clear: 
	ldi mask, INITCOLMASK ; initial column mask, initially 0xEF
	clr col ; initial column

colloop:
	STS PORTL, mask ; set column to mask value
	; (sets column 0 off)
	ser temp ; implement a delay so the
	; hardware can stabilize

delay:
	dec temp
	nop
	brne delay
	LDS temp, PINL ; read PORTL. Cannot use in
				   ; rows are inputs, cols are outputs 
	andi temp, ROWMASK ; read only the row bits
	cpi temp, 0xF ; check if any rows are grounded
	breq nextcol ; if not go to the next column
	ldi mask, INITROWMASK ; initialise row check
	clr row ; initial row

rowloop:      
	mov temp2, temp
	and temp2, mask ; check masked bit
	brne skipconv ; if the result is non-zero,
	; we need to look again
	rcall convert ; if bit is clear, convert the bitcode
	jmp main ; and start again

skipconv:
	inc row ; else move to the next row
	lsl mask ; shift the mask to the next bit
	jmp rowloop  
	        
nextcol:     
	cpi col, 3 ; check if we are on the last column
	breq main ; if so, no buttons were pushed,
	; so start again.

	sec ; else shift the column mask:
	; We must set the carry bit
	rol mask ; and then rotate left by a bit,
	; shifting the carry into
	; bit zero. We need this to make
	; sure all the rows have
	; pull-up resistors
	inc col ; increment column value
	jmp colloop ; and check the next column
	
; convert function converts the row and column given to a
; binary number and also outputs the value to PORTC.
; Inputs come from registers row and col and output is in
; temp.
convert:
	cpi col, 3 ; if column is 3 we have a -,+, or =
	breq signs
	cpi row, 3 ; if row is 3 we have a symbol or 0
	brne continue_1
	rjmp symbols
	
continue_1:
	mov temp, row ; otherwise we have a number (1-9)
	lsl temp ; temp = row * 2
	add temp, row ; temp = row * 3
	add temp, col ; add the column address
	; to get the offset from 1
	inc temp ; add 1. Value of switch is
	; row*3 + col + 1.
	mov temp2, temp
	
	mov lcd_temp, temp ; store value into lcd register
	ldi temp, HOB_NUM
	or lcd_temp, temp  ; OR HOB and value to output ASCII value of number
	mov temp, temp2    ; original value to temp
	jmp convert_end

signs:
	cpi row, 0	; check if minus
	breq minus
	cpi row, 1  ; check if plus
	breq plus
	cpi row, 2	; check if equal sign
	breq equals	
	cpi row, 3	; d is pressed
	clr CalcR
	rjmp reset	; D resets LCD

equals:
	ldi lcd_temp, 61 	; "="
	ldi temp, 0x01
	or CalcR, temp		; set equals is pressed flag
	clr temp
	jmp convert_end

minus:
	mov temp, CalcR	; checks for plus first
	andi temp, 0b00000100
	cpi temp, 0b00000100
	brne sub_check_1
	rcall add_to_previous
	rjmp none_set_1
sub_check_1:
	mov temp, CalcR	; checks for plus first
	andi temp, 0b00000010
	cpi temp, 0b00000010
	brne none_set_1
	rcall sub_from_prev
none_set_1:
	ldi temp, 0b00000010
	or CalcR, temp		; set minus bit 
	Store_to_zp numl, numh		; store the last result
	ldi temp, 0b00100000
	or CalcR, temp 
	clr numl
	clr numh 
	clr temp
	ldi lcd_temp, 45			; ASCII for minus
	jmp convert_end
plus: 
	; check if plus or minus were already pressed
	mov temp, CalcR	; checks for plus first
	andi temp, 0b00000100
	cpi temp, 0b00000100
	brne sub_check
	rcall add_to_previous
	rjmp none_set

sub_check:
	mov temp, CalcR	; checks for plus first
	andi temp, 0b00000010
	cpi temp, 0b00000010
	brne none_set
	rcall sub_from_prev
none_set: 
	ldi temp, 0b00000100
	or CalcR, temp		; set plus bit 	
	Store_to_zp numl, numh	; store the last result
	ldi temp, 0b00100000
	or CalcR, temp 
	clr numl
	clr numh 
	clr temp
	ldi lcd_temp, 43	; "+"
	jmp convert_end

symbols:
	cpi col, 1 ; or if we have zero
	breq zero
	ldi temp, 0b01000000
	or CalcR, temp ; set incorrect expression flag
	cpi col, 0 ; check if we have a star
	breq star
	clr temp
	ldi lcd_temp, 35 ; Hash ASCII
	jmp convert_end

star:
	clr temp
	ldi lcd_temp, 42 ; star output
	jmp convert_end

zero:
	clr temp ; set to zero
	mov lcd_temp, temp
	ldi temp, HOB_NUM
	or lcd_temp, temp
	clr temp

convert_end:
	out PORTC, CalcR ; write status of register to LED bar
					 ; used for debugging
	mov temp2,temp	 ; temp2 now stores the last value of the key that was pressed
	LDS temp, PINL	; read pinl 
	mov flag, temp
	do_lcd_data lcd_temp	; send out the key
	inc n_chars

sign_check:
	mov temp, CalcR
	andi  temp, 0b00000001	; checks if equals is pressed
	cpi temp, 0b1
	breq print_num ; Equals is pressed 
	ldi temp, 10
	mov nl1, numl
	mov nh1, numh
	clv
loop:
	add nl1, numl
	adc nh1, numh
	brvs overflow
	dec temp
	cpi temp, 2
	brge loop
	
	;mul numl, temp
	;mov nl1, r0
	;mov nh1, r1
	;mul numh, temp
	;add nh1, r0
	;brcs overflow	; carry is set
	;mov temp, r1
	;cpi temp, 0
	;brne overflow		; overflow occurs

continue:
	mov numl, nl1
	mov numh, nh1 ; move the result back into numl, numh
	clr temp	  ; sign extension 
	add numl, temp2
	adc numh, temp ; add the last pressed number
	brvc preserve 
	ldi temp, 0b00001000
	or CalcR, temp
		
preserve:
	out PORTC, CalcR
	rcall sleep_5ms
	LDS temp, PINL
	cp temp, flag
	breq preserve
	ret ; return to caller

overflow:
	;set overflow flag
	ldi temp, 0b00001000
	or CalcR, temp 
	rjmp continue

next_or_clear:
	cpi n_chars, 16
	breq next_line 
	cpi n_chars, 32
	breq clear
	ret

next_line:
	lcd_clr LCD_RS
	lcd_clr LCD_RW
	do_lcd_command 0b11000000
	ret

clear:
	lcd_clr LCD_RS
	lcd_clr LCD_RW
	do_lcd_command 0b00000001
	clr n_chars
	ret

print_num:
	out PORTC, CalcR
Inexp:
	;check for incorrect expression
	mov temp, CalcR
	andi temp, 0b01000000
	cpi temp, 0b01000000
	brne overflow_check
	rcall incorrect_expression
	rjmp preserve

overflow_check:
	; check for overflow
	mov temp, CalcR
	andi temp, 0b00001000
	cpi temp, 0b00001000
	brne Calculation			; no overflow set
	rcall invalid_answer
	rjmp preserve

Calculation:
	ldi zl, low(running_num)
	ldi zh, high(running_num)
	ld nl1, z+
	ld nh1, z
	mov temp, CalcR	; check if you add or subtract numbers
	andi temp, 0b00000100
	cpi temp, 0b00000100	; checks if add register is set 
	breq add_num
	mov temp, CalcR
	andi temp, 0b00000010	; minus flag is set
	cpi temp, 0b00000010
	breq subtract
	rjmp integer	; only a integer is present

add_num:
	clv
	add numl, nl1
	adc numh, nh1
	brvs overflow_occured
	ldi zl, low(running_num)
	ldi zh, high(running_num)
	st z+, numl
	st z, numh
	ldi temp, 0b11111001	; remove plus set flag
	and CalcR, temp
	ldi temp, 0b00100000	; set stored expression flag
	or CalcR, temp 
	rjmp contd

subtract:
	clv
	sub nl1, numl
	sbc nh1, numh
	brvs overflow_occured
	ldi zl, low(running_num)
	ldi zh, high(running_num)
	st z+, nl1
	st z, nh1
	ldi temp, 0b11111001	; remove minus set flag
	and CalcR, temp
	rjmp contd 

overflow_occured:
	ldi temp, 0b00001000	; set overflow flag
	or CalcR, temp
	rcall invalid_answer
	rjmp preserve
	

integer:
	ldi zl, low(running_num)
	ldi zh, high(running_num)
	st z+, numl
	st z, numh
	ldi temp, 0b00100000 ; sets flag for stored number

contd:
	clr temp
	ldi zl, low(running_num)
	ldi zh, high(running_num)
	ld numl, z+
	ld numh, z				; load in last result
	cpi numl, 0
	cpc numh, temp
	brlt negative_result	; negative result
	breq before_loop
before_start:	
	ldi temp, low(10000)
	ldi temp2, high(10000)
	mov nl1, temp
	mov nh1, temp2	; starts with subtracting by 10000
	clr ncount		; first digit count = 0

start:
	ldi temp, 1
	cp nl1, temp 
	brlo end		; skip if it cannot be divided  
	cp numl, nl1 
	cpc numh, nh1	; see if number is greater than 
	brge loop_start
	; print number
	divide_10 nl1,nh1 ; number is less than current divisor, go down by 10
	;sub_by_mul10 ncount, nl1, nh1, numl, numh
	clr temp
	cp ncount, temp
	breq zero_check ; check if non zeros were printed

before_loop:
	ldi temp, 48
	add ncount, temp
	rcall next_or_clear
	do_lcd_data ncount
	ldi temp, 0b10000000	; set number other than zero out flag
	or CalcR, temp
	inc n_chars
	clr ncount
	rjmp start

loop_start:
	sub numl, nl1
	sbc numh, nh1
	inc ncount
	rjmp start

negative_result:
	rcall next_or_clear 
	do_lcd_data_l '-' ; inverts the bits, and sends it out as a positive number
	inc n_chars
	ldi temp, 0xFF
	eor numl, temp 
	eor numh, temp 
	ldi temp, 1
	clr temp2
	add numl, temp
	adc numh, temp2
	
	rjmp before_start

end:
	rjmp preserve

zero_check:		; checks if a number other than zero was printed to the LCD
	ldi temp, 0b10000000
	and temp, CalcR
	cpi temp, 0 
	breq start
	rjmp before_loop

add_to_previous: ; adds current number from buffer to storage
	Load_from_zp temp, temp2
	clv
	add numl, temp
	adc numh, temp2
	brvs over_flow
	ldi temp, 0b11111011
	and CalcR, temp ; clear plus set flag
	ret

sub_from_prev: ; subs current number in buffer from storage
	Load_from_zp temp, temp2
	clv
	sub temp, numl
	sbc temp2, numh
	brvs over_flow
	mov numl, temp
	mov numh, temp2
	ldi temp, 0b11111101
	and CalcR, temp ; clear minus set flag
	ret

over_flow:
	ldi temp, 0b00001000	; set overflow flag
	or CalcR, temp
	ret

invalid_answer:
	rcall next_or_clear
	do_lcd_data_l 'O'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'v'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'e'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'r'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'f'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'l'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'o'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'w'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l ' '
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'O'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'c'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'c'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'u'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'r'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'r'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'e'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'd'
	inc n_chars
	ret

incorrect_expression:
	rcall next_or_clear
	do_lcd_data_l 'I'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'n'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'c'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'o'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'r'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'r'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'e'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'c'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 't'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l ' '
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'E'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'x'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'p'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'r'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'e'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 's'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 's'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'i'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'o'
	inc n_chars
	rcall next_or_clear
	do_lcd_data_l 'n'
	inc n_chars
	ret
	
;
; Send a command to the LCD (r16)
;

lcd_command:
	out PORTF, r16
	nop
	lcd_set LCD_E
	nop
	nop
	nop
	lcd_clr LCD_E
	nop
	nop
	nop
	ret

lcd_data:
	out PORTF, r16
	lcd_set LCD_RS
	nop
	nop
	nop
	lcd_set LCD_E
	nop
	nop
	nop
	lcd_clr LCD_E
	nop
	nop
	nop
	lcd_clr LCD_RS
	ret

lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW

lcd_wait_loop:
	nop
	lcd_set LCD_E
	nop
	nop
    nop
	in r16, PINF
	lcd_clr LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	out DDRF, r16
	pop r16
	ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)

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
	ret
