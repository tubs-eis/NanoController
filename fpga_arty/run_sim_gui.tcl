## Copyright (c) 2024 Chair for Chip Design for Embedded Computing,
##                    Technische Universitaet Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.


restart
add_force {/sys_top_emu/CLK100MHZ} -radix hex {1 0ns} {0 5000ps} -repeat_every 10000ps
add_force {/sys_top_emu/ck_rst} -radix hex {0 0ns}
add_force {/sys_top_emu/btn} -radix hex {0 0ns}
add_force {/sys_top_emu/sw} -radix hex {0 0ns}
run 25 ns
add_force {/sys_top_emu/ck_rst} -radix hex {1 0ns}
run 50 ms
add_force {/sys_top_emu/btn} -radix hex {1 0ns}
run 1 ms
add_force {/sys_top_emu/btn} -radix hex {0 0ns}
run 30 ms
