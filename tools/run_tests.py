#!/usr/bin/env python3
"""Run mocks using a supplied existing Lua 5.1/LuaJIT shared library. Installs nothing."""
import ctypes
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
library = os.environ.get("DG_LUA_LIBRARY")
if not library:
    sys.exit("Set DG_LUA_LIBRARY to an existing Lua 5.1/LuaJIT shared library.")
os.environ["DG_ROOT"] = str(root)
lua = ctypes.CDLL(library)
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_settop.argtypes = [ctypes.c_void_p, ctypes.c_int]
lua.lua_close.argtypes = [ctypes.c_void_p]
state = lua.luaL_newstate()
if not state:
    sys.exit("Unable to create Lua state")
try:
    lua.luaL_openlibs(state)
    files = sorted(root.rglob("*.lua")) + sorted(root.rglob("*.mod"))
    for path in files:
        if lua.luaL_loadfile(state, os.fsencode(path)):
            raise RuntimeError(lua.lua_tolstring(state, -1, None).decode())
        lua.lua_settop(state, 0)
    print(f"Syntax PASS: {len(files)} Lua/manifest files", flush=True)
    status = lua.luaL_loadfile(state, os.fsencode(root / "tests/test_mod.lua"))
    if status == 0:
        status = lua.lua_pcall(state, 0, 0, 0)
    if status:
        raise RuntimeError(lua.lua_tolstring(state, -1, None).decode())
finally:
    lua.lua_close(state)
