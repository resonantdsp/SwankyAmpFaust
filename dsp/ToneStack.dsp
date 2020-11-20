//  Classic Marshall Approximation
//  Classic Fender Approximation
//  AC30 Bass + Treble Approximation
//  Copyright (C) 2020  Dave Clark
// 
//  Modified by Garrin McGoldrick and adapted for Swanky Amp.
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

bass = nentry("bass",0,0,1,1);
treble = nentry("treble",0,0,1,1);
mids = nentry("mids",0,0,1,1);
presence = nentry("presence",0,0,1,1);
selection = nentry("selection",0,0,1,1);

presence_db = 10.0 * presence;
mids_db = 10.0 * mids;

c = ma.SR;

ClassicFenderML = ClassicFenderML
with
{
  // Classic Fender Mids and Bass:
  l = 0.495*bass + 0.505;
  l2 = l*l;
  t = 0.495*treble + 0.505;
  m = 0.495*mids + 0.505;

  C1 = 100.0e-9;
  C2 =  47.0e-9;

  R1 = 100.0e3;
  R2 = 250.0e3;
  R3 =  10.0e3;

  Ri =  38.0e3;

  // Transfer Function:

  // Numerator:

  b3 = 0.0;
  b2 = l2*m*C1*C2*R2*R3;
  b1 = (m*C2+m*C1)*R3+l2*C1*R2;
  b0 = 0.0;

  // Denominator:

  a3 = 0.0;
  a2 = l2*m*C1*C2*R2*R3+(l2*C1*C2*R1+l2*Ri*C1*C2)*R2;
  a1 = (m*C2+m*C1)*R3+l2*C1*R2+(C2+C1)*R1+Ri*C2+Ri*C1;
  a0 = 1.0;

  // Z:

  A00 = 1.0/(a0 + a1*c + a2*c*c);

  A0 = 1.0;
  A1 = A00*(2.0*a0 - 2.0*a2*c*c);
  A2 = A00*(a0 - a1*c + a2*c*c);

  B0 = A00*(b0 + b1*c + b2*c*c);
  B1 = A00*(2.0*b0 - 2.0*b2*c*c);
  B2 = A00*(b0 - b1*c + b2*c*c);

  ClassicFenderML = 4.0 * fi.iir((B0,B1,B2),(A1,A2));
};

ClassicFenderT = ClassicFenderT
with
{
  // Classic_Fender_Treble:

  l = 0.495*bass + 0.505;
  l2 = l*l;
  t = 0.495*treble + 0.505;
  m = 0.495*mids + 0.505;

  C1 = 250.0e-12;

  R1 = 100.0e3;
  R2 = 250.0e3;

  Ri = 38.0e3;

  // Transfer Function:

  // Numerator:

  b3 = 0.0;
  b2 = 0.0;
  b1 = t*C1*R1*R1;
  b0 = 0.0;

  // Denominator:

  a3 = 0.0;
  a2 = 0.0;
  a1 = ((R1+Ri)*R2+Ri*R1)*C1;
  a0 = R1+Ri;

  // Z:

  A00 = 1.0/(a0 + a1*c + a2*c*c);

  A0 = 1.0;
  A1 = A00*(2.0*a0 - 2.0*a2*c*c);
  A2 = A00*(a0 - a1*c + a2*c*c);

  B0 = A00*(b0 + b1*c + b2*c*c);
  B1 = A00*(2.0*b0 - 2.0*b2*c*c);
  B2 = A00*(b0 - b1*c + b2*c*c);

  ClassicFenderT = 12.0 * fi.iir((B0,B1,B2),(A1,A2));
};

