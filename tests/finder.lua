-- luajit ~/.hammerspoon/tests/finder.lua
local callback, calls = nil, 0
hs = {
    hotkey = { bind = function(modifiers, key, fn)
        assert(#modifiers == 1 and modifiers[1] == "alt" and key == "e")
        callback = fn
        return {}
    end },
    execute = function(command)
        assert(command == "/usr/bin/open ~")
        calls = calls + 1
    end,
}
dofile(os.getenv("HOME") .. "/.hammerspoon/finder.lua")
callback()
assert(calls == 1)
print("finder: Option+E 打开主目录测试通过")
