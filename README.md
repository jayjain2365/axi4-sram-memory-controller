# AXI4-to-SRAM Memory Controller

A Verilog-based memory controller that interfaces an AXI4 master with a synchronous SRAM model. The design supports burst-based read and write transactions, byte-level write strobes, and independent AXI read and write channels.

## Project Overview

This project implements an AXI4-to-SRAM interface using Verilog RTL. It accepts AXI read and write requests, manages communication with a single-port SRAM, and returns the corresponding AXI responses.

The controller is designed around a 256 × 32-bit SRAM with a one-clock-cycle read latency. It supports INCR bursts and handles read and write transactions through separate AXI channel logic.

## Key Features

- AXI4-based read and write interface.
- 32-bit data bus and 32-bit address bus.
- 256 × 32-bit SRAM organization (1 KB).
- Synchronous SRAM with one-cycle read latency.
- INCR burst transactions.
- Burst lengths from 1 to 16 beats.
- Byte-level write control using `WSTRB`.
- AXI read and write response handling.
- Backpressure handling through VALID/READY handshaking.
- Single outstanding transaction due to the single-port SRAM.
- Write priority when read and write requests arrive simultaneously while the controller is idle.
- Validation of burst length, transfer size, burst type, and address alignment.
- Error response generation for unsupported transactions.

## System Specifications

| Parameter | Specification |
|---|---|
| Protocol | AXI4 subset |
| Address width | 32 bits |
| Data width | 32 bits |
| SRAM depth | 256 words |
| SRAM word width | 32 bits |
| Total memory | 1 KB |
| Read latency | 1 clock cycle |
| Burst type | INCR |
| Burst length | 1–16 beats |
| Write strobes | 4 bits |
| Outstanding transactions | 1 |
| Target clock frequency | 100 MHz |

**Note:** This project implements a defined subset of AXI4 functionality. It is not intended to be a fully compliant implementation of every AXI4 feature.

## Architecture

The design consists of the following main blocks:

1. **AXI Write Slave:** Handles write address and write data transactions, including burst processing and write response generation.
2. **AXI Read Slave:** Handles read address requests, SRAM read operations, and read response generation.
3. **SRAM Controller:** Manages SRAM access, address decoding, read/write control, and byte-enable operations.
4. **SRAM Model:** Implements a behavioral 256 × 32-bit synchronous memory.
5. **Top Module:** Connects the AXI interfaces, SRAM controller, and memory model, and handles transaction ownership and write priority.

### Block-Level Data Flow

```text
             AXI4 Master
                  |
          +-------+-------+
          |               |
     Write Channel    Read Channel
          |               |
   +-------------+  +-------------+
   | AXI Write   |  | AXI Read    |
   | Slave       |  | Slave       |
   +------+------+  +------+------+
          |                |
          +-------+--------+
                  |
          +-------v-------+
          | SRAM          |
          | Controller    |
          +-------+-------+
                  |
          +-------v-------+
          | 256 x 32-bit  |
          | SRAM Model    |
          +---------------+
```

## RTL Modules

The synthesizable RTL is written in Verilog.

| File | Description |
|---|---|
| `axi_sram_top.v` | Top-level integration of the AXI and SRAM blocks |
| `axi_write_slave.v` | AXI write channel handling |
| `axi4_read_slave.v` | AXI read channel handling |
| `sram_controller.v` | SRAM access and control logic |
| `sram_256x32_model.v` | Behavioral SRAM model |

## Verification

Verification is performed using SystemVerilog testbenches and assertions.

The test environment covers:

- Single-beat read and write operations.
- Multi-beat INCR burst transactions.
- Four-beat and sixteen-beat burst transfers.
- Partial-byte writes using all 16 `WSTRB` combinations.
- Different data patterns, including walking-one and walking-zero patterns.
- Random data patterns.
- Read and write response backpressure.
- Simultaneous read and write requests.
- Reference memory scoreboard checks.

### Assertion-Based Verification

SystemVerilog Assertions (SVA) are used to check AXI protocol behavior.

The assertion suite checks:

1. AXI write address channel stability during backpressure.
2. AXI write data channel stability during backpressure.
3. AXI write response channel stability during backpressure.
4. AXI read address channel stability during backpressure.
5. AXI read data channel stability during backpressure.
6. Correct `WLAST` generation.
7. Correct `RLAST` generation.
8. Write response sequencing.
9. Read response sequencing.
10. Valid write response encoding.
11. Valid read response encoding.

### Verification Results

| Verification Metric | Result |
|---|---:|
| Functional checks passed | 473 |
| Functional checks failed | 0 |
| SVA properties | 11 |
| SVA failures | 0 |

**Simulation Status: ALL TESTS PASSED**

The results represent the current testbench and assertion suite. They do not imply exhaustive verification of every possible AXI4 transaction or corner case.

### Lint Analysis

RTL lint analysis was performed to identify unused signals, coding issues, and potential design problems.

