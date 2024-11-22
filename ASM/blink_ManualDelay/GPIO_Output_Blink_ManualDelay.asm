;
; GPIO_Output_Blink.asm
;
; Created: 10/22/2024
; Author : GM
; Desc   : Create a delay func and turn led on and off every 1/4 second
; Chip   : aTmega328
; -----------------------------------------------------------

main:
          ; one time config
          ; init stack pointer
          ldi       r16, HIGH(RAMEND)   ; Load high byte of RAMEND into r16
          out       SPH, r16            ; Set high byte of stack pointer
          ldi       r16, LOW(RAMEND)    ; Load low byte of RAMEND into r16
          out       SPL, r16            ; Set low byte of stack pointer
          sbi       DDRB , DDB2         ; config LED GPIO pin for output


main_loop:                              ; loop() {
          ; turn led on
          sbi       PORTB, PORTB2       ; Set PB2 high to turn on LED
          call      delay_1s            ; Call delay function for 1 second
          ; turn led off
          cbi       PORTB, PORTB2       ; Clear PB2 to turn off LED
          call      delay_1s            ; Call delay function for 1 second
          rjmp      main_loop           ; } // loop


; blocing wait for 1 second

delay_1s:
          ldi       r18, 16             ;for(k=0;k<64;k++) / divid by 4 for 1/4 second delay
delay_loop_3:                           ; {
          ldi       r17, 200            ;  for(j=0,j<200;j++)
delay_loop_2:                           ;   {
          ldi       r16, 250            ;    for(i=0;i<250;i++)
delay_loop_1:                           ;     {
          nop                           ;      null
          nop                           ;
          dec       r16                 ;
          brne      delay_loop_1        ;  }
          dec       r17                 
          brne      delay_loop_2        ; }
          dec       r18                
          brne      delay_loop_2        ;}
          ret                           ;