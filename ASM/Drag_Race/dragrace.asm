;
; dragrace.asm
;
; Author : GM
; Game where the player has to press a button at just the right
; time as a sequence of lights similar to the Christmas tree at
; a drag race.  
; ------------------------------------------------------------

.equ TmDelay = 64911                        ; <<-- provide value for 10ms

.equ Stage1Led = PB3
.equ Stage2Led = PB2
.equ Stage3Led = PB1
.equ Stage4Led = PB0

.equ PlayerGrn = PD5
.equ PlayerRed = PD4

.equ BtnDirR = DDRD
.equ BtnPort = PORTD
.equ ButtonPin = PD2

; setup an array of counters for the color LEDs
.equ Stg1Cnt = 0x0100
.equ Stg2Cnt = 0x0101
.equ Stg3Cnt = 0x0102
.equ Stg4Cnt = 0x0103

.equ DelayCnt = 250

; enum for which light is being displayed
.equ Stage1 = 0
.equ Stage2 = 1
.equ Stage3 = 2
.equ Stage4 = 3
.equ DispPlayer = 4
.equ DispNone = 5

.def dispLight = r18                    ; dispLight  {Stage1=0, Stage2=1, Stage3=2, Stage4=3, Player=4}

.def dispCnt = r16                      ; current display counter
.def isUpdate = r17                     ; bool - if true then update display
.def playerHit = r23                    ; bool - true if player hit when Stage4 was on

; Vector Table
; ------------------------------------------------------------
.org 0x0000                             ; Reset
          jmp       main

.org INT0addr                           ; Player Interupt 
          jmp       playerISR

.org OVF1addr
          jmp       timer1ISR           ; Timer/Counter1 Overflow

.org INT_VECTORS_SIZE                   ; end Vector Table


; void main()
; ------------------------------------------------------------
main:
          call      gpioInit            ; initialize LEDs and button

          call      countersInit        ; setup starting timer counters
          
          call      timer1Init          ; setup the countdown timer

          sei                           ; enable global interrupts

