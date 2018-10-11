; Lab5B.asm
; Authors : Omar Al-Ouf & Ihor Balahan

.include "m2560def.inc"

;=========defining registers=========
.def temp = r16
.def speed = r17
.def number = r18
.def counter = r19
.def flag = r20
.def value = r21
.def input = r22
.def target = r23
.def holes4=r30

;==========LCD Commands==========
.set LCD_DISP_ON = 0b00001110
.set LCD_DISP_OFF = 0b00001000
.set LCD_DISP_CLR = 0b00000001

.set LCD_FUNC_SET = 0b00111000 						; 2 lines, 5 by 7 characters
.set LCD_ENTR_SET = 0b00000110 						; increment, no display shift
.set LCD_HOME_LINE = 0b10000000 					; goes to 1st line (address 0)
.set LCD_SEC_LINE = 0b10101000 						; goes to 2nd line (address 40)
;=================================

;Macro clears a word (2byte) in memory
;Note, @0 is the memory address for the word 
.macro clear
	ldi YL, low(@0)		; load the memory address to Y
	ldi YH, high(@0)
	clr temp
	st Y+, temp			; clear the two bytes at @0 in SRAM
	st Y, temp
.endmacro

;============LCD Output Macros===========
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

.macro do_lcd_char
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
;=========================================

;===========Words==========
.dseg
.org 0x0200
Zero:
	.byte 1
DebounceCounter:
	.byte 2
;==========Two-byte counter for counting second ==========  
TC:	
	.byte 2 

.cseg
.org 0x0000
	jmp RESET
.org INT0addr		;Jump to interrupt handler for Ext Int 1
	jmp PB_0		
.org INT1addr		; Jump to interrupt handler for Ext Int 1
	jmp PB_1
.org INT2addr		; Jump to interrupt handler for Ext Int 2
   jmp motor_speed

.org OVF0addr		; Jump to interrupt handler for Timer0 Overflow
	jmp Timer0OVF	; Jump to the interrupt handler for
	jmp DEFAULT		; default service for all other interrupts.

DEFAULT: reti		; no service
					; continued


RESET:
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

	ser temp					;Set temp to all 1's
	out DDRF, temp				;Port F = output
	out DDRA, temp				;Port A = output
	clr temp
	out PORTF, temp
	out PORTA, temp

	clear DebounceCounter			;Clear counters
	clear TC
	clr speed
	clr counter
	clr number
	clr value

	do_lcd_command LCD_FUNC_SET		;2x5x7
	rcall sleep_5ms
	do_lcd_command LCD_FUNC_SET		;2x5x7
	rcall sleep_1ms
	do_lcd_command LCD_FUNC_SET
	do_lcd_command LCD_FUNC_SET
	do_lcd_command LCD_DISP_OFF
	do_lcd_command LCD_DISP_CLR
	do_lcd_command LCD_ENTR_SET
	do_lcd_command LCD_DISP_ON
	rjmp main

main:
	clr input
	clr target
	ldi temp, (1<<PE4)		;labeled PE2 actually PE4 
	out DDRE, temp   		;output
	clr temp
;==========Timer 3==========
	;ldi temp,0x4A
	sts OCR3BL, temp		;Determine duty free
	clr temp
	sts OCR3BH, temp		
;=========Set Interrupt=========
	ldi temp, (1 << ISC21 | 1 << ISC11 | 1 << ISC01)      ; set INT2 as falling-edge 
    sts EICRA, temp             ; edge triggered interrupt
;=========Enable Interrupt=========
    in temp, EIMSK              ; enable INT2,INT1,INT0
    ori temp, (1<<INT2 | 1<<INT1 | 1<<INT0)
    out EIMSK, temp
;=========Set Timer Interrupt========
	ldi temp, (1<<WGM30)|(1<<COM3B1) ; set the Timer3 to Phase Correct PWM mode (8-bit) aka Mode1
	sts TCCR3A, temp 
	ldi temp, (1<<CS31)
	sts TCCR3B, temp		; Prescaling value=8
	clr temp
;==========Timer0=========
	out TCCR0A, temp		;Loading 0 into temp register
	ldi temp, (1<<CS01)
	out TCCR0B, temp		; Prescaling value=8
	ldi temp, 1<<TOIE0		; Enable Timeroverflow flag
	sts TIMSK0, temp	
	sts Zero, input			;Loading 0 into Zero register
	sei						; Enable global interrupt

loop:
	rjmp loop

;=========Interrupt 1=========
PB_0:
	cpi flag,0	; Check if the DebounceFlag is enabled
	breq IncreaseSpeed
	reti	
