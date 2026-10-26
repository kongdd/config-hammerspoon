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
local trash = {}
package.loaded.keymapping = function(from, to, bundleID)
    assert(from == "del" and to == "cmd+backspace" and bundleID == "com.apple.finder")
    return trash
end
local bindings = dofile(os.getenv("HOME") .. "/.hammerspoon/finder.lua")
assert(bindings.home and bindings.trash == trash, "两项绑定均须保留引用")
callback()
assert(calls == 1)
print("finder: Option+E 打开主目录测试通过")
