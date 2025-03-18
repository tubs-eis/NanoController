# NanoController
A Minimal and Flexible Open-Source Processor Architecture for Ultra-Low-Power SoCs, Featuring Micro-Coded Instruction Set Re-Definition
---
Distributed embedded devices, e.g., in IoT, wireless sensor networks, autonomous wearable and implantable biomedical sensors, which are powered by small batteries or energy harvesting, are constrained to very limited energy budgets.
	*NanoController* is an open-source processor architecture, which is intended to be used as a flexible system state controller in the always-on domain of smart, but energy-constrained devices.
	The NanoController features a compact ISA, minimal silicon area and power consumption, and enables the implementation of, e.g., efficient power management strategies in comparison to much simpler and constrained always-on timer circuits.
	Due to its full software programmability, additional debugging and bug-fixing, as well as adaptable data pre- and post-processing of on-chip data are enabled in comparison to fixed-function finite state machines (FSMs) for system control.
  
The NanoController architecture and SoC system implementations are described in the following papers. If you are using NanoController, please cite it as follows:
>Weißbrich, M., Payá-Vayá, G. (2022). 
>**NanoController: A Minimal and Flexible Processor Architecture for Ultra-Low-Power Always-On System State Controllers**.
>In: Orailoglu, A., Reichenbach, M., Jung, M. (eds) *Embedded Computer Systems: Architectures, Modeling, and Simulation. SAMOS 2022*. Lecture Notes in Computer Science, vol 13511. Springer, Cham. https://doi.org/10.1007/978-3-031-15074-6_7

Further papers with NanoController SoC implementations:
>Weißbrich, M., Meyer, A., Dossanov, A., Issakov, V., Payá-Vayá, G. (2024).
>**A 505nW Programmable NanoController in 22 nm FDSOI-CMOS for Autonomous Ultra-Low-Power Mixed-Signal SoCs**.
> In: *2024 IEEE Nordic Circuits and Systems Conference (NorCAS),* Lund, Sweden. https://doi.org/10.1109/NorCAS64408.2024.10752476

>Weißbrich, M., Blume, H., Payá-Vayá, G. (2022).
>**A Silicon-Proof Controller System for Flexible Ultra-Low-Power Energy Harvesting Platforms**.
> In: *2022 11th International Conference on Modern Circuits and Systems Technologies (MOCAST),* Bremen, Germany. https://doi.org/10.1109/MOCAST54814.2022.9837540

## NEW 2024-03: NanoSoftController (optimized for FPGA)

The *NanoSoftController* FPGA-optimized variant has been added to this repo, which uses distributed LUT RAM for instruction and data memory on Xilinx FPGAs. Furthermore, a reference Vivado synthesis and implementation flow with a Digilent Arty-A7 target is included. Vivado Version 2023.2 has been tested.

The NanoSoftController is described in the following paper, please cite it as follows:
>Weißbrich, M., Seidlitz, G., Payá-Vayá, G. (2025). 
>**NanoSoftController: A Minimal Soft Processor for System State Control in FPGA Systems**.
>In: Carro, L., Regazzoni, F., Pilato, C. (eds) *Embedded Computer Systems: Architectures, Modeling, and Simulation. SAMOS 2024*. Lecture Notes in Computer Science, vol 15226. Springer, Cham. https://doi.org/10.1007/978-3-031-78377-7_17

## NEW 2025-03: NanoController v2 Architecture & Automated Design Space Exploration of the NanoController Instruction Set

The *NanoController v2* architecture is a significantly enhanced micro-architecture, enabling *free re-definition* of the NanoController instruction set by means of a micro-coded control unit.
	Goals are program code compaction and increased performance of application execution.
	To support the exploration of possible instruction set variants for *NanoController v2*, a *fully automated design space exploration framework* is also provided.

## Table of Contents

