;; Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
;;                    TU Braunschweig, Germany
;;                    www.tu-braunschweig.de/en/eis
;;
;; Use of this source code is governed by an MIT-style
;; license that can be found in the LICENSE file or at
;; https://opensource.org/licenses/MIT.

; meas_glsens.asm
; Nanocontroller Program for Glucose Sensor -- continuous operation for measurement
; works for 9 = 3.3.3 datapath

; Memory Assignments
##define ADR_NXT_STATE  7

; Functional Memory
##define ADR_BUF_WE     8
##define ADR_BUF_ADR    9
##define ADR_STATE     10
##define ADR_RTC       11
##define ADR_WAKE_ADC  14
##define ADR_WAKE_RTC  15

ORG 0
  
  CST   ADR_STATE                     ; State needs to be set before other functional memory
                                      ; in order to not disturb registered output stage!
                                      ; MEMPTR is now 1010
  CST   ADR_BUF_WE                    ; MEMPTR is now 1000
  CST   ADR_BUF_ADR                   ; MEMPTR is now 1001
  CST   ADR_NXT_STATE                 ; MEMPTR is now 0111
  LISL                                ; @{'OPB' : (0, 0)}
  LDI   dummy, dummy>>3
  ST    ADR_WAKE_ADC
  LDI   rtcloop
  ST    ADR_WAKE_RTC                  ; MEMPTR is now 1111
  ST    ADR_RTC                       ; MEMPTR is now 1011

dummy:
  SLEEP
  
rtcloop:                              ; 21 *** RTC tick => update state
  
  CST   ADR_RTC                       ; MEMPTR is now 1011
  LDI   100, 100>>3, 100>>6           ; OPB    is now 001.100.100
  STL
  LD    ADR_STATE                     ; @{'OPB' : (0, 7)}
  CMPI  4                             ; OPB    is now 000.000.100
  BNE   loop01
  LDI   1                             ; OPB    is now 000.000.001
  BNE   loop02
loop01:
  CMPI  5                             ; OPB    is now 000.000.101
  BNE   loop03
  LDI   1                             ; OPB    is now 000.000.001
loop02:
  BNE   loop04
loop03:
  CMPI  2                             ; OPB    is now 000.000.010
  BNE   loop05
  LD    ADR_NXT_STATE                 ; @{'OPB' : (0, 7)}
loop04:
  CMPI  1                             ; OPB    is now 000.000.001
loop05:
  BNE   loop1
loop06:                               ; *** States 4/5 and 2->1: Cycle BUF_WE and incr BUF_ADR ***
  LDS   ADR_BUF_WE                    ; MEMPTR is now 1000, OPB overwritten
  LISL
  LIS   ADR_BUF_ADR                   ; MEMPTR is now 1001, OPB overwritten

loop1:
  LD    ADR_STATE                     ; @{'OPB' : (0, 7)}
  CMPI  1                             ; OPB    is now 000.000.001
  BNE   loop2, loop2
  LD    ADR_NXT_STATE                 ; @{'OPB' : (0, 7)}
  BNE   regular, regular, regular
  LISL
  LDS   ADR_STATE                     ; MEMPTR is now 1010, OPB overwritten
  CST   ADR_RTC                       ; MEMPTR is now 1011
  LDI   511, 511>>3, 511>>6           ; OPB    is now 111.111.111
  STL
  BNE   rtcloop, rtcloop, rtcloop

loop2:
  CMPI  2, 2>>3                       ; OPB    is now 000.000.010
  BNE   loop3, loop3
  LD    ADR_NXT_STATE                 ; @{'OPB' : (0, 7)}
  CMPI  1                             ; OPB    is now 000.000.001
  BNE   regular, regular
  LDI   6, 6>>3                       ; OPB    is now 000.000.110
  STL
  LDS   ADR_STATE                     ; MEMPTR is now 1010, OPB overwritten
  LDI   1
  BNE   rtcloop, rtcloop, rtcloop
  
loop3:
  CMPI  5, 5>>3                       ; OPB    is now 000.000.101
  BNE   loop4, loop4
  LDI   2, 2>>3                       ; OPB    is now 000.000.010
  STL
  LDI   1                             ; OPB    is now 000.000.001
  ST    ADR_NXT_STATE                 ; MEMPTR is now 0111
  BNE   rtcloop, rtcloop, rtcloop

loop4:
  CMPI  7, 7>>3                       ; OPB    is now 000.000.111
  BNE   loop5, loop5
  LDI   1, 1>>3                       ; OPB    is now 000.000.001
  STL
  LDI   0                             ; OPB    is now 000.000.000
  ST    ADR_NXT_STATE                 ; MEMPTR is now 0111
  LDI   1
  BNE   rtcloop, rtcloop, rtcloop

loop5:
  CMPI  6, 6>>3                       ; OPB    is now 000.000.110
  BNE   regular
  CST   ADR_RTC                       ; MEMPTR is now 1011
  LDI   200, 200>>3, 200>>6           ; OPB    is now 011.001.000
  STL
regular:
  LD    ADR_NXT_STATE                 ; @{'OPB' : (0, 7)}
  ST    ADR_STATE                     ; MEMPTR is now 1010
  LIS   ADR_NXT_STATE                 ; MEMPTR is now 0111, OPB overwritten
  BNE   rtcloop, rtcloop, rtcloop
  
END
