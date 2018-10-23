;
; Project_final.asm
;
; Created: 10/21/2018 1:35:56 PM
; Author : balabi
;

.include "m2560def.inc" 

.def sec_left = r6
.def temp_counter = r7
.def max_stations = r8	; used in emulator mode to hold maximum number of stations 
.def shift = r9			; used in step 2 to store the shift of the number for outputting letters 
.def n_length = r10		; used as a buffer to store current length of name and length of time stop 
.def stop_time = r11		; used for storing stop times between stations 
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
.def NPL = r24
.def NPH = r25			; low and high bytes to store current address of counter 


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
st Y+, temp
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
	and @0, Treg
.endmacro

.macro check_step2
	ldi @0, 0b01000000
	and @0, Treg
.endmacro

.macro check_step3
	ldi @0, 0b00100000
	and @0, Treg
.endmacro

.macro check_step4
	ldi @0, 0b00010000
	and @0, Treg
.endmacro

.macro check_emulator
	ldi @0, 0b00001000
	and @0, Treg
.endmacro

.macro check_motor_running
	ldi @0, 0b00000010
	and @0, Treg
.endmacro

.macro check_hash_pressed
	ldi @0, 0b00000100
	and @0, Treg
.endmacro

.macro check_next_stop
	ldi @0, 0b00000001
	and @0, Treg
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
stat_times: .byte 10			; 10 bytes to store transfer time for each station
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
	ldi temp,0
	sts OCR3BL, temp	; low register
	clr temp
	sts OCR3BH, temp	; high register
	ldi temp, (1<<CS30)	; no prescaling (CS30 = 1)
	sts TCCR3B, temp
	ldi temp, (1<<WGM30)|(1<<COM3B1)	; phase correct PWM, 8 bits, override port function of PE2
	sts  TCCR3A,temp
	sei
	clr temp
	out DDRD, temp		; set external interrupt 
	out PORTD, temp
	ldi temp, (2<<ISC10) | (2<<ISC00) ; set falling edge
	sts EICRA, temp
	in temp, EIMSK
	ori temp, (1<<INT0) |(1<<INT1)
	out EIMSK, temp
	sei

	; clear all registers 
	clear_ptr TC
	clr sec_left
	clr char_buff
	clr stop_time
	clr shift
	clr n_length
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
	check_emulator temp
	cpi temp, 0
	breq not_running0	; pb0 pressed during other step 1-5

	ori Treg, 0b1		; set stop at next station flag 
not_running0: 
	pop temp 
	out SREG, temp 
	pop temp 
	reti 

;external interupt1
PB_1: 
	push temp 
	in temp, SREG 
	push temp 
	check_emulator temp
	cpi temp, 0
	breq not_running1	; pb0 pressed during other step 1-5
	ori Treg, 0b1		; set stop at next station flag
not_running1:
	pop temp 
	out SREG, temp 
	pop temp 
	reti 

;Timer0 interrupt
Timer0OVF:
	in temp, SREG
	push temp
	push YH
	push YL
	push NPH
	push NPL

	lds NPL, TC
	lds NPH, TC+1
	adiw NPH:NPL, 1

	; check if emulator running, if the motor is stopped, blink the lights 
	check_emulator temp
	cpi temp, 0b00001000
	brne continue_time_check	; emulator not running
	check_motor_running temp
	cpi temp, 0b00000010
	breq continue_time_check	; motor running, dont blink lights 
	; motor off blink lights 
	cpi NPL, low(1)
	ldi temp, high(1)
	cpc NPH, temp
	breq blink

	cpi NPL, low(20)
	ldi temp, high(20)
	cpc NPH, temp
	breq blink

	cpi NPL, low(40)
	ldi temp, high(40)
	cpc NPH, temp
	breq blink 
	rjmp continue_time_check

blink:
	ldi temp,0b00000011
	out PORTC, temp
	rcall sleep_5ms
	jmp continue_time_check
	

