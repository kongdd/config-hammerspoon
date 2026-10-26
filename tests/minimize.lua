-- 无需启动 Hammerspoon：luajit ~/.hammerspoon/tests/minimize.lua
local windows, focused, callback = {}, nil, nil
hs = {
    hotkey = { bind = function(mods, key, fn)
        assert(#mods == 1 and mods[1] == "cmd" and key == "m")
        callback = fn
        return {}
    end },
    window = {
        get = function(id) return windows[id] end,
        focusedWindow = function() return focused end,
    },
}
local function window(id)
    local w = { minimized = false, canMinimize = true }
    function w:id() return id end
    function w:isMinimized() return self.minimized end
    function w:minimize()
        if self.async then
            self.pending = true
        else
            self.minimized = self.canMinimize
        end
        focused = nil
    end
    function w:unminimize() self.minimized = false end
    function w:focus() focused = self end
    windows[id] = w
    return w
end

dofile(os.getenv("HOME") .. "/.hammerspoon/minimize.lua")
local a, b = window(1), window(2)
focused = a
callback()
assert(a.minimized)

-- 焦点已切换，仍恢复原窗口。
focused = b
callback()
assert(not a.minimized and focused == a and not b.minimized)

-- 最小化后没有焦点，仍能恢复。
callback()
assert(a.minimized and focused == nil)
callback()
assert(not a.minimized and focused == a)

-- 手动恢复后，下次按键重新最小化当前窗口。
callback()
a:unminimize()
focused = b
callback()
assert(b.minimized)
callback()
assert(not b.minimized and focused == b)

-- 已关闭的窗口不应妨碍操作其他窗口。
focused = a
callback()
windows[1] = nil
focused = b
callback()
assert(b.minimized)
callback()
assert(not b.minimized and focused == b)

-- 无窗口或无法最小化时安全返回，不记录错误目标。
focused = nil
callback()
b.canMinimize = false
focused = b
callback()
assert(not b.minimized)
focused = window(3)
callback()
assert(focused == nil and windows[3].minimized)
callback()
assert(focused == windows[3] and not focused.minimized)
-- 最小化异步完成：调用后尚未更新状态，也必须记住窗口。
local c = window(4)
c.async = true
focused = c
callback()
assert(c.pending and not c.minimized)
c.minimized = true
focused = b
callback()
assert(not c.minimized and focused == c)
print("minimize: 全部测试通过")
