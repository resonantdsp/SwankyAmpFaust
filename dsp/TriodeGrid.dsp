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

triode_grid = environment {
    // High pass frequency for the signal coming into the tridoe, this is the 
    // result of the capacitor after the input signal and also means we don't
    // have to worry about signal biases. This has an audible impact on the
    // signal and can be used to shape it into the desired tone.
    hp_freq = nentry("hp_freq",0,0,1,1);
    
    // Observed a soft compression on the upper portion of the signal before 
    // grid conduction regime. This is well modelled by `cap_comp`. Suspect
    // this is the result of some capacitance between grid and plate?
    tau = nentry("tau",0,0,1,1);
    ratio = nentry("ratio",0,0,1,1);
    smooth = nentry("smooth",0,0,1,1);
    level = nentry("level",0,0,1,1);

    cap = nentry("cap",0,0,1,1);

    clip = nentry("grid_clip",0,0,1,1);
    corner = nentry("grid_corner",0,0,1,1);
    
    // Convert to `cap_comp` parameters
    tau1 = tau : 1.0 / (ba.sec2samp(_) + 1);
    tau2 = tau * ratio : 1.0 / (ba.sec2samp(_) + 1);
    tau3 = tau * smooth : 1.0 / (ba.sec2samp(_) + 1);

    full = _ 
        : fi.highpass(1, hp_freq) 

        <: _, max(0, _ - level)
        : _, calc_charge_cap(tau1, tau2, cap)
        : _, si.smooth(1 - tau3)
        : -
        
        : soft_clip_up(corner, clip)
        : _;
};

process = triode_grid.full;