continue_time_check:
	clr temp
	out PORTC, temp

	cpi NPL, low(61)
	ldi temp, high(61)
	cpc NPH, temp
	brne Not_a_second

	check_hash_pressed temp
	cpi temp, 0b00000100
	breq stopped_end
	
	check_emulator temp
	cpi temp, 0
	brne emulator_running
	inc temp_counter	; used for the transition from config to emulate
	jmp stopped_end

emulator_running:
	check_motor_running temp
	cpi temp, 0b00000010
	brne stopped		; motor not running, check stop time
	; motor running, decrement time to next station
	ldi temp, 1
	sub sec_left, temp
	cp sec_left, temp	
	brge stopped_end
	ldi temp, 0xFF		; flag next station
	mov shift, temp		; shift used as a flag register
	
	; check for stop at next station
	check_next_stop temp
	cpi temp, 0b1
	brne stopped_end		
	; person wants to get off
	rcall stop_now		; stop motor as time was reached
	mov temp_counter, stop_time
	andi Treg, 0b11111100		; clear stop at next station and motor running bit
	
stopped: 
	ldi temp, 1
	sub temp_counter, temp
	clr temp
	cp temp_counter, temp
	brge stopped_end
	rcall start_now		; restarts engine if stopped time is complete

stopped_end:
	clear_ptr TC
	rjmp END_T0OVF

Not_a_second:
	sts TC, NPL
	sts TC+1, NPH

End_T0OVF:
	pop NPl
	pop NPH
	pop YL
	pop YH
	pop temp
	reti

; scans keyboard to see what key is pressed
main:
	rcall next_or_clear		; see if to move to next line
	rcall sleep_5ms
	rcall sleep_5ms

	;check for a flag to print next station and update travel time
	check_emulator temp
	cpi temp, 0b00001000
	brne s_start
	ldi temp, 0xFF
	cp shift, temp
	brne s_start
	rcall print_station


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

; relative branch out of reach
to_letters:
	jmp letters
to_num_key:
	jmp num_key


; convert function converts the row and column given to a
; binary number and also outputs the value to PORTC.
; Inputs come from registers row and col and output is in
; temp.
convert:
	cpi col, 3 ; if column is 3 we have a letter
	breq to_letters
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

	check_step2 temp
	cpi temp, 0b01000000
	brne to_num_key

	;step 2 check, makes sure there is a shift
	ldi temp, 0
	cp shift, temp
	breq no_valid_input

	; processing for step 2
	mov temp, char_buff
	cpi temp, 1
	breq no_valid_input	; one is pressed, not valid

	ldi temp, 4
	cp shift, temp 
	brlo convert_to_letter		
	; check for shift on keys 7, 9
	ldi temp, 7					
	cp char_buff, temp
	breq convert_to_letter
	ldi temp, 9
	cp char_buff, temp
	breq convert_to_letter
	jmp no_valid_input	; not valid letter pressed


; converts the shift and number to a character for storing station name 
convert_to_letter: 
	ldi temp, 10
	cp n_length, temp
	brlo continue_conversion
	jmp skip_keypress		; name limit reached, ignore letter 
	
continue_conversion:	
	inc n_length			; character accepted, increment the count  

	; conversion of number to keypad letter
	mov temp, char_buff 
	subi temp, 2
	mov temp2, temp
	lsl temp2
	add temp, temp2
	add temp, shift

	; check for 4 letter keys being entered
	; 8 is shifted instead of seven due to the 'S' 
	ldi temp2, 8	
	cp char_buff, temp2
	brne next_check_
	inc temp
next_check_:
	ldi temp2, 9
	cp char_buff, temp2
	brne end_key_converstion
	inc temp

end_key_converstion:
	mov char_buff, temp
	jmp convert_key

no_valid_input:
	jmp skip_keypress
	
