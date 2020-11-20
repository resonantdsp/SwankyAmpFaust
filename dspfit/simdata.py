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
Data structures and loading of simulation data.
"""

import os
from typing import AbstractSet, List, Mapping

import numpy as np
import scipy as sp
import scipy.interpolate


class SimData:
    def __init__(
        self,
        signal: str,
        amplitude: float,
        time: np.ndarray,
        vs: Mapping[str, np.ndarray],
        fs: int,
    ):
        self.signal = signal
        self.amplitude = amplitude
        self.time = time
        self.vs = vs
        self.fs = fs


def load_data(path: str, keep_signals: AbstractSet[str] = None) -> List[SimData]:
    """
    Builds SimData objects from files in a given directory.

    Args:
        path: path of directory in which to find simulation data
        keep_signals: store only these signal names

    Returns:
        list of loaded data
    """
    sim_datas = list()

    for file_name in sorted(os.listdir(path)):
        if not file_name.endswith(".npy"):
            continue
        file_name = file_name[:-4]

        try:
            signal, amplitude = file_name.split("_")
            amplitude = float(amplitude)
        except ValueError:
            continue

        data = np.load(os.path.join(path, f"{file_name}.npy"))

        if keep_signals is None:
            vs = {n: data[n] for n in data.dtype.names if n != "time"}
        else:
            vs = {
                n: data[n]
                for n in data.dtype.names
                if n != "time" and n in keep_signals
            }

        sim_datas.append(
            SimData(
                signal=signal, amplitude=amplitude, time=data["time"], vs=vs, fs=None
            )
        )

    return sim_datas


def resample_sim_data(sim_data: SimData, sample_rate: int) -> SimData:
    """
    Re-sample the simulation with fixed step size.

    Args:
        sim_data: the data to re-sample
        sample_rate: new data will have this sample rate

    Returns:
        a new SimData instance with re-interpolated data
    """
    t0 = sim_data.time[0]
    t1 = sim_data.time[-1]

    num_points = int((t1 - t0) * sample_rate)
    t1 = t0 + num_points / sample_rate
    time = np.linspace(t0, t1, num_points)

    vs = dict()

    for name, signal in sim_data.vs.items():
        poly = sp.interpolate.interp1d(sim_data.time, signal, kind="linear")
        signal = np.asarray(poly(time))
        vs[name] = signal

    return SimData(
        signal=sim_data.signal,
        amplitude=sim_data.amplitude,
        time=time,
        vs=vs,
        fs=sample_rate,
    )
