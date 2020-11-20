#!/usr/bin/env python

#  Swanky Amp tube amplifier simulation
#  Copyright (C) 2020  Garrin McGoldrick
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/>.

"""
Measure the change in signal size as the amp drive is changed.

Used to build the calibration curves found in `PushPullAmp`. See `README.md`
for more information on how to use this.
"""

from pathlib import Path
from typing import Callable, Mapping

import numpy as np

from dspfit import simdata, utils, wrapdsp


def calibrate_sweep(
    push_pull: Callable, push_pull_pars: Mapping[str, float], parameter: str
):
    signal, fs = utils.wave_to_numpy("data/signal.wav")
    if len(signal.shape) == 2:
        signal = signal[:, 0]

    values = list()
    kwargs = push_pull_pars.copy()
    for value in np.linspace(-1, +1, 10 + 1):
        kwargs[parameter] = value
        level1 = np.std(signal)
        amplified = push_pull(fs, signal, **kwargs)[0]
        level2 = np.std(amplified)

        factor = level1 / level2
        values.append(factor)

    print(",".join([f"{v:.6e}f" for v in values]))


def main():
    path_headers = Path("headers")
    path_build = Path("build")

    with (path_headers / "PushPullAmp.h").open("r") as fio:
        code = fio.read()

    push_pull_pars = {
        # a typical configuration
        "triode_num_stages": 3,
        "triode_overhead": 0,
        "triode_hp_freq": 0,
        "triode_grid_tau": 0,
        "triode_grid_ratio": 0,
        "triode_grid_level": 0,
        "triode_grid_clip": 0,
        "triode_plate_bias": 0,
        "triode_plate_comp_ratio": 0,
        "triode_plate_comp_level": 0,
        "triode_plate_comp_offset": 0,
        "triode_drive": 0,
        "tetrode_hp_freq": 0,
        "tetrode_grid_tau": 0,
        "tetrode_grid_ratio": 0,
        "tetrode_plate_comp_depth": 0,
        "tetrode_plate_sag_tau": 0,
        # sag will result in significant loudness fluctuations over time
        "tetrode_plate_sag_toggle": -1,
        "tetrode_plate_sag_depth": 0,
        "tetrode_plate_sag_ratio": 0,
        "tetrode_plate_sag_factor": 0,
        "tetrode_drive": 0,
        "tonestack_bass": 0,
        "tonestack_mids": 0,
        "tonestack_treble": 0,
        "tonestack_selection": 0,
        "cabinet_brightness": 0,
        "cabinet_distance": 0,
        "cabinet_dynamic": 0,
        "input_level": 0,
        "output_level": 0,
    }

    wrapped = wrapdsp.wrap_compute(code, "PushPullAmp", push_pull_pars.keys())
    wrapdsp.compile_wrapped("PushPullAmp", path_build, path_headers, wrapped)
    push_pull = wrapdsp.make_callable("PushPullAmp", path_build, push_pull_pars.keys())

    print("pre amp sweep:")
    calibrate_sweep(push_pull, push_pull_pars, "triode_drive")
    print("power amp sweep:")
    calibrate_sweep(push_pull, push_pull_pars, "tetrode_drive")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    args = parser.parse_args()
    main(**vars(args))
