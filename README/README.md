# Parameterized UART Transmitter and Receiver in Verilog

A simulation-focused UART RTL project written in Verilog. It implements separate transmitter and receiver finite-state machines and a testbench that checks clean loopback transfers as well as parity and framing-error detection.

## Features

- 8-bit serial data, transmitted least-significant bit first.
- Start bit (logic `0`) and stop bit (logic `1`).
- Configurable parity using `PARITY_MODE`:
  - `0`: no parity (`8N1`)
  - `1`: even parity (`8E1`)
  - `2`: odd parity (`8O1`)
- Configurable number of system-clock cycles per serial bit using `CLKS_PER_BIT`.
- Transmitter status outputs: `o_tx_active`, `o_tx_done`, and `o_tx_serial`.
- Receiver outputs: `o_rx_dv`, `o_rx_byte`, `o_parity_error`, and `o_frame_error`.
- Two-register synchronizer on the receiver's asynchronous serial input.
- A self-checking testbench with an internal TX-to-RX loopback and controlled malformed frames.
- VCD waveform generation for inspection in GTKWave.

## How the design works

The transmitter uses an FSM to send the start bit, eight data bits, an optional parity bit, and the stop bit. `CLKS_PER_BIT` controls how many rising edges of `i_clk` each serial bit lasts. Data is sent LSB-first.

The receiver synchronizes its serial input, validates the start bit near its midpoint, samples the eight data bits, optionally checks parity, and checks the stop bit. `o_rx_dv` pulses when a frame has been received; `o_parity_error` and `o_frame_error` indicate parity and stop-bit errors for that received frame.

For a target clock frequency and baud rate, choose an integer `CLKS_PER_BIT` approximately equal to `clock_frequency / baud_rate`; use `CLKS_PER_BIT >= 2` because the receiver validates the start bit using an integer half-bit count. The supplied testbench uses `CLKS_PER_BIT = 16` and a 10 ns clock period to keep simulation short. This RTL project does not include a separate baud-rate generator or demonstrate a physical UART connection.

## Files

Use these filenames in the repository:

```text
README.md
uart_advanced.v       # UART TX and RX modules
uart_advanced_tb.v    # simulation testbench
```

The two source files supplied with the project may currently have names such as `uart(1).v` and `uart_tb(1).v`; rename them to the filenames above, or update the commands below to match your filenames.

## Tools

- **Verilog HDL** — transmitter, receiver, and testbench.
- **Icarus Verilog** — compile and simulate the testbench (`iverilog` and `vvp`).
- **GTKWave** — inspect the generated VCD waveform.
- **VS Code** — optional editor for the source files.

## Run the simulation

Run these commands from the directory containing both Verilog files:

```bash
iverilog -g2012 -s tb_uart_advanced -o uart_sim uart_advanced.v uart_advanced_tb.v
vvp uart_sim
gtkwave uart_advanced.vcd
```

The first command compiles the design and selects `tb_uart_advanced` as the simulation top module. The second runs the simulation. The testbench writes `uart_advanced.vcd`, which the third command opens in GTKWave.

If you keep the original uploaded filenames, quote them because they contain parentheses:

```bash
iverilog -g2012 -s tb_uart_advanced -o uart_sim "uart(1).v" "uart_tb(1).v"
vvp uart_sim
gtkwave uart_advanced.vcd
```

## Testbench coverage

With `CLKS_PER_BIT = 16` and `PARITY_MODE = 1` (even parity), the testbench checks:

1. Clean TX-to-RX loopback frames for `0x00`, `0xA5`, `0x3C`, and `0xFF`.
2. A frame with an intentionally incorrect parity bit; the receiver is expected to assert `o_parity_error` and not `o_frame_error`.
3. A frame with a correct parity bit but a low stop bit; the receiver is expected to assert `o_frame_error` and not `o_parity_error`.
4. Received data bytes against expected values and the expected error flags.

A successful run ends with the testbench message:

```text
ALL ADVANCED UART TESTS PASSED
```

The current testbench exercises only even-parity mode. The no-parity and odd-parity RTL configurations exist but should be given their own tests before claiming those modes are verified. Reset during a frame, back-to-back frames, randomized traffic, and timing/baud mismatch are not covered by this testbench.

## Suggested GTKWave signals

Start with `clk`, `rst`, `tx_dv`, `tx_byte`, `tx_active`, `tx_serial`, `tx_done`, `rx_line`, `rx_dv`, `rx_byte`, `parity_error`, and `frame_error`. Expand the `tb_uart_advanced` hierarchy to select the signals.

## Learning goals

This project practices FSM-based RTL design, clock-cycle timing, serial framing, parity generation/checking, input synchronization, self-checking simulation, and waveform-based debugging.