symbols:
	cpi col, 0		; star is pressed
	breq star_pressed
	cpi col,1		; zero pressed
	breq zero_pressed

;hash pressed, next instruction
	rcall sleep_100ms
	rcall next_step
	rcall sleep_100ms
	ret

zero_pressed:
	clr char_buff
	clr lcd_temp

	;convert for step 1
	check_step1 temp
	cpi temp, 0b10000000
	breq set_stat_num_

	;convert for step 3
	check_step3 temp
	cpi temp, 0b00100000
	breq set_stat_time_

	;convert for step 4
	check_step4 temp
	cpi temp, 0b00010000
	breq set_stop_time_

	; step 2 or emulator running, skip key press 
	jmp skip_keypress

star_pressed:
	check_step2 temp
	cpi temp, 0b01000000
	brne skip_keypress		; star only input during step 2 (space)

	ldi temp, 10			; limit reached
	cp n_length, temp
	brlo store_space
	jmp skip_keypress

store_space:
	; convert star to space
	ldi temp, 32
	mov lcd_temp, temp
	st z+, lcd_temp
	inc n_length
	jmp convert_end

letters:
	ldi temp2, 0b01000000
	and temp2, Treg
	cpi temp2, 0b01000000
	brne skip_keypress		; Letters are only valid in step 2

	mov shift, row
	inc shift				; increment the row number to get the shift amount 
	out PORTC, shift
	ret

;relative branches out of reach
set_stat_num_:
	jmp set_stat_time
set_stat_time_:
	jmp set_stat_time
set_stop_time_:
	jmp set_stop_time

num_key: 
	mov lcd_temp, char_buff ; store number into output register
	
	;step 1 
	check_step1 temp
	cpi temp, 0b10000000
	breq set_stat_num		; step 1, stores max stations

	;step 3				
	check_step3 temp
	cpi temp, 0b00100000
	breq set_stat_time		; stores station transit time 

	;step 4 check
	check_step4 temp		; stores station stop time
	cpi temp, 0b00010000
	breq set_stop_time_

	jmp skip_keypress		; number is pressed during step two or emulator, ignore

convert_key:
	mov temp, char_buff
	ori temp, 0b01000000			; convert to ASCII 
	mov lcd_temp, temp
	st z+, lcd_temp			; store station name in memory for emulator 
	jmp convert_end

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



;sets maximum number of stations 
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
	jmp convert_lcd_num 

;sets time between two stations 
set_stat_time:
	inc n_length			
	ldi temp2, 2
	mov temp, char_buff
	cp n_length, temp2		; sees if a number was previously stored
	brlo store_station_time
	ld temp, z	
	mul_by_10 temp
	add temp, char_buff
	cpi temp, 11
	brlo store_station_time					
	mov temp, char_buff	 
store_station_time:		; if over ten, store only the last digit entered from char_buff
	mov char_buff, temp
	st z, char_buff
	jmp convert_lcd_num 

;sets the stop time
set_stop_time:
	mov temp, char_buff
	cpi temp, 2
	brsh next_check
	ldi temp, 2
	mov char_buff, temp
	rjmp store_stop_time


next_check:
	cpi temp, 6
	brlo store_stop_time
	ldi temp, 5
	mov char_buff, temp
	
store_stop_time:
	inc n_length
	mov stop_time, char_buff
	jmp convert_lcd_num

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
	cpi temp, 10			; cases with 10 stations
	brlo output_number
	do_lcd_data_l '1'
	do_lcd_data_l '0'		; 10 is the max station
	rjmp step_2_continue
output_number:
	ori temp, 0b00110000
	do_lcd_data temp 

step_2_continue:
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
	rcall sleep_100ms
	ret