[Getting started](#Getting-started)

- [Repository Structure](#Repository-Structure)
- [Installation](#Installation)
- [Configuring the Environment](#Configuring-the-Environment)
- [Verifying the Environment Configuration](#Verifying-the-Environment-Configuration)
- [Verifying the Instruction Set Exploration Framework Environment](#Verifying-the-Instruction-Set-Exploration-Framework-Environment)
- [Verifying the FPGA Synthesis Configuration](#Verifying-the-FPGA-Synthesis-Configuration)

[Contributors](#Contributors)

[License](#License)

[Citation](#Citation)

## Getting started

This repository contains the *open-source RTL implementation* of the NanoController v2 architecture, and a *cycle-accurate functional SystemC model* of the NanoController architecture. In the provided simulation environment, both are co-simulated against each other with example program codes to perform a basic check of functionality.
The simulation environment is currently using **Mentor QuestaSim** to perform the VHDL/SystemC co-simulation, which you need to provide within your infrastructure. Version 2025.1 has been tested, older or newer versions without warranty.

Furthermore, it contains the *instruction set design space exploration framework* for NanoController v2 instruction set re-definition via the micro-coded control unit.
The framework is written in **Python**, making use of the *networkx* package for internal graph representations. Python packages (version 3.12.3) on Ubuntu 24.04 LTS have been tested, other versions without warranty.

For the *NanoSoftController* FPGA variant, a reference target (Artix-7 FPGA, Digilent Arty-A7 development board) is provided, which has been tested with the **Xilinx Vivado** toolchain in version 2023.2, other versions without warranty.

### Repository Structure

| Directory | Description |
|-----------|-------------|
| `asm` | Contains the Table Assembler tool to translate NanoController assembly code to binary images. Based on the *axasm* universal cross assembler by Al Williams (https://github.com/wd5gnr/axasm). |
| `config` | Parameter configuration header for the functional SystemC model. Should be coherent with the parameterization in the VHDL packages! |
| `fpga_arty` | Contains the reference Vivado synthesis and implementation flow with a Digilent Arty-A7 FPGA target. Uses the *NanoSoftController* FPGA-optimized variant of the NanoController v2 architecture. |
| `rtl` | Contains the VHDL source code of the open-source RTL implementation of the NanoController v2 architecture. |
| `sim` | VHDL/SystemC co-simulation script flow in sub-directory `scr`, and the functional SystemC model in sub-directory `systemc`. |
| `sw` | NanoController assembly codes and AST representations of example programs. |
| `tools_alldep` | Contains the Python tools and scripts of the instruction set exploration framework for the NanoController v2 architecture. |

### Installation

Clone the repository:
```bash
git clone https://github.com/tubs-eis/NanoController
```

If you intend to use the evolutionary binary instruction set encoding features, also clone the VANAGA repository next to the NanoController repository:
```bash
git clone https://github.com/tubs-eis/VANAGA
```

### Configuring the Environment

1. In `sim/init_tools` and `tools_alldep/sim/init_tools`, define the necessary actions to set up your **Mentor QuestaSim** environment for VHDL/SystemC co-simulation.
2. In `fpga_arty/init_tools`, define the necessary actions to set up your **Xilinx Vivado** environment for FPGA synthesis and implementation of the FPGA-optimized *NanoSoftController* variant. If you want to use the reference target (Artix-7 FPGA, Digilent Arty-A7 development board), make sure your Vivado installation has the Digilent board files installed (https://digilent.com/reference/programmable-logic/guides/install-board-files).

### Verifying the Environment Configuration

Run the VHDL/SystemC co-simulation testbench using:

```
cd sim
make sim-hdl
```

Six test cases should be simulated in sequence. 
	During application execution, functional memory values are printed out for reference (when updated).
	The termination should occur under testbench control, without throwing any mismatch errors between SystemC model and VHDL code. 
	Look out for following transcript lines to indicate proper termination:

```
# ** Note: $finish    : /my/repo/path/NanoController/sim/sv/SPI_Debug_Master.sv(215)
#    Time: 18433 us  Iteration: 1  Instance: /SYSTEM/testbench
```

### Verifying the Instruction Set Exploration Framework Environment

Test procedures and usage examples are provided by a central testbench script:

```
./0_testFramework.sh
```

This will run the tool invocations and data transformations of the framework for 4 reference applications, i.e., lockctrl and lockctrl_alt (ASM implementations), and lockctrl and lockctrl_alt (AST representations).
	If the environment is properly set up, all tests should run from beginning to end without any errors.

### Verifying the FPGA Synthesis Configuration

```
cd fpga_arty
make all
```

This should run the Vivado synthesis and implementation flow for the *NanoSoftController* for an Artix-7 target on the Digilent Arty-A7 FPGA board. The flow should finish without any error or interruption. After completion, you can examine the created Vivado project in the GUI via `make run_gui`. In behavioral simulation, you can source the prepared simulation script in the simulator's Tcl console via `source ../run_sim_gui.tcl`. You should observe activity on the `led` outputs of the reference system top-level, and you should see an LED reaction on the `btn` input trigger.

A programming target is provided in the Makefile, which, when a board is connected, should properly load the bitstream (with a test application) onto the FPGA device of a Digilent Arty-A7 board.
	You should observe a counter on two of the Arty's LEDs, software-controlled by the NanoController.
	Furthermore, a Python script (using the pyserial package) is provided to read out functional memory values of the test application counters via the UART debug interface:

```
cd fpga_arty
make fpga_pgm
./emu_debug_uart.py
```

## Contributors
Chair for Chip Design for Embedded Computing, TU Braunschweig:
- Moritz Weißbrich: Maintainer & main contributor, chip design, silicon validation, and measurements
- Germain Seidlitz: NanoSoftController
- Guillermo Payá Vayá: General contributions & project supervision

Institute for CMOS Design, TU Braunschweig:
- Adilet Dossanov: Application case, chip design, silicon validation, and measurements
- Alexander Meyer: Application case, chip design, silicon validation, and measurements
- Yerzhan Kudabay: Measurement setup, PCB design & wire-bonding, silicon validation
- Vadim Issakov: General contributions & project supervision

## License

This open-source project is distributed under the MIT license.

The *axasm* universal cross assembler by Al Williams (https://github.com/wd5gnr/axasm) has been sourced and modified for this project. All *axasm* files and extensions are distributed under the original license, GPL v3.

## Citation

The NanoController architecture is described in the following paper. If you are using NanoController, please cite it as follows:
>Weißbrich, M., Payá-Vayá, G. (2022). 
>**NanoController: A Minimal and Flexible Processor Architecture for Ultra-Low-Power Always-On System State Controllers**.
>In: Orailoglu, A., Reichenbach, M., Jung, M. (eds) *Embedded Computer Systems: Architectures, Modeling, and Simulation. SAMOS 2022*. Lecture Notes in Computer Science, vol 13511. Springer, Cham. https://doi.org/10.1007/978-3-031-15074-6_7

The NanoSoftController is described in the following paper, please cite it as follows:
>Weißbrich, M., Seidlitz, G., Payá-Vayá, G. (2025). 
>**NanoSoftController: A Minimal Soft Processor for System State Control in FPGA Systems**.
>In: Carro, L., Regazzoni, F., Pilato, C. (eds) *Embedded Computer Systems: Architectures, Modeling, and Simulation. SAMOS 2024*. Lecture Notes in Computer Science, vol 15226. Springer, Cham. https://doi.org/10.1007/978-3-031-78377-7_17

Further papers with NanoController SoC implementations:
>Weißbrich, M., Meyer, A., Dossanov, A., Issakov, V., Payá-Vayá, G. (2024).
>**A 505nW Programmable NanoController in 22 nm FDSOI-CMOS for Autonomous Ultra-Low-Power Mixed-Signal SoCs**.
> In: *2024 IEEE Nordic Circuits and Systems Conference (NorCAS),* Lund, Sweden. https://doi.org/10.1109/NorCAS64408.2024.10752476

>Weißbrich, M., Blume, H., Payá-Vayá, G. (2022).
>**A Silicon-Proof Controller System for Flexible Ultra-Low-Power Energy Harvesting Platforms**.
> In: *2022 11th International Conference on Modern Circuits and Systems Technologies (MOCAST),* Bremen, Germany. https://doi.org/10.1109/MOCAST54814.2022.9837540