| Metric | Result |
|---|---|
| Initial findings | 7 |
| Final lint violations | 0 |
| Status | Passed |

Unused signals were addressed, and AXI transaction fields were validated for the supported transfer configuration.

## Synthesis Results

Synthesis was performed using **AMD Vivado 2025.1** for the Artix-7 `XC7A200T` FPGA.

### Post-Synthesis Resource Utilization

| Resource | Utilization |
|---|---:|
| LUTs | 145 |
| Flip-Flops | 149 |
| BRAM tiles | 0.5 |
| DSP blocks | 0 |
| Bonded I/O | 132 |
| BUFG | 1 |

The 256 × 32-bit SRAM was inferred using one `RAMB18E1` block rather than being implemented using individual flip-flops.

## FPGA Implementation and Timing Analysis

The design was successfully implemented using Vivado 2025.1. A 10 ns clock period was specified using an XDC constraint, corresponding to a target clock frequency of 100 MHz.

### Post-Implementation Resource Utilization

| Resource | Used | Device Capacity | Utilization |
|---|---:|---:|---:|
| LUTs | 121 | 134,600 | 0.09% |
| Slice Registers | 149 | 269,200 | 0.055% |
| Slices | 64 | 33,650 | 0.19% |
| BRAM tiles | 0.5 | 365 | 0.14% |
| Bonded I/O | 132 | 500 | 26.40% |
| BUFGCTRL | 1 | 32 | 3.13% |
| DSP | 0 | 740 | 0% |

### Post-Implementation Timing Results

| Timing Metric | Result |
|---|---:|
| Clock period constraint | 10 ns |
| Target frequency | 100 MHz |
| Worst Negative Slack (WNS) | +5.937 ns |
| Total Negative Slack (TNS) | 0 ns |
| Worst Hold Slack (WHS) | +0.243 ns |
| Total Hold Slack (THS) | 0 ns |
| Worst Pulse Width Slack (WPWS) | +4.500 ns |

All reported internal setup, hold, and pulse-width timing endpoints passed.

### Routing Results

| Routing Metric | Result |
|---|---:|
| Total logical nets | 615 |
| Nets not requiring routing | 221 |
| Fully routed nets | 394 |
| Nets with routing errors | 0 |

**Implementation Status: COMPLETED**

The design completed placement and routing with zero routing errors.

**Timing constraint note:** The current XDC specifies the internal clock but does not define external AXI input and output delays. Therefore, the reported timing results demonstrate internal timing performance under the specified clock constraint, not complete external interface timing closure.

## Design Limitations

- Supports a defined AXI4 subset rather than the complete AXI4 specification.
- Supports one outstanding transaction at a time.
- Uses a single-port SRAM architecture.
- The design was implemented for an Artix-7 device but was not validated on a physical FPGA development board.
- Board-specific I/O pin assignments and I/O standards have not been finalized.
- Bitstream generation and hardware validation were not performed.

## Tools and Technologies

- **HDL:** Verilog, SystemVerilog
- **Simulation and Design:** AMD Vivado 2025.1
- **Verification:** SystemVerilog Testbenches, SVA
- **Implementation:** Vivado Synthesis, Placement and Routing
- **Target FPGA:** AMD Artix-7 XC7A200T
- **Version Control:** Git and GitHub

## Running the Project

1. Clone the repository:

   ```bash
   git clone https://github.com/jayjain2365/axi4-sram-memory-controller.git
   ```

2. Open AMD Vivado 2025.1.

3. Open the project file:

   `AXI4-to-SRAM Memory Controller.xpr`

4. Check the RTL and simulation source files in the Sources window.

5. Run the required simulation testbench.

6. Review the simulation output and waveforms to verify the transactions and assertion results.

## Project Structure

```text
AXI4-to-SRAM Memory Controller/
│
├── AXI4-to-SRAM Memory Controller.srcs/
│   ├── sources_1/
│   │   └── new/
│   │       ├── axi_sram_top.v
│   │       ├── axi_write_slave.v
│   │       ├── axi4_read_slave.v
│   │       ├── sram_controller.v
│   │       └── sram_256x32_model.v
│   │
│   └── sim_1/
│       └── new/
│           ├── axi4_sram_sva.sv
│           ├── sram_controller_sva.sv
│           ├── sram_controller_tb.sv
│           ├── tb_axi4_read.sv
│           ├── tb_axi4_sram.sv
│           ├── tb_axi4_write.sv
│           ├── tb_sram.sv
│           └── tb_sram_controller.sv
│
├── .gitignore
├── AXI4-to-SRAM Memory Controller.xpr
└── README.md
```

## Future Improvements

- Expand AXI protocol coverage and corner-case verification.
- Add more back-to-back transaction tests.
- Improve functional coverage.
- Add external interface timing constraints for a specific AXI master and FPGA board.
- Perform bitstream generation and hardware validation on an FPGA development board.

## Author

**Jay Jain**

GitHub: [jayjain2365](https://github.com/jayjain2365)
