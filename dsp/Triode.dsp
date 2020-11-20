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

grid = library("TriodeGrid.dsp");
plate = library("TriodePlate.dsp");

mix = nentry("mix",0,0,1,1);
overhead = nentry("overhead",0,0,1,1);
// measured in calibrate.py, used to unscale each triode so they can be stacked
// without growing the RMS, then re-applied before tetrode
unscale = nentry("unscale",0,0,1,1);

process = _
	<: _, _
	: _ / overhead, _
	: grid.process, _
	: (plate.process : *(-1)), _
	: _ * overhead / unscale, _
	: mix * _ + (1.0 - mix) * _
	: _;