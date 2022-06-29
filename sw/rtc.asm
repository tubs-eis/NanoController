;; Copyright (c) 2022 Chair for Chip Design for Embedded Computing,
;;                    Technische Universitaet Braunschweig, Germany
;;                    www.tu-braunschweig.de/en/eis
;;
;; Use of this source code is governed by an MIT-style
;; license that can be found in the LICENSE file or at
;; https://opensource.org/licenses/MIT.

; rtc.asm
; Real Time Clock (Hours, Minutes, Seconds)
; works for 7 = 4.3 datapath
; in MEH ASIC !!!

; Memory Assignments
##define ADR_HOURS 6
##define ADR_MINS  7

; Functional Memory
##define ADR_SECS      8
##define ADR_PROXCNT   9
##define ADR_RTC       11
##define ADR_WAKE_PROX 14
##define ADR_WAKE_RTC  15

ORG 0
  
  CST   ADR_HOURS               ; MEMPTR is now 0110
  CST   ADR_MINS                ; MEMPTR is now 0111
  CST   ADR_SECS                ; MEMPTR is now 1000
  CST   ADR_PROXCNT             ; MEMPTR is now 1001
  CST   ADR_RTC                 ; MEMPTR is now 1011
  LISL                          ; OPB overwritten
  LDI   prox, prox>>3
  ST    ADR_WAKE_PROX           ; MEMPTR is now 1110
  LDI   loop, loop>>3
  ST    ADR_WAKE_RTC            ; MEMPTR is now 1111
  SLEEP
  
prox:                           ; 22 *** Proximity event => count and send trigger pulse

  LIS  ADR_PROXCNT              ; MEMPTR is now 1001, OPB overwritten
  LISL                          ; OPB overwritten

idle:

  SLEEP
  
loop:                           ; 26 *** RTC tick => update clock
  
  LIS  ADR_SECS                 ; MEMPTR is now 1000, OPB overwritten
  CMPI 60, 60>>3                ; OPB    is now 0111.100
  BNE  idle, idle
  CSTL
  LIS  ADR_MINS                 ; MEMPTR is now 0111, OPB overwritten
  CMPI 60, 60>>3                ; OPB    is now 0111.100
  BNE  idle, idle
  CSTL
  
  ; following code commented out to reduce simulation time
  ; may be activated again for real-time FPGA-based rapid prototyping
  
  ;LIS  ADR_HOURS                ; MEMPTR is now 0110, OPB overwritten
  ;CMPI 24, 24>>3                ; OPB    is now 0011.000
  ;BNE  idle, idle
  ;CSTL
  
END
