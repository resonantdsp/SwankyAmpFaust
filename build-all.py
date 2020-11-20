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
Build the DSP code into C++ headers. The headers provide the classes to which
are used in the `PushPullAmp` class.
"""

import json
from pathlib import Path

import numpy as np
from matplotlib import pyplot as plt

from dspfit import utils, wrapdsp


def inspect_behaviour(func, kwargs, plot_dir: Path):
    """
    Plot the time and frequency behaviour of the function.
    """

    fs = int(48e3)
    length = fs
    impulse = np.zeros(length, dtype="float32")
    impulse[length // 2] = 1
    zeros = np.zeros(length, dtype="float32")

    # run on an empty buffer
    out = func(fs, zeros, **kwargs)[0]
    # plot the output signal
    plt.plot(out)
    plt.savefig(str(plot_dir / f"empty-signal.png"))
    plt.clf()

    # run on a buffer with an impulse
    out = func(fs, impulse, **kwargs)[0]
    # plot the output signal
    plt.plot(out)
    plt.savefig(str(plot_dir / f"impulse-signal.png"))
    plt.clf()
    # plot the fft response to an impulse (which is the frequency domain
    # representation of the transfer function)
    fft, _ = utils.calc_fft(out, fs, do_window=False, use_db=True, rezero=False)
    plt.plot(fft)
    plt.savefig(str(plot_dir / f"impulse-response.png"))
    plt.clf()


def main(path_dsp: str, plot_dir: str):
    path_dsp = Path(path_dsp)
    plot_dir = Path(plot_dir) if plot_dir else None
    path_build = Path("build")
    path_headers = Path("headers")
    path_build.mkdir(parents=True, exist_ok=True)
    path_headers.mkdir(parents=True, exist_ok=True)

    if plot_dir is not None:
        plot_dir = Path(plot_dir)

    # remove previous build files
    for path in path_build.iterdir():
        if not path.is_file():
            continue
        path.unlink()

    # remove previous headers if not manual code
    for path in path_headers.iterdir():
        if not path.is_file():
            continue
        if path.suffix != ".h":
            continue
        if path.stem == "PushPullAmp":
            continue
        path.unlink()

    # gather the parameters from the triode parts for use in the combined
    # triode model
    with (path_dsp / "Triode.json").open("r") as fio:
        triode_json = json.load(fio)
    with (path_dsp / "TriodeGrid.json").open("r") as fio:
        triode_json.update(json.load(fio))
    with (path_dsp / "TriodePlate.json").open("r") as fio:
        triode_json.update(json.load(fio))
    with (path_dsp / "Triode.json").open("w") as fio:
        json.dump(triode_json, fio, indent="\t")

    # build each individual class that makes up the amp
    for class_name in (
        "Cabinet",
        "ToneStack",
        "Triode",
        "TetrodeGrid",
        "TetrodePlate",
    ):
        dsp_func, pars = wrapdsp.build_fausthpp(
            path_build=path_build,
            path_headers=path_headers,
            path_dsp=path_dsp,
            class_name=class_name,
        )

        if plot_dir is not None:
            class_plot_dir = plot_dir / class_name
            class_plot_dir.mkdir(parents=True, exist_ok=True)

            # measure with default parameters
            kwargs = {p: 0.0 for p in pars}
            # triode has parameters controlled by the PushPullAmp which don't
            # default at zero
            if class_name == "Triode":
                kwargs["mix"] = 1.0
                kwargs["overhead"] = 1.0
                kwargs["unscale"] = 1.0

            inspect_behaviour(dsp_func, kwargs, class_plot_dir)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("path_dsp", type=str)
    parser.add_argument("--plot_dir", type=str)
    args = parser.parse_args()
    main(**vars(args))
