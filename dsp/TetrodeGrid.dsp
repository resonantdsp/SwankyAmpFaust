//  Swanky Amp tube amplifier simulation
//  Copyright (C) 2020  Garrin McGoldrick
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.

import("stdfaust.lib");
import("common.dsp");

tetrode_grid = environment {
    // See `triode_grid.dsp` for info on common functionality

    hp_freq = nentry("hp_freq",0,0,1,1);

    // The highpass applies to the signal with some DC offset, leading to some
    // dynamics as the DC offset is being subtracted, want to preserve those
    // early dyanamics
    offset1 = nentry("offset1",0,0,1,1);

    // This offset affects how much signal is being accumulated into the 
    // smoothing
    offset2 = nentry("offset2",0,0,1,1);

    // Smoothing time constant
    taus = nentry("taus",0,0,1,1);

    level = nentry("level",0,0,1,1);
    tau = nentry("tau",0,0,1,1);
    ratio = nentry("ratio",0,0,1,1);
    cap = nentry("cap",0,0,1,1);

    tau1 = tau : 1.0 / (ba.sec2samp(_) + 1);
    tau2 = tau * ratio : 1.0 / (ba.sec2samp(_) + 1);

    full = _ 
        : -(offset1)
        : fi.highpass(1, hp_freq) 

        // The difference between the grid input and output looks like an
        // exponentially smoothed version of the signal, subtracting this
        // then recovers the correct result, seems relted to the drift on
        // the screen
        : -(offset2)
        <: _, si.smooth(ba.tau2pole(taus)) : -

        // Same effect observed with the triode grid signal
        <: _, max(0, _ - level)
        : _, calc_charge_cap(tau1, tau2, cap)
        : -

        : _;
};

process = tetrode_grid.full;
