#!/usr/bin/python3
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

import signal
import serial
import time
import sys

checkValues = b'\x90\x92'                  # command values to send sequentially

def exitHandler(sig, frame):
  ser.close()  # close port
  print()
  print("[emu_debug_uart.py] END")
  print()
  sys.exit(0)


print()
print("[emu_debug_uart.py] START")

print("[emu_debug_uart.py] Open Port...")
ser = serial.Serial('/dev/ttyUSB1', 1200)  # open serial port with 1200 Baud
time.sleep(.2)                             # I... am... slow,... need... more... time...
print(ser.name)                            # check which port was really used

print("[emu_debug_uart.py] Reset Input Buffer...")
ser.reset_input_buffer()                   # throw away received garbage prior to sending data

signal.signal(signal.SIGINT, exitHandler)  # set up ending on interruption signal (keyboard Ctrl+C, for example)

while True:                                # endless loop until interrupted by signal
  for i in range(len(checkValues)):        # for each value in sequence
    ser.write(checkValues[i:i+1])          # write to serial output buffer
    time.sleep(.2)                         # I... am... slow,... need... more... time...
    ser.flush()                            # flush output buffer, this actually sends over UART
    s = ser.read(1)                        # read 1 byte of result
    print(f"{s.hex()} ", end='')           # print hex values without line ending
  print()                                  # end line after command sequence
