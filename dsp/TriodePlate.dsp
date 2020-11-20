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

triode_plate = environment {
    bias = nentry("bias",0,0,1,1);
    bias_corner = nentry("bias_corner",0,0,1,1);

    scale = nentry("scale",0,0,1,1);

    clip = nentry("plate_clip",0,0,1,1);
    corner = nentry("plate_corner",0,0,1,1);

    drift_level = nentry("drift_level",0,0,1,1);
    drift_tau = nentry("drift_tau",0,0,1,1);
    drift_depth = nentry("drift_depth",0,0,1,1);

    comp_level = nentry("comp_level",0,0,1,1);
    comp_tau = nentry("comp_tau",0,0,1,1);
    comp_ratio = nentry("comp_ratio",0,0,1,1);
    comp_depth = nentry("comp_depth",0,0,1,1);
    comp_cap = nentry("comp_cap",0,0,1,1);

    comp_corner = nentry("comp_corner",0,0,1,1);
    comp_offset = nentry("comp_offset",0,0,1,1);

    comp_tau1 = comp_tau : 1.0 / (ba.sec2samp(_) + 1);
    comp_tau2 = comp_tau * comp_ratio : 1.0 / (ba.sec2samp(_) + 1);

    nyquist = 1.0 / (2.0 * ba.samp2sec(1));
    lp_freq = nyquist * 0.9;

    full = _ 
        // found the fit works better with just a scale and a clip instead of
        // the full 1.5 power law treatement
        : *(scale)
        : soft_clip_down(bias_corner, -bias)

        // wave form is inverted on plate, easier to set defaults this way
        : *(-1)

        : soft_clip_down(corner, clip)

        <: _, max(drift_level) - drift_level
        : _, si.smooth(ba.tau2pole(drift_tau)) * drift_depth
        : -

        <: max(comp_level) - comp_level, _
        : calc_charge_cap(comp_tau1, comp_tau2, comp_cap) * comp_depth + comp_offset, _
        // NOTE: the clip level is relative to zero
        : soft_clip_up(comp_corner)

        : fi.lowpass(1, lp_freq)

        : _;
};

process = triode_plate.full;