# Repository Guidelines

## Project Structure & Module Organization

- Each learning module lives in a numbered folder (for example, `1. mux2`, `6. UART`, `10. dual_port_ram`).
- Verilog sources are stored directly in each module folder as `.v` files.
- Testbenches follow the `_tb.v` suffix (for example, `mux2_tb.v`, `uart_tx_tb.v`).
- Constraint files appear as `.xdc` alongside the module they target.
- Editor settings live in `.vscode`.

## Build, Test, and Development Commands

- No build scripts are defined in this repo. Use your FPGA toolchain to synthesize or simulate each module.
- Example simulation with Icarus Verilog (if installed):
  `iverilog -g2012 -s mux2_tb -o mux2_tb.out "1. mux2/mux2.v" "1. mux2/mux2_tb.v"`
- Example run with `vvp`:
  `vvp mux2_tb.out`

## Coding Style & Naming Conventions

- Use 2-space indentation and keep line length reasonable for readability.
- Prefer lowercase file and module names with underscores (for example, `uart_tx.v`, `gray_converter.v`).
- Keep parameters and signal names descriptive; avoid single-letter names except for simple data paths.

## Testing Guidelines

- Add a matching `_tb.v` for new modules; keep the testbench in the same folder as the DUT.
- Focus on functional coverage (reset, boundary conditions, and basic timing behavior).
- Name the top testbench module to match the filename (for example, `uart_tx_tb`).

## Commit & Pull Request Guidelines

- Commit messages in history are short and imperative (for example, `Create hex8.v`, `Update README.md`, `Rename 6. uart_tx.v to 6. UART/uart_tx.v`).
- Keep commits scoped to one module or change set when possible.
- Pull requests should include a brief description, affected module folders, and simulation evidence if you ran it.
