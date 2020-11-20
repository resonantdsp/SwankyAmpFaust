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

cab = cab
with {
    offset = nentry("offset",0,0,1,1);
    hp_f = nentry("hp_f",0,0,1,1);
    lp_f = nentry("lp_f",0,0,1,1);
    shelf_f = nentry("shelf_f",0,0,1,1);
    shelf_l = nentry("shelf_l",0,0,1,1);
    scoop_f = nentry("scoop_f",0,0,1,1);
    scoop_l = nentry("scoop_l",0,0,1,1);
    scoop_b = nentry("scoop_b",0,0,1,1);
    peak_1_f = nentry("peak_1_f",0,0,1,1);
    peak_1_l = nentry("peak_1_l",0,0,1,1);
    peak_1_b = nentry("peak_1_b",0,0,1,1);
    peak_2_f = nentry("peak_2_f",0,0,1,1);
    peak_2_l = nentry("peak_2_l",0,0,1,1);
    peak_2_b = nentry("peak_2_b",0,0,1,1);
    peak_3_f = nentry("peak_3_f",0,0,1,1);
    peak_3_l = nentry("peak_3_l",0,0,1,1);
    peak_3_b = nentry("peak_3_b",0,0,1,1);
    peak_4_f = nentry("peak_4_f",0,0,1,1);
    peak_4_l = nentry("peak_4_l",0,0,1,1);
    peak_4_b = nentry("peak_4_b",0,0,1,1);
    peak_5_f = nentry("peak_5_f",0,0,1,1);
    peak_5_l = nentry("peak_5_l",0,0,1,1);
    peak_5_b = nentry("peak_5_b",0,0,1,1);
    peak_6_f = nentry("peak_6_f",0,0,1,1);
    peak_6_l = nentry("peak_6_l",0,0,1,1);
    peak_6_b = nentry("peak_6_b",0,0,1,1);
    peak_7_f = nentry("peak_7_f",0,0,1,1);
    peak_7_l = nentry("peak_7_l",0,0,1,1);
    peak_7_b = nentry("peak_7_b",0,0,1,1);
    peak_8_f = nentry("peak_8_f",0,0,1,1);
    peak_8_l = nentry("peak_8_l",0,0,1,1);
    peak_8_b = nentry("peak_8_b",0,0,1,1);
    peak_9_f = nentry("peak_9_f",0,0,1,1);
    peak_9_l = nentry("peak_9_l",0,0,1,1);
    peak_9_b = nentry("peak_9_b",0,0,1,1);
    peak_10_f = nentry("peak_10_f",0,0,1,1);
    peak_10_l = nentry("peak_10_l",0,0,1,1);
    peak_10_b = nentry("peak_10_b",0,0,1,1);

    brightness = nentry("brightness",0,0,1,1);
    distance = nentry("distance",0,0,1,1);
    dynamic = nentry("dynamic",0,0,1,1);
    dynamic_level = nentry("dynamic_level",0,0,1,1);

    // measured by running a single coil signal with low drive through the amp,
    // and then a humbucker signal with high drive
    gain_low = 0.05 * dynamic_level;
    gain_high = max(gain_low * 2.0, 0.5 * dynamic_level);

    cab_eq(gain) = _
        : fi.highpass(4, hp_f)
        : fi.lowpass(3, lp_f)
        : fi.highshelf(7, shelf_l, shelf_f)

        : fi.peak_eq(peak_1_l, peak_1_f, peak_1_b)
        : fi.peak_eq(peak_2_l, peak_2_f, peak_2_b)

        : fi.peak_eq(peak_3_l, peak_3_f, peak_3_b)
        : fi.peak_eq(peak_4_l, peak_4_f, peak_4_b)

        : fi.peak_eq(peak_5_l, peak_5_f, peak_5_b)

        : fi.peak_eq(peak_6_l, peak_6_f, peak_6_b)
        : fi.peak_eq(peak_7_l, peak_7_f, peak_7_b)

        : fi.peak_eq(peak_8_l + 5 * dynamic * gain, peak_8_f - 500 * dynamic * gain, peak_8_b + 200 * dynamic * gain)

        : fi.peak_eq(peak_9_l, peak_9_f, peak_9_b)
        : fi.peak_eq(peak_10_l, peak_10_f, peak_10_b)

        : fi.peak_eq(scoop_l, scoop_f, scoop_b)

        : fi.peak_eq(-5, 100, 200)

        : fi.low_shelf(-3 * brightness + 3 * dynamic * gain, 1100)
        : fi.peak_eq(15 * brightness, 6000, 1000)

        : fi.high_shelf(-5 * dynamic * gain, 6500)

        : fi.peak_eq(-10 * distance, 70, 100)
        : fi.peak_eq(-17 * distance, 1200, 300)
        : *(ba.db2linear(2 * distance))

        : *(ba.db2linear(offset))

        : _ ;
    
    cab_gain = _
        : abs
        : si.smooth(ba.tau2pole(0.1))
        : (_ - gain_low) / (gain_high - gain_low)
        : (_ - 0.5) * 2.0
        : ftanh(_)
        : (_ + 1.0) / 2.0
        :  _;

    cab = _
        <: (
            cab_gain,
            _
        )
        : cab_eq
        : _ ;
};

process = _ <: cab;