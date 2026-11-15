#!/usr/bin/env python3
"""Syntax check: every Lua file must parse as Lua 5.1 (the code keeps to the Lua 5.1 subset of Luau).
Run from the project root:  python3 tools/check_lua.py"""
import glob, os, sys
from lupa.lua51 import LuaRuntime
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
lua = LuaRuntime()
check = lua.eval('function(s, n) local f, e = loadstring(s, n) if f then return "ok" else return e end end')
files = sorted(glob.glob("src/**/*.lua", recursive=True) + glob.glob("tools/*.lua") + glob.glob("tests/*.lua"))
bad = 0
for f in files:
    r = check(open(f).read(), "@" + f)
    if r != "ok":
        bad += 1
        print(r)
print(f"check_lua: {len(files)} files, {bad} syntax errors")
sys.exit(1 if bad else 0)
