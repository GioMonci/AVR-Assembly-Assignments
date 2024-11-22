;
; blink_rate.asm
;
; Created: 11/19/2024
; Author : GM
; Description: a program that slows and accelerates
; an LED's blink delay based on which button you press.
; --------------------------------------------------

.equ StartBlink = 10                    ; how many timer interrupts per blink

.equ LedDirR = DDRB
.equ LedPort = PORTB
.equ LedPinR = PINB
.equ LedPin  = PB1

.equ BtnDirR = DDRD
.equ BtnPort = PORTD
.equ SlowPin = PD2
.equ FastPin = PD3

.def trmFlag = r18

.def blinkRate = r19
.def blinkCntr = r21

; Vector Table
; --------------------------------------------------
.org 0x0000                             ; Reset
          jmp       main

.org INT0addr                           ; External Interrupt Request 0
          jmp       slowButtonISR


.org INT1addr                           ; External Interrupt Request 1
          jmp       fastButtonISR


.org OVF1addr
          jmp       timer1ISR           ; Timer/Counter1 Overflow

.org INT_VECTORS_SIZE                   ; End Vector Table


; main()
; --------------------------------------------------
main:
          ; one time configruation

          ; initialize stack pointer
          ldi       r16,HIGH(RAMEND)
          out       SPH,r16
          ldi       r16,LOW(RAMEND)
          out       SPL,r16

          /** LED GPIO **/              
          sbi       LedDirR, LedPin     ; configure LED GPIO pin for output
          call      setup_buttons

          call      setup_tm1           ; initialize timer

          ldi       blinkRate,StartBlink; set starting blink rate
          mov       blinkCntr,blinkRate ; initialize blink counter

          sei                           ; enable global interrupts

main_lp:                                ; loop() {

          tst       trmFlag             ; if (!trmFlag) see if zero
          breq      timer_flag_end      ;   continue // if z flag is one then we branch, if not then we stay in
                                        ; else
	tst       blinkCntr 	; if (!blinkCntr)
          breq      blink_led 	;   blink LED
                                        ; else
          dec       blinkCntr           ;  blinkCntr--
          rjmp      timer_flag_end      ;  continue

blink_led:
          call      toggle_led          ; toggle the LED
          mov       blinkCntr,blinkRate ; reset blink counter
                                        ; then
timer_flag_end:
          clr       trmFlag             ; trmFlag = false

main_lp_end:
          rjmp      main_lp             ; } // loop


; initialize the fast/slow buttons
; --------------------------------------------------
setup_buttons:

          ; setup slow button         
          cbi       BtnDirR,SlowPin     ; set slow button to input
          cbi       BtnPort,SlowPin     ; set high-impedance

          ; setup fast button         
          cbi       BtnDirR,FastPin    ; set fast button to input
	sbi       BtnPort,FastPin    ; set pull-up
                                        


          ; enable slow & fast     	
          sbi       EIMSK,INT0          ; enable slow button interrupt
	sbi       EIMSK,INT1	; enable Fast button interrupt

                    ; enable rising-edge trigger
          ldi       r20,(1<<ISC01)|(1<<ISC00)

                    ; enable falling-edge trigger
          ori       r20,(1<<ISC11)|(0<<ISC10)

          sts       EICRA,r20

          ret


; 100ms counter
; --------------------------------------------------
setup_tm1:                              ; {
          ; set counter
          ldi       r20,HIGH(40536)     ; 100ms
          sts       TCNT1H,r20
          ldi       r20,LOW(40536)
          sts       TCNT1L,r20

          ; config control registers
          clr       r20
          sts       TCCR1A,r20          ; normal mode

          ; set clk/64
          ldi       r20,(1<<CS11) | (1<<CS10)
          sts       TCCR1B,r20          ; normal mode & clk

          ldi       r20,(1<<TOIE1)      ; enable TOV1 interrupt
          sts       TIMSK1,r20

          ret                           ; }


; toggle state of the LED
; --------------------------------------------------
toggle_led:
          sbis      LedPinR,LedPin      ; if (LED on goto OFF)
          rjmp      led_on              ; when button pressed
          rjmp      led_off             ; when button not pressed


led_on:
          sbi       LedPort,LedPin           ; turn led on
          rjmp      led_end

led_off:
          cbi       LedPort,LedPin           ; turn led off
led_end:
          ret


; interrupt service routine to handle button interrrupts
; to speed up the blink rate of the LED
; --------------------------------------------------
fastButtonISR:

           ldi      r16,1
           cp       blinkRate,R16       ; if (rate == 1)
           breq     fastButtonRet       ; return

           dec       blinkRate          ; make blink happen faster (less timer iterations)

fastButtonRet:
          reti                          ; return from interrupt


; interrupt service routine to handle button interrrupts
; to slow down the blink rate of the LED
; --------------------------------------------------
slowButtonISR:

          inc        blinkRate          ; make blink happen slower (more timer iterations)

          reti                          ; return from interrupt


; interrupt service routine to handle timer1 interrrupts
; --------------------------------------------------
timer1ISR:

          ldi       trmFlag, 1          ; timerFlag = true

          ; reset counter
          ldi       r20,HIGH(40536)     ; 100ms
          sts       TCNT1H,r20
          ldi       r20,LOW(40536)
          sts       TCNT1L,r20

          reti