; step to get travel times between stations
step_3:
	do_lcd_command 0b1		; clear display
	andi Treg, 0b00000111	; set flag for inputting travel times 
	ori Treg, 0b00100000

	do_lcd_data_l 'S'
	do_lcd_data_l 'T' 
 
	mov temp, current_station
	cpi temp, 10			; cases with 10 stations
	brlo output_number_1
	do_lcd_data_l '1'
	do_lcd_data_l '0'		; 10 is the max station
	rjmp step_3_continue1
output_number_1:
	ori temp, 0b00110000
	do_lcd_data temp
	inc current_station

step_3_continue1:
	do_lcd_data_l ' '
	do_lcd_data_l 'T'
	do_lcd_data_l 'O'
	do_lcd_data_l ' '
	do_lcd_data_l 'S'
	do_lcd_data_l 'T'
	
	mov temp, current_station
	cpi temp, 10			; cases with 10 stations
	brlo output_number_2
	do_lcd_data_l '1'
	do_lcd_data_l '0'		; 10 is the max station
	rjmp step_3_continue2
output_number_2:
	ori temp, 0b00110000
	do_lcd_data temp

step_3_continue2:
	do_lcd_data_l ' '
	do_lcd_data_l 'T'
	do_lcd_data_l 'I'
	do_lcd_data_l 'M'
	do_lcd_data_l 'E'
	ldi n_chars, 16
	rcall next_or_clear
	do_lcd_data_l '-'
	do_lcd_data_l '>'
	subi n_chars, -2
	rcall sleep_100ms
	ret

step_4:	
	do_lcd_command 0b1		; clear display
	andi Treg, 0b00000111	; set flag for inputting travel times 
	ori Treg, 0b00010000	

	do_lcd_data_l 'M'
	do_lcd_data_l 'R'
	do_lcd_data_l 'A'
	do_lcd_data_l 'I'
	do_lcd_data_l 'L'
	do_lcd_data_l ' '
	do_lcd_data_l 'S'
	do_lcd_data_l 'T'
	do_lcd_data_l 'O'
	do_lcd_data_l 'P'
	do_lcd_data_l ' '
	do_lcd_data_l 'T'
	do_lcd_data_l 'I'
	do_lcd_data_l 'M'
	do_lcd_data_l 'E'
	ldi n_chars, 16
	rcall next_or_clear
	do_lcd_data_l '-'
	do_lcd_data_l '>'
	subi n_chars, -2
	rcall sleep_100ms
	ret

; configuration complete!
step_5:
	do_lcd_command 0b1		; clear display
	clr Treg	; clear instruction flags

	do_lcd_data_l 'C'
	do_lcd_data_l 'O'
	do_lcd_data_l 'N'
	do_lcd_data_l 'F'
	do_lcd_data_l 'I'
	do_lcd_data_l 'G'
	do_lcd_data_l ' '
	do_lcd_data_l 'C'
	do_lcd_data_l 'O'
	do_lcd_data_l 'M'
	do_lcd_data_l 'P'
	do_lcd_data_l 'L'
	do_lcd_data_l 'E'
	do_lcd_data_l 'T'
	do_lcd_data_l 'E'
	ldi n_chars, 16
	rcall next_or_clear
	do_lcd_data_l 'W'
	do_lcd_data_l 'A'
	do_lcd_data_l 'I'
	do_lcd_data_l 'T'
	do_lcd_data_l '.'
	do_lcd_data_l '.'
	do_lcd_data_l '.'
	subi n_chars, -4

	; load proper pointers
	ld_in_ptr xl, xh, stations			; load max number of station
	ld temp, x
	mov max_stations, temp
	ldi temp, 2
	mov current_station, temp
	ld_in_ptr NPL, NPH, stat_times		; NP holds address to stop times
	mov r3, NPL
	mov r4, NPH
	ld_in_ptr xl, xh, stat_names		; x holds pointer to station names
	ld_in_ptr zl, zh, stat_char_nums	; z holds pointer to name lengths

	;get pointer to point to station 2
	ld temp, z+
	clr shift
	clr temp2
	add xl, temp
	adc xh, temp2	; gets station name of next station
	clr sec_left
	clr temp_counter