ClassicMarshallML = ClassicMarshallML
with {
  // Classic Marshall Mids and Bass:

  bass0 = 0.495*bass + 0.505;
  // l = l<=0.5 ? 0.2*l : 1.6*l - 0.7;
  lesser = (bass0 <= 0.5);
  greater = (bass0 > 0.5);
  l = lesser*0.2*bass0 + greater*(1.6*bass0 - 0.7);
  t = 0.495*treble + 0.505;
  m = 0.495*mids + 0.505;

  C1 = 22.0e-9;
  C2 = 22.0e-9;

  R1 = 33.0e3;
  R2 = 1.0e6;
  R3 = 22.0e3;

  Ri = 0.0;

  // Transfer Function:

  // Numerator:

  b3 = 0.0;
  b2 = ((m*m-m)*R3*R3-l*m*R2*R3)*C1*C2;
  b1 = (-m*C2-C1)*R3-l*C1*R2;
  b0 = 0.0;

  // Denominator:

  a3 = 0.0;
  a2 = ((m*m-m)*R3*R3+(-l*m*R2+(m-1)*R1+(m-1)*Ri)*R3+(-l*R1-l*Ri)*R2)*C1*C2;
  a1 = (-m*C2-C1)*R3-l*C1*R2+(-C2-C1)*R1-Ri*C2-Ri*C1;
  a0 = -1.0;

  // Z:
                
  A00 = 1.0/(a0 + a1*c + a2*c*c);

  A0 = 1.0;
  A1 = A00*(2.0*a0 - 2.0*a2*c*c);
  A2 = A00*(a0 - a1*c + a2*c*c);

  B0 = A00*(b0 + b1*c + b2*c*c);
  B1 = A00*(2.0*b0 - 2.0*b2*c*c);
  B2 = A00*(b0 - b1*c + b2*c*c);

  ClassicMarshallML = 1.4 * fi.iir((B0,B1,B2),(A1,A2));
};

ClassicMarshallT = ClassicMarshallT
with {
  // Classic_Marshall_Treble:

  bass0 = 0.495*bass + 0.505;
  // l = l<=0.5 ? 0.2*l : 1.6*l - 0.7;
  lesser = (bass0 <= 0.5);
  greater = (bass0 > 0.5);
  l = lesser*0.2*bass0 + greater*(1.6*bass0 - 0.7);
  t = 0.495*treble + 0.505;
  m = 0.495*mids + 0.505;
  
  C1 = 470e-12;
  
  R1 = 33000;
  R2 = 220000;
  
  Ri = 0.0;
  
  // Transfer Function:
  
  // Numerator:
  
  b3 = 0.0;
  b2 = 0.0;
  b1 = t*C1*R1*R1;
  b0 = 0.0;
  
  // Denominator:
  
  a3 = 0.0;
  a2 = 0.0;
  a1 = ((R1+Ri)*R2+Ri*R1)*C1;
  a0 = R1+Ri;
  
  // Z:
  
  A00 = 1.0/(a0 + a1*c + a2*c*c);
  
  A0 = 1.0;
  A1 = A00*(2.0*a0 - 2.0*a2*c*c);
  A2 = A00*(a0 - a1*c + a2*c*c);
  
  B0 = A00*(b0 + b1*c + b2*c*c);
  B1 = A00*(2.0*b0 - 2.0*b2*c*c);
  B2 = A00*(b0 - b1*c + b2*c*c);
  
  ClassicMarshallT = 6.0 * fi.iir((B0,B1,B2),(A1,A2));
};


