;
; TrafficLight.asm
;
; Author : GM
; This program simulates a traffic light and cross walk on one lane of traffic
; When you press the button when the lights are green and yellow, the cross walk
; will light up. If the button isnt pressed, the cross walk will not light up.
; ------------------------------------------------------------

.equ TmDelay = 34286                  ; 2 sec delay        

.equ BtnDirR = DDRD
.equ BtnPort = PORTD
.equ ButtonPin = PD2

.equ LedDirR = DDRD
.equ LedDirGreen = DDD3
.equ LedDirYellow = DDD4
.equ LedDirRedOne = DDD5
.equ LedDirRedTwo = DDD6
.equ LedDirWhite = DDD7

.equ Stage1Led = PD3
.equ Stage2Led = PB4
.equ Stage3Led = PB5

.equ RedWalk = PD6
.equ CrossWalk = PD7

; setup an array of counters for the color LEDs
.equ Stg1Cnt = 0x0100
.equ Stg2Cnt = 0x0101
.equ Stg3Cnt = 0x0102

.equ DelayCnt = 0

; enum for which light is being displayed
.equ Stage1 = 0
.equ Stage2 = 1
.equ Stage3 = 2
.equ DispPlayer = 4
.equ DispNone = 5

.def dispLight = r18                    ; dispLight  {Stage1=0, Stage2=1, Stage3=2, Stage4=3, button=4}

.def dispCnt = r16                      ; current display counter
.def isUpdate = r17                     ; bool - if true then update display
.def buttonHit = r23                    ; bool - true if button hit when Stage4 was on


; Vector Table
; ------------------------------------------------------------
.org 0x0000                             ; Reset
          jmp       main

.org INT0addr                           ; Player Interupt 
          jmp       ButtonISR

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
          ; set traffic light
          
          ; green
          sbi       LedDirR,LedDirGreen ; Set up green LED
          ; yellow
          sbi       LedDirR,LedDirYellow;Set up yellow LED
          ; red
          sbi       LedDirR,LedDirRedOne;Set up red LED
          sbi       LedDirR,LedDirRedTwo;Set up red LED for cross walk
          ; white/grey
          sbi       LedDirR, LedDirWhite;Set up white LED
          ; button input
          cbi       BtnDirR, ButtonPin  ; input
          sbi       BtnPort, ButtonPin  ; pull-up

          sbi       EIMSK, INT0         ; enble button interupt

          ldi       r20,0b00000010      ; mask 

          sts       EICRA,r20           ; falling edge

          ret                           ; gpioInit


; void countersInit()
; ------------------------------------------------------------
countersInit:
          ; Stage1 
          ldi       r16,10              ; 2 Seconds
          sts       Stg1Cnt,r16
          ; Stage2
          ldi       r16,3               ; .5 seconds
          sts       Stg2Cnt,r16
          ; Stage3
          ldi       r16,8               ; 1.5 second
          sts       Stg3Cnt,r16 

          ldi       dispLight,DispNone  ; initialize to no light
          ldi       dispCnt,DelayCnt    ; delay between runs

          clr       isUpdate            ; false

          ret                           ; countersInit

; void timer1Init()
; ------------------------------------------------------------
timer1Init:
          ; Initialize Timer1

          ; set counter
          ldi       r20,HIGH(TmDelay)     ; 2 seconds
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
; ------------------------------------------------------------
.def tempCnt = r19
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
          rjmp      buttonOn            ;   default: // button

Stage1On:
          cbi       PortD,Stage3Led     ; turn off Stage4 light
          sbi       PortD,RedWalk       ; turn On No walk light
          cbi       PortD,CrossWalk     ; turn off Cross walk light
          sbi       PortD,Stage1Led     ; turn on Stage1 light
          lds       tempCnt,Stg1Cnt     ; load Stage1 timer value
          mov       dispCnt,tempCnt     ; copy timer to display counter
          tst       tempCnt             ; if (tempCnt == 0)
          breq      updtDispRet         ;    return
          rjmp      UpdtDispRet         ; break
Stage2On:
          cbi       PortD,Stage1Led     ; turn off Stage1 light
          sbi       PortD,Stage2Led     ; turn on Stage2 light
          lds       tempCnt,Stg2Cnt     ; load Stage1 timer value
          mov       dispCnt,tempCnt     ; copy timer to display counter
          tst       tempCnt             ; if (tempCnt == 0)
          breq      updtDispRet         ;    return
          rjmp      UpdtDispRet         ; break
Stage3On:
          cbi       PortD,Stage2Led     ; turn off Stage2 light
          sbi       PortD,Stage3Led     ; turn on Stage3 light
          call      ButtonOn
          lds       tempCnt,Stg3Cnt     ; load Stage1 timer value
          mov       dispCnt,tempCnt     ; copy timer to display counter
          tst       tempCnt             ; if (tempCnt == 0)
          breq      updtDispRet         ;    return
          rjmp      UpdtDispRet         ; break

ButtonOn:
          sbi       PortD,Stage3Led     ; turn off Stage4 light
          call      checkCrossWalk
                                        ; } // end switch
UpdtDispRet:
          ret                           ; updateDisplay

; void checkCrossWalk()
; ------------------------------------------------------------
checkCrossWalk:
          tst       buttonHit           ; if (!buttonHit)
          breq      buttonRet           ;   goto bad
          sbi       PortD,CrossWalk     ; turn on crossWalk
          cbi       PortD,RedWalk       ; turn of Red Light
          rjmp      buttonRet
         
buttonRet:
          clr       buttonHit           ; false
          ldi       dispCnt,DelayCnt    ; delay next cycle

          ret                           

; void buttonISR()
; ------------------------------------------------------------
buttonISR:
          cpi   dispLight, stage3       ; compare display light to stage 3
          breq  buttonbad               ; if (dispLight and stage 3 are the same) to go button bad
          ldi   buttonHit, 1            ; else make button hit true
buttonbad:
          reti
      



; void timer1ISR()
; ------------------------------------------------------------
timer1ISR:  
          ldi       isUpdate, 1          ; isUpdate = true

          ; reset counter
          ldi       r20,HIGH(TmDelay)     ; 2 seconds
          sts       TCNT1H,r20
          ldi       r20,LOW(TmDelay)
          sts       TCNT1L,r20

          reti                          ; timer1ISR