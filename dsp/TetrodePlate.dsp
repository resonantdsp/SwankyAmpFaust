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

tetrode_plate = environment {
    // See `triode_plate.dsp` for more info on common functionality

    scale = nentry("scale",0,0,1,1);

    drift_level = nentry("drift_level",0,0,1,1);
    drift_tau = nentry("drift_tau",0,0,1,1);
    drift_depth = nentry("drift_depth",0,0,1,1);

    drift2_level = nentry("drift2_level",0,0,1,1);
    drift2_depth = nentry("drift2_depth",0,0,1,1);

    clip = nentry("clip",0,0,1,1);
    clip_corner = nentry("clip_corner",0,0,1,1);
    
    comp_tau = nentry("comp_tau",0,0,1,1);
    comp_depth = nentry("comp_depth",0,0,1,1);

    cross_corner = nentry("cross_corner",0,0,1,1);

    hp_freq = nentry("hp_freq",0,0,1,1);
    lp_freq = nentry("lp_freq",0,0,1,1);

    sag_toggle = nentry("sag_toggle",0,0,1,1);
    sag_depth = nentry("sag_depth",0,0,1,1);
    sag_tau = nentry("sag_tau",0,0,1,1);
    sag_ratio = nentry("sag_ratio",0,0,1,1);
    sag_factor = nentry("sag_factor",0,0,1,1);
    sag_onset = nentry("sag_onset",0,0,1,1);

    sag_tau1 = sag_tau : 1.0 / (ba.sec2samp(_) + 1.0);
    sag_tau2 = sag_tau * sag_ratio : 1.0 / (ba.sec2samp(_) + 1.0);

    nyquist = 1.0 / (2.0 * ba.samp2sec(1));
    hp_freq_clip = hp_freq : min(nyquist * 0.9);
    lp_freq_clip = lp_freq : min(nyquist * 0.9);

    // calculation of the power draw sag induced overhead reduction
    calc_comp_clip = _
        : /(clip)
        : abs
        : min(1.0)
        : si.smooth(ba.tau2pole(comp_tau))
        : clip * 1.0 / (1.0 + _ * comp_depth)
        : _;

    // This is the common process for both sides of the signal
    side = _ 
        // NOTE: power clip is correct here, but the results aren't impacted 
        // strongly but it, so omitted for simplicity

        // Bias drifting causing cross over distortion
        <: _, max(drift_level) - drift_level
        : _, si.smooth(ba.tau2pole(drift_tau)) * drift_depth
        : -

        // Clipping at the top of the waveform with a variable level
        <: calc_comp_clip, _
        : soft_clip_up(clip_corner)

        // Soften the cross over distortion edge
        : soft_clip_down(cross_corner, 0)

        : _;
    
    calc_sag_comp = _
        : /(clip)
        : abs
        // signal below and above clip contriubute differently
        <: min(1.0), max(1.0)
        : sag_onset * _ + _
        // further scale by a user parameter, which should follow the overall
        // drive factor. Use 1 + x formulation to avoid the pole since the
        // parameter isn't transformed into positive space.
        : _ / (1.0 + max(0.0, sag_factor))
        : calc_charge(sag_tau1, sag_tau2)
        : 1.0 / (1.0 +  _ * sag_depth * sag_toggle)
        : _;
    
    // Combine both sides in push-pull fashion
    full = _
        : *(scale)
        <: _, _

        : _, (_ <: *(-1), _)
        : _, side, side
        : _, *(-1), _
        : _, +

        : calc_sag_comp, _
        : *
        : *(1.0 + sag_depth * sag_toggle)

        : fi.bandpass(1, hp_freq_clip, lp_freq_clip)

        // TODO: this is really only needed for fitting
        <: _, abs
        : _, max(drift2_level) - drift2_level
        : _, si.smooth(ba.tau2pole(drift_tau)) * drift2_depth * -1
        : -

        : _;
};

process = tetrode_plate.full;