;enable timer0
start_timer0:
	clr temp
	out TCCR0A, temp
	ldi temp, 0b00000101
	out TCCR0B, temp	; set prescalar value to 1024
	ldi temp, (1<<TOIE0)
	sts TIMSK0, temp	; enable overflow interrupt
	sei

; 5 second loop buffer for emulator start
loop_start:
	ldi temp, 5
	cp temp_counter, temp
	brsh end
	rjmp loop_start

end:
	ori TREG, 0b00001000	; set emulator running flag
	rcall start_now			; start motor
	rcall print_station
	ret

; displays next station on screen
print_station:
	; next station print
	do_lcd_command 0b01
	do_lcd_command 0b00001100 ; no cursor, no bar, no blink

	do_lcd_data_l 'N'
	do_lcd_data_l 'E'
	do_lcd_data_l 'X'
	do_lcd_data_l 'T'
	do_lcd_data_l ' '
	do_lcd_data_l 'S'
	do_lcd_data_l 'T'
	do_lcd_data_l 'A'
	do_lcd_data_l 'T'
	do_lcd_data_l 'I'
	do_lcd_data_l 'O'
	do_lcd_data_l 'N'
	ldi n_chars, 16
	rcall next_or_clear

	; check for last station
	mov temp, max_stations
	cp max_stations, current_station
	brge contine_printing
	ldi temp, 1
	mov current_station, temp			; get station 1
	ld_in_ptr zl, zh, stat_char_nums	; get number of characters for station 1
	ld_in_ptr xl, xh, stat_names		; get station 1 name


	; check for no input

	; load in important values
contine_printing:
	ld n_length, z+		; get length of name
	mov temp, zl
	mov temp2, zh
	mov zl, NPL
	mov zh, NPH
	ld sec_left, z+	; get stop time to next station
	mov NPL, zl
	mov NPH, zh
	mov zl, temp
	mov zh, temp2		; reset pointers to next point

	ldi temp, 1
	cp current_station, temp
	brne name_sendout_start
	ld_in_ptr NPL, NPH, stat_times	; reset travel time between station
	 
name_sendout_start:
	ldi temp, 0
	cp n_length, temp
	breq no_chars			; no characters were typed 
	
	ld lcd_temp, x+
	rcall sleep_5ms
	do_lcd_data lcd_temp	; send out letter
	rcall sleep_5ms

	ldi temp,1
	sub n_length, temp		; subtract from characters remaining
	cp n_length, temp
	brsh name_sendout_start

before_end: 
	; do not start the motor if it was not running previously 
	check_motor_running temp
	cpi temp, 0
	breq end_print
	rcall start_now		; start_motor

end_print:
	inc current_station
	clr shift
	ret

; handles cases where no letter was typed
no_chars:
	ldi temp, 10
	cp temp, current_station	; stations higher than ten
	breq print_10

	mov lcd_temp, current_station
	ori lcd_temp, 0b00110000
	do_lcd_data lcd_temp
	rcall sleep_5ms
	rjmp before_end

print_10:
	do_lcd_data_l '1'
	do_lcd_data_l '0'
	rjmp before_end
	

next_step:
	check_step1 temp
	cpi temp, 0b10000000
	breq store_step1

	check_step2 temp
	cpi temp, 0b01000000
	breq store_step2

	check_step3 temp
	cpi temp, 0b00100000
	breq store_step3

	check_step4 temp
	cpi temp, 0b00010000
	breq store_step_4

	check_emulator temp
	cpi temp, 0b00001000
	breq check_motor_stop
	ret
	

;stores step one 
store_step1:
	ld_in_ptr xl, xh, stations
	ld temp, x
	cpi temp, 2
	brsh move_to_step_two
	ldi temp, 10
	st x, temp ; number of stations is less than 2, the max is entered 
