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

import json
import math
from pathlib import Path
from typing import Callable, Iterable, Mapping, NamedTuple

import matplotlib as mpl
import numpy as np
import scipy as sp
import scipy.optimize

mpl.use("Agg")
from matplotlib import pyplot as plt

plt.style.use("seaborn")

from . import wavio


def wave_to_numpy(path: str, max_length: float = None) -> (np.ndarray, int):
    """
    Load a wave file as a numpy array.

    Args:
        path: path to the wave file
        max_length: return only up to this many seconds of data

    Returns:
        array of float values in range [0, 1], sample rate
    """
    data = wavio.read(path)

    rate = data.rate
    max_value = 2 ** (data.sampwidth * 8)

    values = np.mean(data.data, axis=1)
    values = values / float(max_value)

    if max_length is not None:
        max_samples = math.ceil(max_length * rate)
        values = values[:max_samples]

    return values, rate


def calc_fft(
    signal: Iterable[float],
    fs: float,
    do_window: bool = True,
    use_db: bool = True,
    rezero: bool = False,
) -> (np.ndarray, np.ndarray):
    """
    Calculate the FFT of a signal.

    Args:
        signal: signal value at the time points
        fs: samplig rate
        do_window: apply a hanning window to the signal
        use_db: convert the values to decibels relative to 0 db FS
        rezero: set the fft peak to zero

    Returns:
        the fft array and the array of fft bin frequencies
    """
    signal = np.asarray(signal)

    if do_window:
        window = np.hanning(len(signal))
        signal = signal * window

    fft = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1.0 / fs)

    if use_db:
        fft = np.abs(fft) ** 2
        if rezero:
            fft = 10 * np.log10(fft / np.max(fft))
        else:
            fft = 10 * np.log10(fft)

    return fft, freqs


def plot_fft(signal: Iterable[float], fs: float, **kwargs) -> plt.Figure:
    """
    Plot the real FFT spectrum for some signal with evenly spaced time samples.
    Note that the figure isn't shown, but is returned to the user.

    Args:
        signal: signal value at the time points
        fs: samplig rate
        kwargs: keyword arguments to pass so the `matplotlib.pyplot.plot` function

    Returns:
        `plt.Figure` on which the data has been plotted
    """
    fft, freqs = calc_fft(signal, fs, do_window=True, use_db=True, rezero=True)

    # plot with standard rantes, but don't show yet
    plt.plot(freqs, fft, **kwargs)
    plt.ylim((-80, +1))
    plt.xlim((10, 20000))
    plt.xscale("log")

    return plt.gcf()


class FitData(NamedTuple):
    fs: int
    time: np.ndarray
    signal_in: np.ndarray
    signal_out: np.ndarray
    mask: np.ndarray
    name: str


def plot_result(
    plot_dir: Path, fit_datas: Iterable[FitData], func: Callable, kwargs: Mapping
):
    plot_dir.mkdir(parents=True, exist_ok=True)

    for data in fit_datas:
        pred = func(data.fs, data.signal_in, **kwargs)[0]

        fig = plt.figure(figsize=(600 / 96, 400 / 96), dpi=96)
        plt.plot(data.time, data.signal_out)
        plt.plot(data.time, pred, ls=":")
        plt.xlabel("Time (s)")
        plt.ylabel("Voltage (scaled)")
        plt.tight_layout()
        plt.savefig(str(plot_dir / f"{data.name}_sig.png"))
        plt.close(fig)

        fig = plt.figure(figsize=(600 / 96, 400 / 96), dpi=96)
        plot_fft(data.signal_out, data.fs)
        plot_fft(pred, data.fs, ls=":")
        plt.xlabel("Frequency (Hz)")
        plt.ylabel("Decibels")
        plt.tight_layout()
        plt.savefig(str(plot_dir / f"{data.name}_fft.png"))
        plt.close(fig)


def fit_sim_data(
    datas: Iterable[FitData],
    model_func: Callable,
    parameters: Iterable[str],
    values: Iterable[float],
    fix_pars: Iterable[str],
    methods: Iterable[str] = ["Powell"],
    randomness: float = 0,
):
    fix_pars = set(fix_pars)
    fit_pars = [p for p in parameters if p not in fix_pars]

    par_values = {p: v for p, v in zip(parameters, values)}

    def fun(x):
        kwargs = dict(par_values)
        # copy the fit values into the dict of parameters
        for par, val in zip(fit_pars, x):
            kwargs[par] = val

        err = 0
        for data in datas:
            pred = model_func(data.fs, data.signal_in, **kwargs)[0]
            err_scale = (
                np.max(data.signal_out[data.mask]) - np.min(data.signal_out[data.mask])
            ) ** 2
            err += np.mean((pred[data.mask] - data.signal_out[data.mask]) ** 2) / (
                err_scale + 1e-12
            )

        return err * 1e3

    x0 = list(values)

    num_fits = len(methods)
    for ifit, method in enumerate(methods):
        if num_fits >= 1 and randomness > 0:
            random_factor = randomness * (num_fits - ifit - 1) / (num_fits - 1)
            x0 += np.random.randn(len(x0)) * random_factor
        res = sp.optimize.minimize(fun=fun, x0=x0, method=method)
        print(f"loss: {res.fun:+.4e}")
        x0 = res.x

    kwargs = dict(par_values)
    for par, val in zip(fit_pars, res.x):
        kwargs[par] = float(val)

    return kwargs


def update_defaults(path_dsp: Path, class_name: str, kwargs, ignore={}):
    with (path_dsp / f"{class_name}.json").open("r") as fio:
        pars_info = json.load(fio)

    for par, value in kwargs.items():
        if par in ignore:
            continue
        prior = float(pars_info[par].get("default", 0))
        pars_info[par]["default"] = value + prior

    with (path_dsp / f"{class_name}.json").open("w") as fio:
        json.dump(pars_info, fio, indent="\t")
