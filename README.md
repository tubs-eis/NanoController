# NanoController
A Minimal and Flexible Processor Architecture for Ultra-Low-Power Controllers
---
Distributed nodes in IoT and wireless sensor networks, which are powered by small batteries or energy harvesting, are constrained to very limited energy budgets.
	By intelligent power management and power gating strategies for the main microcontroller of the system, the energy efficiency can be significantly increased.
	However, timer-based, periodical power-up sequences are too inflexible to implement these strategies, and the use of a programmable power management controller demands minimum area and ultra-low power consumption from this system part itself.

NanoController is an open-source processor architecture, which is intended to be used as a flexible system state controller in the always-on domain of smart devices.
	The NanoController features a compact ISA, minimal silicon area and power consumption, and enables the implementation of efficient power management strategies in comparison to much simpler and constrained always-on timer circuits.
  
The NanoController architecture is described in the following paper. If you are using NanoController, please cite it as follows:
>Weißbrich, M., Payá-Vayá, G. (2022). 
>**NanoController: A Minimal and Flexible Processor Architecture for Ultra-Low-Power Always-On System State Controllers**.
>In: Orailoglu, A., Reichenbach, M., Jung, M. (eds) *Embedded Computer Systems: Architectures, Modeling, and Simulation. SAMOS 2022*. Lecture Notes in Computer Science, vol 13511. Springer, Cham. https://doi.org/10.1007/978-3-031-15074-6_7

## NEW 2024-03: NanoSoftController (optimized for FPGA)

The *NanoSoftController* FPGA-optimized variant has been added to this repo, which uses distributed LUT RAM for instruction and data memory on Xilinx FPGAs. Furthermore, a reference Vivado synthesis and implementation flow with a Digilent Arty-A7 target is included. Vivado Version 2023.2 has been tested.

The NanoSoftController is described in the following paper, please cite it as follows:
>Weißbrich, M., Seidlitz, G., Payá-Vayá, G. (2024). 
>**NanoSoftController: A Minimal Soft Processor for System State Control in FPGA Systems**.
>In: *Embedded Computer Systems: Architectures, Modeling, and Simulation. SAMOS 2024* (accepted for publication, in print)

## Table of Contents

[Getting started](#Getting-started)

- [Repository Structure](#Repository-Structure)
- [Installation](#Installation)
- [Configuring the Environment](#Configuring-the-Environment)
- [Verifying the Environment Configuration](#Verifying-the-Environment-Configuration)
- [Verifying the FPGA Synthesis Configuration](#Verifying-the-FPGA-Synthesis-Configuration)

[Contributors](#Contributors)

[License](#License)

[Citation](#Citation)

## Getting started

This repository contains the *open-source RTL implementation* of the NanoController architecture, and a *cycle-accurate functional SystemC model* of the NanoController architecture. In the provided simulation environment, both are co-simulated against each other with 2 example program codes to perform a basic check of functionality.

The simulation environment is currently using **Mentor QuestaSim** to perform the VHDL/SystemC co-simulation, which you need to provide within your infrastructure. Version 2021.3 has been tested, older or newer versions without warranty.

### Repository Structure

| Directory | Description |
|-----------|-------------|
| `asm` | Contains the Table Assembler tool to translate NanoController assembly code to binary images. Based on the *axasm* universal cross assembler by Al Williams (https://github.com/wd5gnr/axasm). |
| `config` | Parameter configuration header for the functional SystemC model. Should be coherent with the parameterization in the VHDL packages! |
| `fpga_arty` | Contains the reference Vivado synthesis and implementation flow with a Digilent Arty-A7 FPGA target. Uses the *NanoSoftController* FPGA-optimized variant of the NanoController. |
| `rtl` | Contains the VHDL source code of the open-source RTL implementation of NanoController. |
| `sim` | VHDL/SystemC co-simulation script flow in sub-directory `scr`, and the functional SystemC model in sub-directory `systemc`. |
| `sw` | NanoController assembly code of example programs. |

### Installation

Clone the repository

```bash
git clone https://github.com/tubs-eis/NanoController
```

### Configuring the Environment

1. In `sim/init_tools`, define the necessary actions to set up your **Mentor QuestaSim** environment for VHDL/SystemC co-simulation.
2. In `fpga_arty/init_tools`, define the necessary actions to set up your **Xilinx Vivado** environment for FPGA synthesis and implementation of the FPGA-optimized *NanoSoftController* variant. If you want to use the reference target (Artix-7 FPGA, Digilent Arty-A7 development board), make sure your Vivado installation has the Digilent board files installed (https://digilent.com/reference/programmable-logic/guides/install-board-files).

### Verifying the Environment Configuration

Run the VHDL/SystemC co-simulation testbench using:

```
cd sim
make sim-hdl
```

Two example programs should be simulated in sequence. The termination should occur under testbench control, without throwing any mismatch errors between SystemC model and VHDL code. Look out for following transcript lines to indicate proper termination:

```
** Note: (vsim-6574) SystemC simulation stopped by user.
```

### Verifying the FPGA Synthesis Configuration

```
cd fpga_arty
make all
```

This should run the Vivado synthesis and implementation flow for the *NanoSoftController* for an Artix-7 target on the Digilent Arty-A7 FPGA board. The flow should finish without any error or interruption. After completion, you can examine the created Vivado project in the GUI via `make run_gui`. In behavioral simulation, you can source the prepared simulation script in the simulator's Tcl console via `source ../run_sim_gui.tcl`. You should observe activity on the `led` outputs of the reference system top-level, and you should see an LED reaction on the `btn` input trigger.

A programming target is provided in the Makefile, which, when a board is connected, should properly load the bitstream onto the FPGA device of a Digilent Arty-A7 board:

```
cd fpga_arty
make fpga_pgm
```

## Contributors

- Moritz Weißbrich (Technische Universität Braunschweig)
- Guillermo Payá Vayá (Technische Universität Braunschweig)

## License

This open-source project is distributed under the MIT license.

The *axasm* universal cross assembler by Al Williams (https://github.com/wd5gnr/axasm) has been sourced and modified for this project. All *axasm* files and extensions are distributed under the original license, GPL v3.

## Citation

The NanoController architecture is described in the following paper. If you are using NanoController, please cite it as follows:
>Weißbrich, M., Payá-Vayá, G. (2022). 
>**NanoController: A Minimal and Flexible Processor Architecture for Ultra-Low-Power Always-On System State Controllers**.
>In: Orailoglu, A., Reichenbach, M., Jung, M. (eds) *Embedded Computer Systems: Architectures, Modeling, and Simulation. SAMOS 2022*. Lecture Notes in Computer Science, vol 13511. Springer, Cham. https://doi.org/10.1007/978-3-031-15074-6_7

The NanoSoftController is described in the following paper, please cite it as follows:
>Weißbrich, M., Seidlitz, G., Payá-Vayá, G. (2024). 
>**NanoSoftController: A Minimal Soft Processor for System State Control in FPGA Systems**.
>In: *Embedded Computer Systems: Architectures, Modeling, and Simulation. SAMOS 2024* (accepted for publication, in print)
