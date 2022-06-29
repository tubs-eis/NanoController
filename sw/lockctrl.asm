;; Copyright (c) 2022 Chair for Chip Design for Embedded Computing,
;;                    Technische Universitaet Braunschweig, Germany
;;                    www.tu-braunschweig.de/en/eis
;;
;; Use of this source code is governed by an MIT-style
;; license that can be found in the LICENSE file or at
;; https://opensource.org/licenses/MIT.

; lockctrl.asm
; Nanocontroller Program for Electronic Doorlock
; works for 7 = 4.3 datapath
; in MEH ASIC !!!

; Memory Assignments
##define ADR_HOURS 6
##define ADR_MINS  7

; Functional Memory
##define ADR_SECS       8
##define ADR_GPCSTATE  10
##define ADR_RTC       11
##define ADR_WAKE_TRIG 13
##define ADR_WAKE_PROX 14
##define ADR_WAKE_RTC  15

ORG 0
  
  CST   ADR_GPCSTATE                  ; GPC state needs to be set first 
                                      ; in order to not disturb system state! 
                                      ; MEMPTR is now 1010
  CST   ADR_HOURS                     ; MEMPTR is now 0110
  CST   ADR_MINS                      ; MEMPTR is now 0111
  CST   ADR_SECS                      ; MEMPTR is now 1000
  CST   ADR_RTC                       ; MEMPTR is now 1011
  LISL                                ; OPB overwritten
  LDI   trig, trig>>3
  ST    ADR_WAKE_TRIG                 ; MEMPTR is now 1101
  LDI   prox
  ST    ADR_WAKE_PROX                 ; MEMPTR is now 1110
  LDI   rtcloop, rtcloop>>3
  ST    ADR_WAKE_RTC                  ; MEMPTR is now 1111
  SLEEP

trig:                                 ; 26 *** GPC triggers that it can be deactivated

  LDS   ADR_GPCSTATE                  ; MEMPTR is now 1010, OPB overwritten
  SLEEP

prox:                                 ; 29 *** Proximity event => start up GPC
  
  LDI   2, 2>>3                       ; OPB    is now 0000.010
  ST    ADR_GPCSTATE                  ; MEMPTR is now 1010
  SLEEP
  
rtcloop:                              ; 35 *** RTC tick => update clock
  
  LIS   ADR_SECS                      ; MEMPTR is now 1000, OPB overwritten
  CMPI  60, 60>>3                     ; OPB    is now 0111.100
  BNE   idle, idle
  CSTL
  CST   ADR_GPCSTATE
  LIS   ADR_MINS                      ; MEMPTR is now 0111, OPB overwritten
  CMPI  60, 60>>3                     ; OPB    is now 0111.100
  BNE   idle, idle
  CSTL
  LIS   ADR_HOURS                     ; MEMPTR is now 0110, OPB overwritten
  CMPI  24, 24>>3                     ; OPB    is now 0011.000
  BNE   idle, idle
  CSTL

idle:
  SLEEP
  
END
