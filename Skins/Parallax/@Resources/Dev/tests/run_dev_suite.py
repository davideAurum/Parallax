"""Run DevSuite.lua against the production Dev scripts without Rainmeter.

There is no standalone Lua on the maintainer's PC, so this loads OBS Studio's LuaJIT 2.1
(Lua 5.1 ABI) lua51.dll through ctypes, as the other offline Parallax suites do. Pass --lua
to use another lua51.dll. The suite works in a private temporary directory.
Exit code 0 and "PASS <n>" on success.
"""
from __future__ import annotations

import argparse
import ctypes
import os
import shutil
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
RESOURCES = HERE.parents[0].parent  # ...\@Resources
DEFAULT_LUA = Path(r"C:\Program Files\obs-studio\bin\64bit\lua51.dll")
LUA_GLOBALSINDEX = -10002


def run_suite(lua_dll: Path, work: Path) -> str:
    os.add_dll_directory(str(lua_dll.parent))
    lua = ctypes.CDLL(str(lua_dll))
    lua.luaL_newstate.restype = ctypes.c_void_p
    lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
    lua.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    lua.lua_getfield.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_char_p]
    lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
    lua.lua_tolstring.restype = ctypes.c_char_p
    state = lua.luaL_newstate()
    lua.luaL_openlibs(state)
    suite = HERE / "DevSuite.lua"
    for path in (suite, RESOURCES, work):
        if "]==]" in str(path):
            raise SystemExit(f"Unsupported path: {path}")
    script = (
        f"local suite = dofile([==[{suite}]==])\n"
        f"local ok, result = pcall(suite.run, [==[{RESOURCES}]==], [==[{work}]==])\n"
        "RESULT = (ok and 'PASS ' or 'FAIL ') .. tostring(result)\n"
    )
    if lua.luaL_loadstring(state, script.encode("utf-8")) or lua.lua_pcall(state, 0, 0, 0):
        return "FAIL " + (lua.lua_tolstring(state, -1, None) or b"").decode("utf-8", "replace")
    lua.lua_getfield(state, LUA_GLOBALSINDEX, b"RESULT")
    return (lua.lua_tolstring(state, -1, None) or b"FAIL no result").decode("utf-8", "replace")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua", type=Path, default=DEFAULT_LUA)
    parser.add_argument("--keep", action="store_true", help="keep the private work directory")
    args = parser.parse_args()
    if not args.lua.is_file():
        print(f"lua51.dll not found at {args.lua}; pass --lua.", file=sys.stderr)
        return 2
    work = Path(tempfile.mkdtemp(prefix="parallax-dev-suite-"))
    try:
        result = run_suite(args.lua, work)
    finally:
        if not args.keep:
            shutil.rmtree(work, ignore_errors=True)
    print(result)
    return 0 if result.startswith("PASS ") else 1


if __name__ == "__main__":
    sys.exit(main())
