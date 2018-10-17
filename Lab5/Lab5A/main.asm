; Lab5A.asm
; Authors : Omar Al-Ouf & Ihor Balahan

.include "m2560def.inc"
 .def temp = r16
 .def holes = r20
 .def mask = r19
 .equ START_TIME = 0b00000000 ; 0b11011111
 .def d_5 = r13
 .def d_4 = r12
 .def d_3 = r11
 .def d_2 = r10
 .def d_1 = r9
 .def result_high = r18
 .def result_low = r17
 
 ; The detector can be read by using an external interrupt
 ; The detector will output a 1 when there isn’t a hole, 
 ; so you can use the falling edge of the detector to trigger 
 ; an interrupt to count a hole.

 ; The macro clears a word (2 bytes) in the data memory
 ; The parameter @0 is the memory address for that word
 .macro clear_2
 ldi YL, low(@0) ; load the memory address to Y pointer
 ldi YH, high(@0)
 clr temp ; set temp to 0
 st Y+, temp ; clear the two bytes at @0 in SRAM
 st Y, temp
 .endmacro
 
 .macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data
	ldi r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro display
	rcall lcd_data
	rcall lcd_wait
.endmacro


.dseg
SecondCounter: .byte 2 ; two-byte counter for counting seconds.
TempCounter: .byte 2 ; temporary counter used to determine if one second has passed
RevCounter: .byte 2 ; revolution counter
.cseg
.org 0x0000
 
jmp RESET
jmp DEFAULT ; no handling for IRQ0.
jmp DEFAULT ; no handling for IRQ1.
.org INT2addr ; 
jmp EXT_INT2
.org OVF0addr ; OVF0addr is the address of Timer0 Overflow Interrupt Vector
jmp Timer0OVF ; jump to the interrupt handler for Timer0 overflow.
jmp DEFAULT ; default service for all other interrupts.
DEFAULT: reti ; no interrupt handling 
 
RESET: 
/*ldi secd, 0
ldi mins, 0*/
ldi temp, high(RAMEND) ; initialize the stack pointer SP
out SPH, temp
ldi temp, low(RAMEND)
out SPL, temp
/*ser temp ; set Port C as output
out DDRC, temp*/
clr r16
out DDRD, r16
out PORTD, temp
ldi temp, (2 << ISC20) 
sts EICRA, temp
in temp, EIMSK
ori temp, (1<<INT2)
out EIMSK, temp
sei
ser r16
out DDRF, r16
out DDRA, r16
clr r16
out PORTF, r16
out PORTA, r16

do_lcd_command 0b00111000 ; 2x5x7
rcall sleep_5ms
do_lcd_command 0b00111000 ; 2x5x7
rcall sleep_1ms
do_lcd_command 0b00111000 ; 2x5x7
do_lcd_command 0b00111000 ; 2x5x7
do_lcd_command 0b00001000 ; display off?
do_lcd_command 0b00000001 ; clear display
do_lcd_command 0b00000110 ; increment, no display shift
do_lcd_command 0b00001110 ; Cursor on, bar, no blink

do_lcd_data 'S'
do_lcd_data 'p'
do_lcd_data 'e'
do_lcd_data 'e'
do_lcd_data 'd'
do_lcd_data ':'
do_lcd_data '0'
do_lcd_data '0'
do_lcd_data '0'
do_lcd_data '0'
do_lcd_data '0'

rjmp main ; jump to main program



EXT_INT2:
push temp
in temp, SREG
push temp
push r23
push r22
inc holes
cpi holes, 4
brne end
clr holes
lds r22, RevCounter
lds r23, RevCounter+1
ldi temp, 1
add r22, temp
ldi temp, 0
adc r23, temp
sts RevCounter, r22
sts RevCounter+1, r23
end:
pop r22
pop r23
pop temp
out SREG, temp
pop temp
reti



Timer0OVF: ; interrupt subroutine to Timer0
in temp, SREG
push temp ; prologue starts
push YH ; save all conflicting registers in the prologue
push YL
push r25
push r24 ; prologue ends
; Load the value of the temporary counter
lds r24, TempCounter
lds r25, TempCounter+1
adiw r25:r24, 1 ; increase the temporary counter by one
cpi r24, low(781) ; check if (r25:r24) = 7812
ldi temp, high(781) ; 7812 = 10^6/128
cpc r25, temp
brne NotSecond
 