ClassicAC30L = ClassicAC30L
with {
  bass0 = 0.495*bass + 0.505;
  lesser = (bass0 <= 0.5);
  greater = (bass0 > 0.5);
  l = lesser*0.2*bass0 + greater*(1.6*bass0 - 0.7);
  t = 0.495*treble + 0.505;

  // Classic AC30 Bass
  // WARNING: BASS HAS TREBLE DEPENDENCE! (See TF below)

  C1 =  22.0e-9;
  C2 = 100.0e-9;

  R1 = 100.0e3;
  R2 =  10.0e3;
  R3 = 250.0e3;

  //Reduced:

  R4 = 250.0e3;
  R5 = 150000.0;  // Load

  Ri = 56.0e3;

  // Transfer Function:

  // Numerator:

  b3 = 0.0;
  b2 = (l*l - l)*C1*C2*R2*R4*R4*R5;
  b1 = ((l*l - l)*C2*R4*R4 + ((l - 1)*C1 - C2)*R2*R4)*R5;
  b0 = 0.0;

  // Denominator:
                 
  a3 = 0.0;                     
  a2 = ((R2 + R1 + Ri)*(l*l - l)*C1*C2*R4*R4 - (R1 + Ri)*l*C1*C2*R2*R4)*R5 + ((R2 + R1 + Ri)*(l*l - l)*t*C1*C2*R3 + (R1 + Ri)*(l*l - l)*C1*C2*R2)*R4*R4 - (R1 + Ri)*l*t*C1*C2*R2*R3*R4;

  a1 = ((l*l - l)*C2*R4*R4 + (C1*R2 + (C2 + C1)*R1 + Ri*C2 + Ri*C1)*(l - 1)*R4 - R2*C2*R4 + ((-C2 - C1)*R1 - Ri*C2 - Ri*C1)*R2)*R5 + (t*C2*R3 + C1*R2 + (C2 + C1)*R1 + Ri*C2 + Ri*C1)*(l*l - l)*R4*R4 + ((((l - 1)*t*C1 - t*C2)*R2 + ((l - 1)*t*C2 + (l - 1)*t*C1)*R1 + (l - 1)*Ri*t*C2 + (l - 1)*Ri*t*C1)*R3 + ((-C2 - C1)*R1 - Ri*C2 - Ri*C1)*R2)*R4 + ((-t*C2 - t*C1)*R1 - Ri*t*C2 - Ri*t*C1)*R2*R3;

  a0 = ((l - 1)*R4 - R2)*R5 + (l*l - l)*R4*R4 + ((l - 1)*t*R3 - R2)*R4 - t*R2*R3;

  // Z:
    
  A00 = 1.0/(a0 + a1*c + a2*c*c);

  A0 = 1.0;
  A1 = A00*(2.0*a0 - 2.0*a2*c*c);
  A2 = A00*(a0 - a1*c + a2*c*c);

  B0 = A00*(b0 + b1*c + b2*c*c);
  B1 = A00*(2.0*b0 - 2.0*b2*c*c);
  B2 = A00*(b0 - b1*c + b2*c*c);

  ClassicAC30L = 8.0 * fi.iir((B0,B1,B2),(A1,A2));
};

ClassicAC30T = ClassicAC30T
with {
  bass0 = 0.495*bass + 0.505;
  lesser = (bass0 <= 0.5);
  greater = (bass0 > 0.5);
  l = lesser*0.2*bass0 + greater*(1.6*bass0 - 0.7);
  t = 0.495*treble + 0.505;
 
  // Classic_AC30_Treble:

  C1 = 560.0e-12;

  R1 = 100.0e3;
  R2 =  10.0e3;
  R3 = 250.0e3;

  Ri = 48.0e3;
   
  // Transfer Function:
   
  // Numerator:

  b3 = 0.0;
  b2 = 0.0;
  b1 = ((R2+t*R1)*R3+R1*R2)*C1;
  b0 = R2;

  // Denominator:

  a3 = 0.0;
  a2 = 0.0;
  a1 = ((R2+R1+Ri)*R3+R1*(R2+Ri))*C1;
  a0 = R2+R1+Ri;

  // Z:

  A00 = 1.0/(a0 + a1*c + a2*c*c);

  A0 = 1.0;
  A1 = A00*(2.0*a0 - 2.0*a2*c*c);
  A2 = A00*(a0 - a1*c + a2*c*c);

  B0 = A00*(b0 + b1*c + b2*c*c);
  B1 = A00*(2.0*b0 - 2.0*b2*c*c);
  B2 = A00*(b0 - b1*c + b2*c*c);
    
  ClassicAC30T = 1.5 * fi.iir((B0,B1,B2),(A1,A2));
};

ClassicFender = _ <: ClassicFenderT + ClassicFenderML;
ClassicMarshall = _ <: ClassicMarshallT + ClassicMarshallML;
ClassicAC30 = _ <: ClassicAC30T + ClassicAC30L : fi.peak_eq(mids_db, 1e3, 2e3);

// at 0, full weight, over 1.0, no weight
weight_fender = 1.0 - min(max(selection, 0.0), 1.0);
// at 2, full weight, below 1.0, no weight
weight_ac30 = min(max(selection, 1.0), 2.0) - 1.0;
// at 1.0 full weight, away by 1.0, no weight
weight_marshall = 1.0 - min(max(abs(selection - 1.0), 0.0), 1.0);

process = _
  <: ClassicFender, ClassicMarshall, ClassicAC30
  : weight_fender * _ + weight_marshall * _ + weight_ac30 * _
  : fi.peak_eq(presence_db, 4e3, 2e3)
  : _;
