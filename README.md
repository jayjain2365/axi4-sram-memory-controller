# AXI4-to-SRAM Memory Controller

A Verilog-based memory controller that interfaces an AXI4 master with a synchronous SRAM model. The design supports burst-based read and write transactions, byte-level write strobes, and independent AXI read and write channels.

## Project Overview

This project implements an AXI4-to-SRAM interface using Verilog RTL. It accepts AXI read and write requests, manages the communication with a single-port SRAM, and returns the corresponding AXI responses.

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

**Note:** This project implements a defined subset of AXI4 functionality. It is not intended to be a fully compliant implementation of every AXI4 feature.

## Architecture

The design consists of the following main blocks:

1. **AXI Write Slave:** Handles write address and write data transactions, including burst processing and write response generation.
2. **AXI Read Slave:** Handles read address requests, SRAM read operations, and read response generation.
3. **SRAM Controller:** Manages SRAM access, address decoding, read/write control, and byte-enable operations.
4. **SRAM Model:** Implements a behavioral 256 × 32-bit synchronous memory.
5. **Top Module:** Connects the AXI interfaces, SRAM controller, and memory model, and handles transaction ownership and arbitration priority.

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

Seven SystemVerilog Assertions (SVA) properties are implemented and verified:

1. AXI write address channel stability during backpressure.
2. AXI write data channel stability during backpressure.
3. AXI write response channel stability during backpressure.
4. AXI read address channel stability during backpressure.
5. AXI read data channel stability during backpressure.
6. Correct `WLAST` generation.
7. Correct `RLAST` generation.

### Verification Results

| Verification Metric | Result |
|---|---:|
| Functional checks passed | 473 |
| Functional checks failed | 0 |
| SVA properties passed | 7 |
| SVA properties failed | 0 |

**Simulation Status: ALL TESTS PASSED**

The results represent the current testbench and assertion suite. They do not imply exhaustive verification of every possible AXI4 transaction or corner case.

## Tools and Technologies

- **HDL:** Verilog, SystemVerilog
- **Simulation and Design:** AMD Xilinx Vivado 2025.1
- **Verification:** SystemVerilog Testbenches, SVA
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
- Add more burst-length and back-to-back transaction tests.
- Improve functional coverage.
- Perform synthesis and timing analysis.
- Explore FPGA implementation and resource utilization.

## Author

**Jay Jain**  
Electronics and Communication Engineering  
L. D. College of Engineering, Ahmedabad

GitHub: [jayjain2365](https://github.com/jayjain2365)