mainLoop:
          tst       isUpdate            ; if (!isUpdate)
          breq      mainLoop            ;   continue
                                        ; else {
          clr       isUpdate            ;   isUpdate = false

          tst       dispCnt             ;   if (decCounter > 0)
          brne      mainDecrement       ;     goto decrement counter
                                        ;   else
          call      updateDisplay       ;     updateDisplay()
          rjmp      endMain             ;     continue

mainDecrement:
          dec       dispCnt             ; dispCnt-- 

endMain:
          rjmp      mainLoop            ; main


; void gpioInit()
; ------------------------------------------------------------
gpioInit:
          ; set christmas tree lights to output

          ; yellow
          sbi DDRB, DDB3
          sbi DDRB, DDB2
          sbi DDRB, DDB1
          ; green
          sbi DDRB, DDB0


          ; set good/bad indicator lights to output

         ; good
         sbi DDRD, DDD5       ; good light for output
         ; bad
         sbi DDRD, DDD4       ; bad light for output

          ; set player input button

         cbi        BtnDirR, ButtonPin  ; input
         sbi        BtnPort, ButtonPin  ; pull-up

         sbi        EIMSK, INT0         ; enble button interupt

         ldi        r20,0b00000010      ; mask 

         sts        EICRA,r20           ; falling edge

         ret                           ; gpioInit


; void countersInit()
; ------------------------------------------------------------
countersInit:
          ; Stage1 
          ldi       r16,100
          sts       Stg1Cnt,r16
          ; Stage2
          ldi       r16,75
          sts       Stg2Cnt,r16
          ; Stage3
          ldi       r16,50
          sts       Stg3Cnt,r16
          ; Stage4
          ldi       r16,25
          sts       Stg4Cnt,r16     

          ldi       dispLight,DispNone  ; initialize to no light
          ldi       dispCnt,DelayCnt    ; delay between runs

          clr       isUpdate            ; false

          ret                           ; countersInit

; void timer1Init()
; ------------------------------------------------------------
timer1Init:
          ; Initialize Timer1

          ; set counter
          ldi       r20,HIGH(TmDelay)     ; 10ms
          sts       TCNT1H,r20
          ldi       r20,LOW(TmDelay)
          sts       TCNT1L,r20

          ; config control registers
          clr       r20
          sts       TCCR1A,r20          ; normal mode

          ; set clk/64
          ldi       r20,(1<<CS11) | (1<<CS10)
          sts       TCCR1B,r20          ; normal mode & clk

          ldi       r20,(1<<TOIE1)      ; enable TOV1 interrupt
          sts       TIMSK1,r20
          ret                           ; timer1Init


; void updateDisplay()
; Uses
.def tempCnt = r19
; ------------------------------------------------------------
updateDisplay:

          inc       dispLight           ; next light

          cpi       dispLight,DispNone  ; if (dispLight < None)
          brlo      doUpdateDisp        ;  update next light
                                        ; else
          ldi       dispLight,Stage1    ;    set back to Stage1

doUpdateDisp:                           ; switch(dispLight) {                                        
          cpi       dispLight,Stage1    ;   case Stage1:
          breq      Stage1On            ;     turn on Stage1 Light
          cpi       dispLight,Stage2    ;   case Stage2:
          breq      Stage2On            ;     turn on Stage2 Light
          cpi       dispLight,Stage3    ;   case Stage3:
          breq      Stage3On            ;     turn on Stage3 Light
          cpi       dispLight,Stage4    ;   case Stage4:
          breq      Stage4On            ;     turn on Stage4 Light
          rjmp      PlayerOn            ;   default: // player

Stage1On:
          cbi       PortD,PlayerGrn     ; turn off Player Green light
          cbi       PortD,PlayerRed     ; turn off Player Red light
          sbi       PortB,Stage1Led     ; turn on Stage1 light
          lds       tempCnt,Stg1Cnt     ; load Stage1 timer value
          mov       dispCnt,tempCnt     ; copy timer to display counter
          tst       tempCnt             ; if (tempCnt == 0)
          breq      updtDispRet         ;    return
          dec       tempCnt             ; tempCnt--
          sts       Stg1Cnt,tempCnt     ; save new counter value
          rjmp      UpdtDispRet         ; break
Stage2On:
          cbi       PortB,Stage1Led     ; turn off Stage1 light
          sbi       PortB,Stage2Led     ; turn on Stage2 light
          lds       tempCnt,Stg2Cnt     ; load Stage1 timer value
          mov       dispCnt,tempCnt     ; copy timer to display counter
          tst       tempCnt             ; if (tempCnt == 0)
          breq      updtDispRet         ;    return
          dec       tempCnt             ; tempCnt--
          sts       Stg2Cnt,tempCnt     ; save new counter value
          rjmp      UpdtDispRet         ; break
Stage3On:
          cbi       PortB,Stage2Led     ; turn off Stage2 light
          sbi       PortB,Stage3Led     ; turn on Stage3 light
          lds       tempCnt,Stg3Cnt     ; load Stage1 timer value
          mov       dispCnt,tempCnt     ; copy timer to display counter
          tst       tempCnt             ; if (tempCnt == 0)
          breq      updtDispRet         ;    return
          dec       tempCnt             ; tempCnt--
          sts       Stg3Cnt,tempCnt     ; save new counter value
          rjmp      UpdtDispRet         ; break
Stage4On:
          cbi       PortB,Stage3Led     ; turn off Stage3 light
          sbi       PortB,Stage4Led     ; turn on Stage4 light
          lds       tempCnt,Stg4Cnt     ; load Stage1 timer value
          mov       dispCnt,tempCnt     ; copy timer to display counter
          tst       tempCnt             ; if (tempCnt == 0)
          breq      updtDispRet         ;    return
          dec       tempCnt             ; tempCnt--
          sts       Stg4Cnt,tempCnt     ; save new counter value
          rjmp      UpdtDispRet         ; break
PlayerOn:
          cbi       PortB,Stage4Led     ; turn off Stage4 light
          call      checkPlayer
                                        ; } // end switch
UpdtDispRet:
          ret                           ; updateDisplay


; void checkPlayer()
; ------------------------------------------------------------
checkPlayer:
          tst       playerHit           ; if (!playerHit)
          breq      PlayerBad           ;   goto bad
PlayerGood:                             ; else
          sbi       PortD,PlayerGrn     ;   turn on Player Stage4 light
          rjmp      PlayerRet
PlayerBad:
          sbi       PortD,PlayerRed     ;   turn on Player Stage2 light
          rjmp      PlayerRet

PlayerRet:
          clr       playerHit           ; false
          ldi       dispCnt,DelayCnt    ; delay next cycle

          ret                           ; checkPlayer


; void playerISR()
; ------------------------------------------------------------
playerISR:

          ; Check if dispLight == Stage4
          ldi     r20, Stage4              ; Load Stage4 constant into r20
          cp      dispLight, r20           ; Compare dispLight with Stage4
          breq    player_hit            ; If not equal, return from ISR
          call    CheckPlayer
          reti
player_hit:
          ldi       playerhit,1
          call      CheckPlayer
          reti



; void timer1ISR()
; ------------------------------------------------------------
timer1ISR:
          ldi       isUpdate, 1          ; isUpdate = true

          ; reset counter
          ldi       r20,HIGH(TmDelay)     ; 10ms
          sts       TCNT1H,r20
          ldi       r20,LOW(TmDelay)
          sts       TCNT1L,r20

          reti                          ; timer1ISR