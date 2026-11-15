#!/usr/bin/env python3
"""Run a Lua file from the project root with the Roblox-style harness (no Studio needed).
Usage: python3 tools/lua.py tests/run.lua [args]      Needs: pip install lupa
The game code sticks to the Lua 5.1 subset of Luau, so the same files run here and in Studio."""
import os, sys
from lupa.lua51 import LuaRuntime
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(root)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().ROOT = root
lua.globals().ARGS = lua.table_from(sys.argv[2:])
lua.globals().LISTDIR = lambda d: lua.table_from(sorted(os.path.join(d, n) for n in os.listdir(d)))
lua.execute(open("tools/harness.lua").read())
try:
    lua.globals().runfile(sys.argv[1])
except Exception as e:
    print("FAILED:", e); sys.exit(1)
