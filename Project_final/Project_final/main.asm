;
; Project_final.asm
;
; Created: 10/21/2018 1:35:56 PM
; Author : balabi
;

.include "m2560def.inc" 		 

.def current_station = r12	; used for storing current station number
.def temp3 = r13 
.def flag=  r14
.def char_buff = r15	; serves as a buffer to store numbers, symbols, letters
.def temp = r16
.def row = r17
.def col = r18
.def mask = r19
.def temp2 = r20
.def Treg = r21			; flag status register used for train control 
.def n_chars = r22		; ; number of characters on screen
.def lcd_temp = r23


;Keypad constants 
.equ PORTLDIR = 0xF0
.equ INITCOLMASK = 0xEF
.equ INITROWMASK = 0x01
.equ ROWMASK = 0x0F

;LCD constansts
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

; macro to clear 2 byte data stored at an address
.macro clear_ptr
ldi YL, low(@0)
ldi YH, high(@0)
clr temp
st Y+ temp
st Y, temp
.endmacro

; macro used to multiply number by ten for storing multi digit
; numbers
.macro mul_by_10
	mov temp2, @0
	mov temp3, @0
	ldi temp, 9
loop_start:
	add temp2, temp3
	subi temp, 1
	cpi temp, 1 
	brge loop_start
	mov temp, temp2
	brvs overflow_occurred
	rjmp macro_end
overflow_occurred: 
	ldi temp, 128
macro_end:
.endmacro

; macros for checking which step the simulator is on using Treg flag bits  
.macro check_step1
	ldi @0, 0b10000000
	or @0, Treg
.endmacro

.macro check_step2
	ldi @0, 0b01000000
	or @0, Treg
.endmacro

.macro check_step3
	ldi @0, 0b00100000
	or temp, Treg
.endmacro

.macro check_step4
	ldi @0, 0b00010000
	or @0, Treg
.endmacro

; macro to load an address into a stack pointer
.macro ld_in_ptr
	ldi @0, low(@2)
	ldi @1, high(@2)
.endmacro

;LCD Macros 
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


.dseg
stat_names: .byte 100		; 100 bytes used to store station names, 10 bytes each 
stat_char_nums: .byte 10	; 10 bytes to store how many chars are in each station name
stat_time: .byte 10			; 10 bytes to store transfer time for each station
stations: .byte 1				; 1 byte to store the number of stations 
TC: .byte 2					; tempcounter 


.cseg
jmp RESET
.org INT0addr
jmp PB_0
.org INT1addr
jmp PB_1
.org OVF0addr
jmp Timer0OVF

RESET:
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp
	
	ldi temp, PORTLDIR		
	sts DDRL, temp			; columns are outputs, rows are inputs (0b11110000)
	
	ser temp
	out DDRC, temp			; Port C,F,A are all outputs
	out DDRF, temp
	out DDRA, temp
	
	clr temp
	out PORTC, temp			; all LEDs off
	out PORTF, temp
	out PORTA, temp			; enable pull-up resisters 

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

	ldi temp, (1<<PE4)		; PE is labeled as PE2
	out DDRE, temp	; Port E as output
	
	;Timer3
	;Determine duty-free
	clr temp
	sts OCR3BL, temp	; low register
	sts OCR3BH, temp	; high register
	ldi temp, (1<<CS30)	; no prescaling (CS30 = 1)
	sts TCCR3B, temp
	ldi temp, (1<<WGM30)|(1<<COM3B1)	; phase correct PWM, 8 bits, override port function of PE2
	sts  TCCR3A,temp
	
	sei
	clr temp
	out PORTD, temp
	out DDRD, temp		; set external interrupt 
	ldi temp, (2<<ISC10)|(2<<ISC00) ; set falling edge
	sts EICRA, temp
	in temp, EIMSK
	ori temp, (1<<INT0)|(1<<INT1)
	sei

	; clear all registers 
	clr current_station
	clr Treg 
	clr n_chars 
	ld_in_ptr xl,xh, stations
	st x, n_chars		; store zero in memory 
	
	rcall step_1
	rjmp main

;external interupt0
PB_0: 
	push temp 
	in temp, SREG 
	push temp 
	
	ldi temp, 0
	sts OCR3BL,temp
	
	ori Treg, 0b1		; set stop at next station flag 
	out PORTC, Treg
	pop temp 
	out SREG, temp 
	pop temp 
	reti 

;external interupt1
PB_1: 
	push temp 
	in temp, SREG 
	push temp 
	
	ldi temp, 60
	sts OCR3BL,temp
	
	ori Treg, 0b1		; set stop at next station flag
	out PORTC, Treg
	pop temp 
	out SREG, temp 
	pop temp 
	reti 

; scans keyboard to see what key is pressed
main:
	;out PORTC, Treg
	rcall next_or_clear		; see if to move to next line

s_start:
	ldi mask, INITCOLMASK	; 0xEF
	clr col

colloop:
	sts PORTL, mask	; column to mask value (initially column 0 is off)
	ser temp 

