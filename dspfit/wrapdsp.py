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
Functionality to compile faust code and expose it to python.
"""

import ctypes
import json
import os
import re
import subprocess
import warnings
from contextlib import contextmanager
from pathlib import Path
from typing import Iterable, Mapping, Tuple

import numpy as np

_WRAP_CODE = """
{header}

extern "C" {{

void compute(int samplingFreq, int count, FAUSTFLOAT** buffer{arguments}) {{
  {name} dsp = {name}();
  dsp.prepare(samplingFreq);
  {set_parameters}
  dsp.process(count, buffer);
}}

}}
"""


def wrap_compute(code: str, class_name: str, parameters: Iterable[str]):
    """Generate code which initializes a DSP instance and calls its compute."""

    arguments = ", ".join([f"FAUSTFLOAT {n}" for n in parameters])
    arguments = ", " + arguments if arguments else ""

    set_parameters = "\n  ".join([f"dsp.set_{n}({n});" for n in parameters])

    code = _WRAP_CODE.format(
        header=code,
        name=class_name,
        arguments=arguments,
        set_parameters=set_parameters,
    )

    return code


@contextmanager
def scoped_file(path: Path):
    yield
    try:
        path.unlink()
    except FileNotFoundError:
        pass


def compile_wrapped(class_name: str, path_build: Path, path_headers: Path, code: str):
    """Copile warpped faust code into a dll"""
    path_build.mkdir(parents=True, exist_ok=True)

    path_cpp = path_build / f"{class_name}.cpp"
    with path_cpp.open("w") as fio:
        fio.write(code)

    subprocess.check_call(
        (
            f"cd {path_build} && "
            "g++ -std=c++17 -shared -fpic -O3 "
            f"-I {str(path_headers.absolute())} "
            f"-o {class_name}.so "
            f"{class_name}.cpp"
        ),
        shell=True,
    )


def make_callable(class_name: str, path: Path, parameters: Iterable[str]):
    """Create a function which will call the fasut dsp from a library."""
    cdll = ctypes.cdll.LoadLibrary(str(path / f"{class_name}.so"))
    c_compute = cdll.compute

    def py_callable(fs: int, buffer: np.ndarray, **kwargs):
        buffer = np.copy(buffer, order="C").astype("float32")
        if len(buffer.shape) == 1:
            buffer = np.ascontiguousarray(buffer[None, :])
        assert len(buffer.shape) == 2

        c_samplingFreq = ctypes.c_int(fs)
        c_count = ctypes.c_int(buffer.shape[1])

        c_buffer = (ctypes.POINTER(ctypes.c_float) * 2)()
        for i in range(buffer.shape[0]):
            c_buffer[i] = buffer[i].ctypes.data_as(ctypes.POINTER(ctypes.c_float))

        args = [ctypes.c_float(kwargs[n]) for n in parameters]

        c_compute(
            c_samplingFreq,
            c_count,
            ctypes.byref(c_buffer),
            *args,
        )

        return buffer

    return py_callable


def build_fausthpp(
    path_build: Path, path_headers: Path, path_dsp: Path, class_name: str
):
    compiled_pars = subprocess.check_output(
        [
            "faust2hpp",
            str(path_headers),
            str(path_dsp / f"{class_name}.dsp"),
            class_name,
            "--pars_file",
            str(path_dsp / f"{class_name}.json"),
            "--print_pars",
        ],
        encoding="utf8",
    )

    compiled_pars = [c.strip() for c in compiled_pars.split("\n") if c.strip()]

    with (path_headers / f"{class_name}.h").open("r") as fio:
        code = fio.read()

    wrapped_code = wrap_compute(code, class_name, compiled_pars)
    compile_wrapped(class_name, path_build, path_headers, wrapped_code)

    return make_callable(class_name, path_build, compiled_pars), compiled_pars


def build_fausthpp_monitor(
    path_build: Path,
    path_headers: Path,
    path_dsp: Path,
    class_name: str,
    monitor_member: str,
):
    compiled_pars = subprocess.check_output(
        [
            "faust2hpp",
            str(path_headers),
            str(path_dsp / f"{class_name}.dsp"),
            class_name,
            "--pars_file",
            str(path_dsp / f"{class_name}.json"),
            "--print_pars",
        ],
        encoding="utf8",
    )
    compiled_pars = [c.strip() for c in compiled_pars.split("\n") if c.strip()]

    with (path_headers / f"{class_name}Faust.h").open("r") as fio:
        code = fio.read()

    if code.find(monitor_member) < 0:
        raise RuntimeError(f"{monitor_member} not found in source")

    idx_insert = code.find("\tvirtual void compute(")
    idx_insert = code.find("\t\t}\n\t}\n", idx_insert)
    if idx_insert < 0:
        raise RuntimeError("can't find inspection insertion point")

    code = "".join(
        (
            code[:idx_insert],
            f"\t\t\toutputs[0][i] = {monitor_member}[0];\n",
            code[idx_insert:],
        )
    )

    with (path_headers / f"{class_name}Faust.h").open("w") as fio:
        fio.write(code)

    with (path_headers / f"{class_name}.h").open("r") as fio:
        code = fio.read()

    wrapped_code = wrap_compute(code, class_name, compiled_pars)
    compile_wrapped(class_name, path_build, path_headers, wrapped_code)

    return make_callable(class_name, path_build, compiled_pars), compiled_pars
