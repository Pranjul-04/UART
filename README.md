# UART (Universal Asynchronous Receiver/Transmitter)

A UART design written in Verilog, built using **Quartus Prime** and simulated using **ModelSim**. It supports full-duplex serial communication with even parity checking, framing error detection, and majority-vote (3x oversampling) noise filtering on the receiver side. The testbench actively injects bit errors, noise glitches, and line breaks onto the serial line to validate error handling.

## Table of Contents

- [Features](#features)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
- [Module Details](#module-details)
- [Frame Format](#frame-format)
- [Baud Rate Calculation](#baud-rate-calculation)
- [Top-Level FSM](#top-level-fsm)
- [Testbench Scenarios](#testbench-scenarios)
- [Getting Started](#getting-started)
- [Sample Output](#sample-output)
- [Known Limitations](#known-limitations)
- [Future Improvements](#future-improvements)

## Features

- 8-bit data transmission with start bit, even parity bit, and stop bit
- Configurable baud rate generation (default: ~9600 baud from a 20 MHz clock)
- Receiver uses 16x oversampling with a 3-sample majority vote to filter out noise glitches
- Error detection: parity error and frame error flags, combined into a single `status_error` signal
- Simple FSM-based top-level controller to coordinate TX/RX handshaking
- Self-checking testbench with fault injection (bit flips, double-bit corruption, noise, and line breaks)

## Project Structure

```
.
├── UART_top.v              # Top-level module (FSM + submodule instantiation)
├── baud_rate_generator.v   # TX/RX baud rate enable pulse generator
├── uart_transmitter.v      # Serial transmitter
├── uart_receiver.v         # Serial receiver with oversampling + majority vote
├── UART_tb.v               # Testbench
├── data.hex                # Test data loaded via $readmemh
└── uart_waveform.vcd        # Generated waveform dump (after simulation)
```

## Architecture

```
                ┌─────────────────────────┐
   tx_start ──▶ │                         │
   Data_in  ──▶ │                         │──▶ Data_out
                │        UART_top         │──▶ rx_ready
                │   (FSM + Baud Gen +      │──▶ status_error
                │   TX + RX submodules)    │──▶ tx_serial_out
   rx_serial_in ▶│                         │
                └─────────────────────────┘
```

`UART_top` instantiates and wires together the baud rate generator, transmitter, and receiver, and drives a small handshake FSM that latches `Data_in`, kicks off a transmission, waits for the receiver to finish, and checks for errors.

## Module Details

### `baud_rate_generator`
Free-running counters clocked by the system clock generate periodic one-cycle enable pulses:
- `tx_counter` rolls over every 5208 clock cycles → `tx_enb` (baud tick for the transmitter)
- `rx_counter` rolls over every 325 clock cycles → `rx_enb` (16x oversampling tick for the receiver, i.e. ~16 ticks per bit period)

### `uart_transmitter`
A 5-state FSM (`IDLE → START → DATA → PARITY → STOP`) that, on `wr_enb`, latches the input byte, computes even parity (`^data_in`), and shifts the frame out one bit per `tx_enb` pulse. `busy` is high whenever the FSM is not in `IDLE`.

### `uart_receiver`
A 4-state FSM (`START → DATA → PARITY → STOP`) that oversamples the incoming line at `rx_enb` ticks. For each bit period it captures 3 samples (at sample counts 5, 6, 7) and uses majority voting to decide the bit value, which rejects narrow noise glitches. It flags:
- `parity_error` if the computed parity doesn't match the received parity bit
- `frame_error` if the stop bit is not sampled as `1`

`ready` pulses high once a full byte (data + parity + stop) has been received, and can be cleared externally via `ready_clr`.

### `UART_top`
A 5-state FSM (`IDLE → WAIT_TX_IDLE → SEND → WAIT_RX → CHECK`) that:
1. Latches `Data_in` when `tx_start` is asserted
2. Waits for the transmitter to be free, then pulses `wr_enb` to start sending
3. Waits for `rx_ready` from the receiver
4. Checks `status_error`; if an error occurred it retries the send, otherwise it returns to `IDLE`

## Frame Format

```
 ___      _______________________      _____      ____
|   |    |                       |    |     |    |
| S |D0 D1 D2 D3 D4 D5 D6 D7      | P  |  1  |  idle...
|___|_______________________|____|_____|
 Start          8 data bits    Parity  Stop
 (0)                          (even)   (1)
```

## Baud Rate Calculation

With a 20 MHz clock:
- TX baud tick every 5208 clocks → ≈ 20,000,000 / 5208 ≈ **3840 Hz** bit rate
- RX oversampling tick every 325 clocks → 16 samples per TX bit period (325 × 16 ≈ 5200 ≈ 5208)

Adjust the counter rollover values in `baud_rate_generator` to target a different baud rate for your system clock.

## Top-Level FSM

| State | Behavior |
|---|---|
| `IDLE` | Waits for `tx_start`; latches `Data_in` |
| `WAIT_TX_IDLE` | Waits until the transmitter is not busy |
| `SEND` | Pulses `wr_enb` to begin transmission |
| `WAIT_RX` | Waits for `rx_ready` |
| `CHECK` | Clears `ready`; re-sends on error, else returns to `IDLE` |

## Testbench Scenarios

The testbench (`UART_tb`) loops the transmitter's serial output back into the receiver (`rx_serial_in = tx_serial_out`) and can override the line with `inject_err`/`err_val` to simulate line faults. It exercises:

1. **Normal send** – basic transmit/receive check against values loaded from `data.hex`
2. **Data corruption** – flips a single, chosen data bit mid-transmission to verify parity detects it and the top-level FSM auto-recovers by resending
3. **Double-bit corruption** – flips two bits to demonstrate a case even parity *cannot* catch (a silent failure — expected, since even parity only detects odd numbers of bit errors)
4. **Mid-bit noise** – injects a very narrow glitch (well short of a full sample window) to confirm the majority-vote oversampling filters it out
5. **Break condition** – holds the line low for multiple bit periods to simulate a full line break, then checks that the receiver recovers cleanly once the line is released

## Getting Started

1. Open **Quartus Prime** and create a new project (or open the existing `.qpf`).
2. Add all Verilog source files: `UART_top.v`, `baud_rate_generator.v`, `uart_transmitter.v`, `uart_receiver.v`.
3. Set `UART_top` as the top-level entity for synthesis.
4. In Quartus, go to **Tools → Options → EDA Tool Options** and point it to your ModelSim installation, then set ModelSim as the simulation tool under **Assignments → Settings → EDA Tool Settings → Simulation**.
5. Launch ModelSim from Quartus (**Tools → Run Simulation Tool → RTL Simulation**), or open ModelSim directly and compile all source files plus `UART_tb.v`.
6. Make sure `data.hex` is present in the simulation working directory (used by `$readmemh`).
7. Run the simulation (`run -all` in the ModelSim console) and check the transcript for `[PASS]` / `[FAIL]` messages.
8. Open `uart_waveform.vcd` in a waveform viewer (e.g. GTKWave, or ModelSim's own waveform window) to inspect signal-level behavior.

## Sample Output

```
[PASS] SENT: 11 | RECEIVED: 11
[PASS] SENT: 22 | RECEIVED: 22
PARITY CAUGHT IT. AUTO-RECOVERED: a5
ILENT FAILURE ACHIEVED. RECEIVED: xx | Parity failed to detect 2-bit flip.
RECEIVER MAJORITY VOTING IGNORED NOISE. RECEIVED: f0
[PASS] RECOVERED FROM FULL BREAK. RECEIVED: 5a
```

## Known Limitations

- Even parity can only detect an **odd** number of bit errors per frame; simultaneous (even-count) bit flips go undetected, as intentionally demonstrated by the double-bit corruption test.
- Baud rate values are hard-coded for a specific clock frequency; changing the system clock requires recalculating the counter rollover values.
- No hardware flow control (RTS/CTS) or FIFO buffering — one byte is handled at a time.

## Future Improvements

- Parameterize clock frequency and baud rate instead of hard-coding counter values
- Add TX/RX FIFOs for buffered, back-to-back transfers
