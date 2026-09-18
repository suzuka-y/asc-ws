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

proj_path = Path(__file__).resolve().parent
repo_root = proj_path.parent

_pdk_root_env = os.getenv("PDK_ROOT")
if _pdk_root_env:
    pdk_root = Path(_pdk_root_env)
    if not pdk_root.is_absolute():
        pdk_root = (repo_root / pdk_root).resolve()
else:
    pdk_root = (repo_root / "gf180mcu").resolve()

pdk = os.getenv("PDK", "gf180mcuD")
scl = os.getenv("SCL", "gf180mcu_fd_sc_mcu7t5v0")
pad = os.getenv("PAD", "gf180mcu_fd_io")
sram = os.getenv("SRAM", "gf180mcu_fd_ip_sram")
slot = os.getenv("SLOT", "1x1")

hdl_toplevel = "chip_top"
ASC_CLOCK_MHZ = 74.25
ASC_CLOCK_PERIOD_PS = 13468
ASC_OUTPUT_PADS = 28
ASC_PIPELINE_CLOCKS = 14


async def set_defaults(dut):
    dut.input_PAD.value = 0


async def enable_power(dut):
    dut.VDD.value = 1
    dut.VSS.value = 0


async def start_clock(clock):
    c = Clock(clock, ASC_CLOCK_PERIOD_PS, "ps")
    cocotb.start_soon(c.start())


def pad_bit(dut, index):
    value = dut.bidir_PAD.value[index]
    text = str(value).lower()
    assert text in ("0", "1"), f"bidir_PAD[{index}] is unresolved: {value}"
    return int(text)


async def observe_pclk_toggle(dut, window_ns=50):
    states = set()
    for _ in range(window_ns):
        states.add(pad_bit(dut, 0))
        if states == {0, 1}:
            return
        await Timer(1, "ns")
    assert states == {0, 1}, f"PCLK did not toggle; observed states: {states}"


async def assert_reset(dut):
    dut.rst_n_PAD.value = 0
    await Timer(100, "ns")


async def release_reset(dut):
    await Timer(3, "ns")
    dut.rst_n_PAD.value = 1


async def start_up(dut):
    await set_defaults(dut)
    if gl:
        await enable_power(dut)
    await start_clock(dut.clk_PAD)
    await assert_reset(dut)


@cocotb.test()
async def test_asc_v043_reset_and_smoke(dut):
    logger = logging.getLogger("asc_testbench")
    logger.info("Starting ASC v0.43 at 74.25 MHz...")

    await start_up(dut)
    await observe_pclk_toggle(dut)

    # 720p uses positive HSYNC/VSYNC, so inactive is LOW.
    assert pad_bit(dut, 1) == 0, "HSYNC must be inactive-low during reset"
    assert pad_bit(dut, 2) == 0, "VSYNC must be inactive-low during reset"
    assert pad_bit(dut, 3) == 0, "DE must be low during reset"
    for index in range(4, 28):
        assert pad_bit(dut, index) == 0, f"RGB pad {index} must be black during reset"

    await release_reset(dut)

    # 2-stage reset synchronization + 13-clock internal fill + 1 DPI output register.
    await ClockCycles(dut.clk_PAD, 6)
    assert pad_bit(dut, 1) == 0
    assert pad_bit(dut, 2) == 0
    assert pad_bit(dut, 3) == 0
    for index in range(4, 28):
        assert pad_bit(dut, index) == 0

    await ClockCycles(dut.clk_PAD, ASC_PIPELINE_CLOCKS + 1)

    # Early active raster: syncs inactive LOW, DE HIGH.
    assert pad_bit(dut, 1) == 0, "HSYNC should be inactive-low after startup"
    assert pad_bit(dut, 2) == 0, "VSYNC should be inactive-low after startup"
    assert pad_bit(dut, 3) == 1, "DE should be active after v0.43 pipeline fill"

    for index in range(4, ASC_OUTPUT_PADS):
        pad_bit(dut, index)

    await observe_pclk_toggle(dut)
    logger.info("ASC v0.43 reset/integration smoke test passed")


def chip_top_runner():
    sources = []
    defines = {f"SLOT_{slot.upper()}": True}
    includes = [repo_root / "src"]

    defines[f"PDK_{pdk.replace('-','_')}"] = True
    defines[f"SCL_{scl}"] = True
    defines[f"PAD_{pad}"] = True
    defines[f"SRAM_{sram}"] = True

    if gl:
        sources.append(pdk_root / pdk / "libs.ref" / scl / "verilog" / f"{scl}.v")
        if scl != "gf180mcu_as_sc_mcu7t3v3":
            sources.append(pdk_root / pdk / "libs.ref" / scl / "verilog" / "primitives.v")

        sources.append(repo_root / f"final/pnl/{hdl_toplevel}.pnl.v")
        defines.update({"FUNCTIONAL": True, "USE_POWER_PINS": True})
    else:
        sources.append(repo_root / "src/chip_top.sv")
        sources.append(repo_root / "src/chip_core.sv")

        asc_rtl = [
            "asc_core.v",
            "dpi_output.v",
            "fade_level_decoder.v",
            "fade_scaler.v",
            "grid_offset_axis.v",
            "pattern_brick_fill.v",
            "pattern_brick_hollow.v",
            "pattern_cell_style.v",
            "pattern_corner_fill.v",
            "pattern_corner_hollow.v",
            "pattern_diagonal_fill.v",
            "pattern_diagonal_hollow.v",
            "pattern_gen.v",
            "pattern_mixer.v",
            "pattern_palette8.v",
            "pattern_square_fill.v",
            "pattern_square_hollow.v",
            "reset_synchronizer.v",
            "scene_controller.v",
            "scroll_phase.v",
            "timing_generator.v",
        ]

        asc_dir = repo_root / "src/asc"
        missing = [name for name in asc_rtl if not (asc_dir / name).is_file()]
        if missing:
            raise FileNotFoundError(
                "ASC v0.43 RTL deployment is incomplete. Missing: "
                + ", ".join(missing)
            )

        asc_core_text = (asc_dir / "asc_core.v").read_text(encoding="utf-8")
        required_tokens = [
            "rst_n_raw",
            "1280x720p60",
            "Total                   : 14 pixel clocks",
        ]
        missing_tokens = [t for t in required_tokens if t not in asc_core_text]
        if missing_tokens:
            raise RuntimeError(
                "src/asc/asc_core.v does not look like ASC v0.43. Missing: "
                + ", ".join(missing_tokens)
            )

        sources.extend(asc_dir / name for name in asc_rtl)

    sources += [
        pdk_root / pdk / f"libs.ref/{pad}/verilog/{pad}.v",
        repo_root / "ip/gf180mcu_ws_ip__logo/vh/gf180mcu_ws_ip__logo.v",
        repo_root / "ip/gf180mcu_ws_ip__marker/vh/gf180mcu_ws_ip__marker.v",
        repo_root / "ip/gf180mcu_ws_ip__qrcode_id/vh/gf180mcu_ws_ip__qrcode_id.v",
        repo_root / "ip/gf180mcu_ws_ip__shuttle_id/vh/gf180mcu_ws_ip__shuttle_id.v",
        repo_root / "ip/gf180mcu_ws_ip__project_id/vh/gf180mcu_ws_ip__project_id.v",
    ]

    build_args = []
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

    runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module="chip_top_tb,",
        plusargs=[],
        waves=True,
    )


if __name__ == "__main__":
    chip_top_runner()