rjmp one_tenth_second

one_tenth_second:
/*inc secd
cpi secd, 60
brne continue
ldi secd, 0
inc mins
continue:*/
jmp calculation
end_calculation:
ldi r22, 0
ldi r23, 0
sts RevCounter, r22
sts RevCounter+1, r23
/*ldi r16, 49
display*/
clear_2 TempCounter ; reset the temporary counter
; Load the value of the second counter
lds r24, SecondCounter
lds r25, SecondCounter+1
adiw r25:r24, 1 ; increase the second counter by one
sts SecondCounter, r24
sts SecondCounter+1, r25
rjmp EndIF
 
NotSecond: ; store the new value of the temporary counter
sts TempCounter, r24
sts TempCounter+1, r25
 
EndIF: pop r24 ; epilogue starts
pop r25 ; restore all conflicting registers from the stack
pop YL
pop YH
pop temp
out SREG, temp
reti ; return from the interrupt


main: 
clr holes
clear_2 TempCounter ; initialize the temporary counter to 0
clear_2 SecondCounter ; initialize the second counter to 0
ldi temp, 0b00000000
out TCCR0A, temp
ldi temp, 0b00000010
out TCCR0B, temp ; set prescalar value to 8
ldi temp, 1<<TOIE0 ; TOIE0 is the bit number of TOIE0 which is 0
sts TIMSK0, temp ; enable Timer0 Overflow Interrupt
sei ; enable global interrupt
end_loop: 
rjmp end_loop ; loop forever




.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro

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



calculation:
ldi temp, low(10000)
mov r3, temp
ldi temp, high(10000)
mov r4, temp
ldi temp, low(1000)
mov r5, temp
ldi temp, high(1000)
mov r6, temp
ldi temp, 100
mov r7, temp
ldi temp, 10
mov r8, temp
clr d_5
clr d_4
clr d_3
clr d_2
clr d_1

ldi r25, 0
lds temp, RevCounter
mov result_low, temp
lds temp, RevCounter+1
mov result_high, temp
clr temp
sts SecondCounter, temp
sts SecondCounter+1, temp
/*ldi r25, 0b11111111
mov result_low, r25
ldi r25, 0b111111
mov result_high, r25
ldi r25, 0*/

sub_ten_thousand:
sub result_low, r3
sbc result_high, r4
inc d_5
cp result_low, r25
cpc result_high, r25
brge sub_ten_thousand
add result_low, r3
adc result_high, r4
dec d_5

sub_thousand:
sub result_low, r5
sbc result_high, r6
inc d_4
cp result_low, r25
cpc result_high, r25
brge sub_thousand
add result_low, r5
adc result_high, r6
dec d_4

sub_hundred:
sub result_low, r7
sbc result_high, r25
inc d_3
cp result_low, r25
cpc result_high, r25
brge sub_hundred
add result_low, r7
adc result_high, r25
dec d_3

sub_ten:
sub result_low, r8
sbc result_high, r25
inc d_2
cp result_low, r25
cpc result_high, r25
brge sub_ten
add result_low, r8
adc result_high, r25
dec d_2

mov d_1, result_low



/*do_lcd_command 0b00111000 ; 2x5x7
rcall sleep_5ms
do_lcd_command 0b00111000 ; 2x5x7
rcall sleep_1ms
do_lcd_command 0b00111000 ; 2x5x7
do_lcd_command 0b00111000 ; 2x5x7
do_lcd_command 0b00001000 ; display off?*/
do_lcd_command 0b00000001 ; clear display
do_lcd_command 0b00000110 ; increment, no display shift
do_lcd_command 0b00001110 ; Cursor on, bar, no blink

do_lcd_data 'S'
do_lcd_data 'p'
do_lcd_data 'e'
do_lcd_data 'e'
do_lcd_data 'd'
do_lcd_data ':'

mov r16, d_5
ldi r27, 48
add r16, r27
display
mov r16, d_4
add r16, r27
display
ldi r27, 48
mov r16, d_3
add r16, r27
display
ldi r27, 48
mov r16, d_2
add r16, r27
display
ldi r27, 48
mov r16, d_1
add r16, r27
display

do_lcd_data '0'
do_lcd_data ' '
do_lcd_data 'r'
do_lcd_data '/'
do_lcd_data 's'
jmp end_calculation