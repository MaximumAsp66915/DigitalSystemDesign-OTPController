# 🛡️ Digital System Design: OTP Memory Controller

Welcome to the official repository for the **One-Time Programmable (OTP) Memory Controller** hardware design project. This project was developed as a core laboratory deliverable for the **ASIC/FPGA Design** course.

---

## 📌 Project Overview
The OTP Controller provides a robust digital interface to read configuration data from a 256-bit One-Time Programmable memory array and distribute it across various system sub-modules. 

At **Power-On Reset (POR)**, the controller sequentially boots, reads all necessary configuration fields, applies any valid patch overrides, and locks the final verified values into synchronous output registers. This layout abstracts the complex timing of the non-volatile memory macro, allowing downstream modules to read configuration data directly from stable, static register lines.

### ✨ Key Features
* **Automated POR Boot Sequence:** A dedicated Finite State Machine (FSM) sequentially captures and loads all 256 bits of configuration data instantly upon power-up.
* **Hardware Patching Mechanism:** Supports `Patch0` and `Patch1` override logic, allowing the system to correct a small number of faulty or outdated OTP bits without discarding the entire Bank0 storage block.
* **Downstream Hardware Distribution:** Distributes unique trim and configuration metrics directly to specialized modules like the Frequency Difference Estimator and Temperature Mapping Engine.
* **Dual-Target Flexibility:** The OTP array is modeled as a synchronous ROM for functional RTL simulation, while remaining fully synthesizable to either an ASIC register file or a hard OTP IP macro block.

---

## 🏗️ System Architecture

### 🧭 Position in the System
The OTP Controller sits at the root of the device initialization chain, acting as the secure boot and calibration anchor for the broader digital core:

```text
OTP Array (256 bits) ──► OTP Controller ──┬──► RO_TRIM_CODE to analog (via digital core)
                                          ├──► TC1, TC2 to Frequency Difference Estimator
                                          ├──► RATIO_P0…P4 to Temperature Mapping Engine
                                          ├──► SKU_CODE, CFG_FLAGS, etc.
                                          └──► AGING_BASE to rRO Engine
```

### 📊 Functional Block Diagram
The internal flow within the controller asset layer progresses as follows during the boot cycle:

```text
┌────────────────────────────────────────────────────────────┐
│                      OTP Controller                        │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │      OTP memory array (256 bits) modelled as         │  │
│  │          synchronous ROM (read on clk edge)          │  │
│  └────────────────────┬─────────────────────────────────┘  │
│                       │                                    │
│                       ▼                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │               OTP read FSM (at POR)                  │  │
│  │   - Sequentially reads all fields from Bank0         │  │
│  │   - Reads Patch0 and Patch1 (if valid)               │  │
│  │   - Applies overrides                                │  │
│  │   - Stores final values in output registers           │  │
│  └────────────────────┬─────────────────────────────────┘  │
│                       │                                    │
│                       ▼                                    │
│    Output registers (synchronously updated, static after POR)
└────────────────────────────────────────────────────────────┘
```
### 📁 Repository Structure
```text
├── design/             # RTL Source Code (.v, .sv, or .vhd)
│   ├── otp_ctrl_top.sv # Top-level system controller
│   ├── otp_fsm.sv      # Power-On Reset & Patch processing FSM
│   └── otp_sync_rom.sv # Behavioral Synchronous ROM model (256-bit array)
├── verification/       # Testbenches and Simulation environments
│   ├── tb_otp_top.sv   # Top-level testbench (POR & Patch injection cases)
│   └── wave_configs/   # Saved waveform configurations (.wcfg / .rc)
├── synthesis/          # Synthesis scripts, SDC constraints, and gate netlists
├── docs/               # Project reports, timing waveforms, and register mappings
└── README.md           # Project documentation
```
## 🛠️ Tools & Technologies Used
* **Hardware Description Language:** SystemVerilog / Verilog *(Modify based on choice)*
* **Simulation Engine:** Siemens ModelSim / Questa Advanced Simulator / Synopsys VCS
* **Synthesis & Implementation Suite:** Synopsys Design Compiler (ASIC Target) / AMD Xilinx Vivado (FPGA Target)
* **Design Methodology:** Digital Systems Design (DSD) RTL-to-Gate Flow

---

## 🚀 How to Run the Simulation
To clone the repository and run the functional verification suite locally:

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/](https://github.com/)[Your-Username-or-Org]/Digital-System-Design-OTP-Controller.git
   cd Digital-System-Design-OTP-Controller
   ```
2. Execute the Compile & Simulation Flow:
Open your target EDA simulator tool environment, map the compilation source index to the files located inside the design/ path, and launch execution on the testbench module:
```bash
# Example using command line simulator interface tools
vlog design/*.sv verification/*.sv
vsim work.tb_otp_top -do "run -all"
```

👥 Contributors (Group Members)

- Member 1 - RTL Architecture & FSM Design - GitHub Profile

- Member 2 - Verification, Testbench Development & Coverage - GitHub Profile

- Member 3 - Synthesis Run, Constraints Tuning & Netlist Validation - GitHub Profile

- Member 4 - Synthesis Run, Constraints Tuning & Netlist Validation - GitHub Profile
