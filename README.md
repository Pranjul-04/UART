# UART Communication System in Verilog

## Overview

This project implements a **Universal Asynchronous Receiver Transmitter (UART)** in **Verilog HDL**.
The design supports **8-bit data transmission with even parity** and uses **oversampling for reliable reception**.

The system includes:

* UART Transmitter
* UART Receiver
* Baud Rate Generator
* Top Module integrating TX and RX
* Testbench for simulation

The project is designed for an FPGA environment with a **50 MHz system clock** and **9600 baud rate communication**.

---

## Features

* 8-bit serial data communication
* Even parity generation and checking
* Start and stop bit handling
* 16× oversampling in receiver
* Retransmission capability for received data
* Separate baud rate enable signals for TX and RX
* Fully synthesizable Verilog modules

---

## System Architecture

The UART system consists of the following modules:

### 1. Baud Rate Generator

Generates enable pulses required for transmission and reception.

* System clock: **50 MHz**
* Baud rate: **9600 bps**
* TX enable pulse: every **5208 clock cycles**
* RX enable pulse: every **325 clock cycles** (16× oversampling)

---

### 2. UART Transmitter

The transmitter sends serial data in the following format:

```
Start Bit | Data Bits (8) | Parity Bit | Stop Bit
    0     |   D0-D7       | Even Parity|   1
```

Finite State Machine (FSM) states:

* IDLE
* START
* DATA
* PARITY
* STOP

---

### 3. UART Receiver

The receiver samples incoming data using **16× oversampling** to improve reliability.

FSM states:

* IDLE
* START
* DATA
* PARITY
* STOP
* CHECK

The receiver:

* Reconstructs the received byte
* Verifies parity
* Flags parity errors

---

### 4. UART Top Module

The top module integrates:

* Baud Rate Generator
* Transmitter
* Receiver

It also implements **data retransmission logic** where the received data can be sent back after validation.

---

## Project Structure

```
UART_Project/
│
├── uart_transmitter.v
├── uart_receiver.v
├── baud_rate_generator.v
├── uart_top.v
│
├── testbench/
│   └── uart_tb.v
│
└── README.md
```

---

## Simulation

The design is simulated using tool:

* ModelSim

### Running Simulation

1. Compile all Verilog files
2. Run the testbench
3. Observe the waveform

Expected transmission frame:

```
Start → Data[0] → Data[1] → ... → Data[7] → Parity → Stop
```

---

## Design Considerations

### Oversampling

The receiver uses **16× oversampling** to detect the middle of each bit, improving noise tolerance.

### Parity Checking

Even parity is used to detect single-bit transmission errors.

### FSM Design

Finite State Machines are used to control both transmission and reception.

The design follows good hardware design practices:

* Clear state definitions
* Sequential and combinational logic separation
* Reset initialization

---

## Possible Improvements

Future improvements may include:

* Configurable baud rate
* Support for multiple parity modes
* FIFO buffering
* Interrupt support
* Hardware flow control

---

## Author

**Pranjul Singhal**
B.Tech Electronics and Communication Engineering

---

## License

This project is open-source and can be used for educational purposes.