move_to_step_two:
	ldi temp, 1
	mov current_station, temp	; for step 2, enter the name of station 1
	clr n_length
	clr shift
	ld_in_ptr zl, zh, stat_names
	ld_in_ptr yl, yh, stat_char_nums		; load in the start of memory for station names and lengths 
	rcall step_2;			; call step 2
	ret


store_step_3:
	jmp store_step3
store_step_4:					;  relative jump out of reach
	jmp store_step4
check_motor_stop:
	jmp motor_stop


;store station name and move to step 3 if last station 
store_step2:
	; store station name
	st y+, n_length
	clr n_length
	inc current_station
	ld_in_ptr xl, xh, stations
	ld temp, x
	inc temp
	cp current_station, temp
	breq move_to_step3			; last station stored
	rcall step_2
	ret
move_to_step3:
	clr n_length
	ld_in_ptr zl, zh, stat_times			; z pointer holds the current between station time position 

	ldi temp, 1					; set station back to one 
	mov current_station, temp
	clr temp
	out PORTC, temp
	rcall step_3
	ret

;called to store the distance between two stations and move to step 4
store_step3:
	ldi temp, 1			; check for typed number 
	cp n_length, temp
	brsh zero_check	
	;hash is pressed without a number being typed, defaults to 5 second
	ldi temp, 5
	st z, temp
	rjmp increment_ptr

zero_check:				; check to see if zero is the value in the char buffer
	ld temp, z
	cpi temp, 0	
	brne increment_ptr
	; zero is the last number entered, defaults time to 1 sec
	ldi temp, 1
	st z, temp

increment_ptr:  
	ld temp, z
	
	ldi temp, 1		; increment to next position 
	add zl, temp
	clr temp
	adc zh, temp
	; store travel time 

	ld_in_ptr xl, xh, stations
	ld temp, x
	cp temp, current_station
	breq last_stop_time
	mov temp, current_station			; moves to step 4 after last travel time is stored
	cpi temp, 1
	breq move_to_step4
	rcall step_3
	ret

last_stop_time: 
	do_lcd_command 0b1		; clear display

	do_lcd_data_l 'S'
	do_lcd_data_l 'T'
	
	mov temp, current_station
	cpi temp, 10			; cases with 10 stations
	brlo output_number_l
	do_lcd_data_l '1'
	do_lcd_data_l '0'		; 10 is the max station
	rjmp lst_contd
output_number_l:
	ori temp, 0b00110000
	do_lcd_data temp

lst_contd:
	ldi temp, 1					; last station is one
	mov current_station, temp
	rcall step_3_continue1
	ret

move_to_step4:
	clr n_length	
	ldi temp, 1		; goes back to station one for emulation 
	mov current_station, temp
	rcall step_4
	ret

; completes step 4
store_step4:
	;check for proper input 
	clr temp
	ldi temp2, 5
	cp temp, n_length
	brne move_to_step5		; a number was entered
	mov stop_time, temp2

move_to_step5:
	rcall step_5
	ret 

motor_stop:
	check_hash_pressed temp
	cpi temp, 0b00000100
	breq start_motor		; second hash press in emulator, ignore 
	; stop motor
	rcall stop_now
	andi Treg, 0b00001101
	ori Treg, 0b00001100	; set hash pressed flag 
	ret 
start_motor:
	rcall start_now
	andi treg, 0b00001011	; set flag 
	ret


	; starts motor
start_now:
	ori Treg, 0b00000010
	ldi temp, 60
	sts OCR3BL, temp
	ret

; stops motor
stop_now:
	andi Treg, 0b00001101
	ldi temp, 0
	sts OCR3BL, temp
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

sleep_50ms:
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	ret

sleep_100ms:
	rcall sleep_50ms
	rcall sleep_50ms
	ret

sleep_500ms:
	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms
	ret

sleep_1s:
	rcall sleep_500ms
	rcall sleep_500ms
	ret