delay: ;let hardware stabilize
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
	cpi col, 3 ; if column is 3 we have a letter
	breq letters
	cpi row, 3 ; if row is 3 we have a symbol or 0
	breq symbols

	; we have a number 
	mov temp, row ; otherwise we have a number (1-9)
	lsl temp ; temp = row * 2
	add temp, row ; temp = row * 3
	add temp, col ; add the column address
	; to get the offset from 1
	inc temp ; add 1. Value of switch is
	; row*3 + col + 1.
	mov char_buff, temp

	; check which step is taking place
	ldi temp, 0b10000000
	and temp, Treg
	cpi temp, 0b10000000
	breq num_key		; number key is pressed for step one
	
	ldi temp, 0b00100000
	and temp, TREG
	cpi temp, 0b00100000
	breq num_key		; step 3, number is pressed 


symbols:
	cpi col, 0		; star is pressed
	breq star_pressed
	cpi col,1		; zero pressed
	breq zero_pressed

;hash pressed, next instruction
	rcall next_step
	ret

zero_pressed:
	;skip if step 2
	clr char_buff
	clr lcd_temp

	;convert for step 1
	mov temp, Treg
	andi temp, 0b10000000
	cpi temp, 0b10000000
	breq set_stat_num

	jmp convert_lcd_num

star_pressed:
	jmp skip_keypress

letters:
	ldi temp2, 0b01000000
	and temp2, Treg
	cpi temp2, 0b10000000
	brne skip_keypress		; Letters are only valid in step 2

	; store key press for storage 
	ret

num_key: 
	mov lcd_temp, char_buff ; store number into output register

	; compare step to determine storage 
	mov temp, Treg
	andi temp, 0b10000000
	cpi temp, 0b10000000
	breq set_stat_num
		

convert_lcd_num:
	ori lcd_temp, 0b00110000
	jmp convert_end

skip_keypress:
	ret


convert_end:
	LDS temp, PINL
	mov flag, temp
	do_lcd_data lcd_temp
	inc n_chars

preserve: 
	rcall sleep_5ms
	lds temp, PINL
	cp temp, flag
	breq preserve
	ret

set_stat_num:
	ld_in_ptr xl, xh, stations	; retrieve number of stations from storage 
	ld temp, x 
	mul_by_10 temp				; multiply previous stored number by ten
	add temp, char_buff			; add current number and compare with 10
	cpi temp, 11
	brlo store_stat_max
	clr temp					; if over ten, store only the last digit entered from char_buff
	mov temp, char_buff	 
store_stat_max:
	mov char_buff, temp
	st x, char_buff
	out PORTC, char_buff
	jmp convert_lcd_num

Timer0OVF:
	
	
; display to read the number of stations
step_1:
	do_lcd_command 0b1		; clear display
	andi Treg, 0b00000111	; set flag for inputting number of stations 
	ori Treg, 0b10000000
	
	do_lcd_data_l 'M'
	do_lcd_data_l 'A'
	do_lcd_data_l 'X'
	do_lcd_data_l ' '
	do_lcd_data_l 'S'
	do_lcd_data_l 'T'
	do_lcd_data_l 'A'
	do_lcd_data_l 'T'
	do_lcd_data_l 'I'
	do_lcd_data_l 'O'
	do_lcd_data_l 'N'
	do_lcd_data_l 'S'
	ldi n_chars, 16
	rcall next_or_clear
	do_lcd_data_l '-'
	do_lcd_data_l '>'
	subi n_chars, -2
	ret

; read the names of each station
step_2:
	do_lcd_command 0b1		; clear display
	andi Treg, 0b00000111	; set flag for inputting names 
	ori Treg, 0b01000000
	
	do_lcd_data_l 'S'
	do_lcd_data_l 'T'
	do_lcd_data_l 'A'
	do_lcd_data_l 'T'
	do_lcd_data_l 'I'
	do_lcd_data_l 'O'
	do_lcd_data_l 'N'
	do_lcd_data_l ' '

	;output station name you are getting 
	mov temp, current_station
	ori temp, 48
	do_lcd_data temp 

	do_lcd_data_l ' '
	do_lcd_data_l 'N'
	do_lcd_data_l 'A'
	do_lcd_data_l 'M'
	do_lcd_data_l 'E'
	ldi n_chars, 16
	rcall next_or_clear
	do_lcd_data_l '-'
	do_lcd_data_l '>'
	subi n_chars, -2
	ret

next_step:
	check_step1 temp
	cpi temp, 0b10000000
	breq store_step1

	check_step2 temp
	cpi temp, 0b01000000

	check_step3 temp
	cpi temp, 0b00100000

	check_step4 temp
	cpi temp, 0b00010000


store_step1:
	ld_in_ptr xl, xh, stations
	ld temp, x
	cpi temp, 2
	brsh move_to_step_two
	ldi temp, 10
	st x, temp ; number of stations is less than 2, the max is entered 
move_to_step_two:
	ldi temp, 1
	mov current_station, temp	; step 2, enter the name of station 1
	rcall step_2;			; call step 2
	ret



; determines if to go onto next line or clear
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