IncreaseSpeed:
	ldi flag,1
	cpi target, 100
	breq return1
	subi target,-20			;Increasing 20 for target value
return0:
	reti
;==========Interrupt 2=========
PB_1:
	cpi flag,0	; Check if the DebounceFlag is enabled
	breq DecreaseSpeed
	reti
DecreaseSpeed:
	ldi flag,1
	cpi target, 0
	breq return0
	subi target,20	;Decreasing 20 for target value
return1:
	reti

Timer0OVF:
	in temp, SREG
	push temp			; Prologue starts.
	push YH				; Save all conflict registers in the prologue.
	push YL
	push r25
	push r24
;==========Update Debounce Flag===========
	lds R24,DebounceCounter
	lds R25,DebounceCounter+1
	adiw r25:r24,1 
	cpi r24, low(2200)		;Set the debounce
	ldi temp,high(2200)
	cpc r25, temp
	breq SetDebounceFlag
	sts DebounceCounter,r24
	sts DebounceCounter+1,r25
	rjmp TimeCounter

SetDebounceFlag:
	clear DebounceCounter
	clr flag

TimeCounter:
	lds r24, TC
	lds r25, TC+1 
	adiw r25:r24, 1
	cpi r25, high(2210)
	ldi temp, low(2210)
	cpc r24, temp
	brne NotaSecond
	
;==========Update The Speed============
	cpi target, 0
	brne continue
	clr input
	sts OCR3BL, input
	rjmp UpdateTime
	
continue:
	cp speed, target
	breq UpdateTime
	lds input, OCR3BL
	cp speed, target
	brsh decrease
	cpi input, 255
	breq UpdateTime
	subi input, -3
	sts OCR3BL, input
	rjmp UpdateTime
	
decrease:
	cpi input, 0
	breq UpdateTime
	subi input, 3
	sts OCR3BL, input
	
UpdateTime:
	clear TC
	rcall UpdateSpeed
	rjmp Endif

NotaSecond:
	sts TC, r24
	sts TC+1, r25

Endif:
	pop	r24
	pop	r25
	pop	YL
	pop	YH
	pop	temp
	out SREG, temp
	reti

;========= Completing the Display=========
UpdateSpeed:
	do_lcd_command LCD_DISP_CLR
	do_lcd_command LCD_HOME_LINE
	mov speed, target
	do_lcd_char 'T'
	do_lcd_char 'a'
	do_lcd_char 'r'
	do_lcd_char 'g'
	do_lcd_char 'e'
	do_lcd_char 't'
	do_lcd_char ':'
	do_lcd_char ' '
	rcall display
	do_lcd_command LCD_SEC_LINE
	ldi temp,3
	mul value,temp
	mov speed, r0
	clr value
	do_lcd_char 'S'
	do_lcd_char 'p'
	do_lcd_char 'e'
	do_lcd_char 'e'
	do_lcd_char 'd'
	do_lcd_char ':'
	do_lcd_char ' '
	rcall display
	ret

;========== Displaying the numbers=========
display:
	push speed
Dloop:
	cpi speed, 100
	brsh hunderd
	cpi speed, 10
	brsh ten
	lds temp, Zero
	clr number
	sts Zero, number
	cpi temp, 1
	brne go
	do_lcd_char '0'
go:
	subi speed, -'0'
	do_lcd_data speed
return:
	pop speed
	ret
hunderd:
	ldi temp, 1
	sts Zero, temp
	ldi counter, 100
Hloop:
	dec speed
	dec counter
	cpi counter, 0
	brne Hloop
	inc number
	cpi speed, 100
	brlo showNumber
	rjmp Dloop

ten:
	clr temp
	sts Zero, temp
	ldi counter, 10
Tloop:
	dec speed
	dec counter
	cpi counter, 0
	brne Tloop
	inc number
	cpi speed, 10
	brlo showNumber
	rjmp Dloop

showNumber:
	subi number, -'0'
	do_lcd_data number
	clr number
	rjmp Dloop

;=========Counting the number of revolutions=========
inccount:
	inc value				;Holds the number of times it does a full revolution
	clr holes4
	jmp back

motor_speed:
	in temp, SREG
	push temp
	inc holes4
	cpi holes4,4
	breq inccount
	back:
	pop temp
	out SREG, temp
	reti
	
;==========LCD Display Code Below (Note r16)==========
; Delay Constants
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4 				; 4 cycles per iteration - setup/call-return overhead

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

lcd_command:
	out PORTF, r16
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:
	out PORTF, r16
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret

lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in r16, PINF
	lcd_clr LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	out DDRF, r16
	pop r16
	ret

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
