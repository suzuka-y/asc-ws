# SPDX-FileCopyrightText: © 2025 Project Template Contributors
# SPDX-License-Identifier: Apache-2.0

import os
import logging
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles
from cocotb_tools.runner import get_runner

sim = os.getenv("SIM", "icarus")
gl = os.getenv("GL", False)
pdk_root = os.getenv("PDK_ROOT", Path(__file__).resolve().parent / "../gf180mcu")
pdk = os.getenv("PDK", "gf180mcuD")
scl = os.getenv("SCL", "gf180mcu_fd_sc_mcu7t5v0")
pad = os.getenv("PAD", "gf180mcu_fd_io")
sram = os.getenv("SRAM", "gf180mcu_fd_ip_sram")
slot = os.getenv("SLOT", "1x1")

hdl_toplevel = "chip_top"
ASC_CLOCK_MHZ = 74.25
ASC_CLOCK_PERIOD_PS = 13468  # nearest even-ps period for ~74.25 MHz (74.250074 MHz)


async def set_defaults(dut):
    """Set external digital inputs to known values."""
    dut.input_PAD.value = 0


async def enable_power(dut):
    """Drive explicit power pins used by the powered gate-level netlist."""
    dut.VDD.value = 1
    dut.VSS.value = 0


async def start_clock(clock):
    """Start the ASC v0.42 pixel clock at approximately 74.25 MHz."""
    # Clock requires a period that can be represented exactly by simulator
    # time precision. 13468 ps gives a 50% duty cycle with integer-ps halves.
    c = Clock(clock, ASC_CLOCK_PERIOD_PS, "ps")
    cocotb.start_soon(c.start())


async def reset(reset_signal, active_low=True, time_ns=1000):
    """Apply reset and then release it."""
    cocotb.log.info("Reset asserted...")

    reset_signal.value = not active_low
    await Timer(time_ns, "ns")
    reset_signal.value = active_low

    cocotb.log.info("Reset deasserted.")


async def start_up(dut):
    """Run the common startup sequence."""
    await set_defaults(dut)
    if gl:
        await enable_power(dut)
    await start_clock(dut.clk_PAD)
    await reset(dut.rst_n_PAD)


def pad_bit(dut, index):
    """Read one resolved bidirectional pad bit as an integer."""
    value = dut.bidir_PAD.value[index]
    text = str(value).lower()
    assert text in ("0", "1"), f"bidir_PAD[{index}] is unresolved: {value}"
    return int(text)


@cocotb.test()
async def test_asc_smoke(dut):
    """Basic wafer.space integration smoke test for ASC v0.42."""

    logger = logging.getLogger("asc_testbench")

    logger.info("Starting ASC v0.42...")
    await start_up(dut)

    # ASC v0.42 has a fixed 10-clock pixel pipeline. Give the pipeline a few
    # extra clocks after reset release before checking the external outputs.
    await ClockCycles(dut.clk_PAD, 16)

    # At the beginning of a 720p frame, positive-polarity HSYNC and VSYNC are
    # inactive-Low and DE is active. These are bidir_PAD[1], [2], and [3].
    assert pad_bit(dut, 1) == 0, "HSYNC should be inactive-low after startup"
    assert pad_bit(dut, 2) == 0, "VSYNC should be inactive-low after startup"
    assert pad_bit(dut, 3) == 1, "DE should be active near the start of frame"

    # RGB888 outputs must all resolve to binary values. Avoid reading
    # the full bidir_PAD vector because unused upper pads are intentionally left
    # in input mode and may therefore be Z in RTL simulation.
    for index in range(4, 28):
        pad_bit(dut, index)

    # PCLK is mapped to bidir_PAD[0]. Do not compare its phase directly with
    # clk_PAD: the external clock enters through an input pad model and PCLK
    # leaves through a bidirectional output pad model, so pad propagation
    # delay is expected. For this integration smoke test, verify only that the
    # external PCLK pad resolves and toggles between both logic levels.
    pclk_states = set()
    for _ in range(80):
        pclk_states.add(pad_bit(dut, 0))
        if pclk_states == {0, 1}:
            break
        await Timer(1, "ns")

    assert pclk_states == {0, 1}, (
        f"PCLK did not toggle at bidir_PAD[0]; observed states: {pclk_states}"
    )

    logger.info("ASC v0.42 smoke test passed")


def chip_top_runner():

    proj_path = Path(__file__).resolve().parent

    sources = []
    defines = {f"SLOT_{slot.upper()}": True}
    includes = [proj_path / "../src/"]

    # Set the LibreLane PDK/SCL/PAD defines.
    defines[f"PDK_{pdk.replace('-','_')}"] = True
    defines[f"SCL_{scl}"] = True
    defines[f"PAD_{pad}"] = True
    defines[f"SRAM_{sram}"] = True

    if gl:
        # SCL models
        sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / f"{scl}.v")
        if scl != "gf180mcu_as_sc_mcu7t3v3":
            sources.append(Path(pdk_root) / pdk / "libs.ref" / scl / "verilog" / "primitives.v")

        # Use the powered post-layout netlist.
        sources.append(proj_path / f"../final/pnl/{hdl_toplevel}.pnl.v")

        defines.update({"FUNCTIONAL": True, "USE_POWER_PINS": True})
    else:
        sources.append(proj_path / "../src/chip_top.sv")
        sources.append(proj_path / "../src/chip_core.sv")

        # ASC v0.42 RTL source files.
        sources.extend(sorted((proj_path / "../src/asc").glob("*.v")))

    sources += [
        # IO pad models
        Path(pdk_root) / pdk / f"libs.ref/{pad}/verilog/{pad}.v",

        # Custom wafer.space IP
        proj_path / "../ip/gf180mcu_ws_ip__logo/vh/gf180mcu_ws_ip__logo.v",
        proj_path / "../ip/gf180mcu_ws_ip__marker/vh/gf180mcu_ws_ip__marker.v",
        proj_path / "../ip/gf180mcu_ws_ip__qrcode_id/vh/gf180mcu_ws_ip__qrcode_id.v",
        proj_path / "../ip/gf180mcu_ws_ip__shuttle_id/vh/gf180mcu_ws_ip__shuttle_id.v",
        proj_path / "../ip/gf180mcu_ws_ip__project_id/vh/gf180mcu_ws_ip__project_id.v",
    ]

    build_args = []

    if sim == "icarus":
        # For debugging:
        # build_args = ["-Winfloop", "-pfileline=1"]
        pass

    if sim == "verilator":
        build_args = ["--timing", "--trace", "--trace-fst", "--trace-structs"]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        defines=defines,
        always=True,
        includes=includes,
        build_args=build_args,
        waves=True,
    )

    plusargs = []

    runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module="chip_top_tb,",
        plusargs=plusargs,
        waves=True,
    )


if __name__ == "__main__":
    chip_top_runner()
