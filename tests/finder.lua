-- 无需启动 Hammerspoon：luajit ~/.hammerspoon/tests/finder.lua
local callback, front, launches, trashes = nil, "com.apple.Safari", 0, 0
local types = { keyDown = 1, keyUp = 2 }
hs = {
    keycodes = { map = { e = 14, forwarddelete = 117 } },
    application = {
        frontmostApplication = function()
            if front then return { bundleID = function() return front end } end
        end,
        launchOrFocus = function(name)
            assert(name == "Finder")
            launches = launches + 1
        end,
    },
    eventtap = {
        event = {
            types = types,
            newKeyEvent = function(modifiers, key, down)
                assert(#modifiers == 1 and modifiers[1] == "cmd" and key == "delete")
                return { down = down }
            end,
        },
        new = function(events, fn)
            assert(#events == 2 and events[1] == types.keyDown and events[2] == types.keyUp)
            callback = fn
            return { start = function(self) return self end }
        end,
    },
}
dofile(os.getenv("HOME") .. "/.hammerspoon/finder.lua")
local function send(kind, flags, expected, code)
    local consumed, events = callback({
        getType = function() return types[kind] end,
        getKeyCode = function() return code or 14 end,
        getFlags = function() return flags or {} end,
    })
    assert(consumed == expected)
    if events then
        assert(consumed and #events == 2 and events[1].down and not events[2].down)
        trashes = trashes + 1
    end
end

-- 普通应用中成对拦截，松键后仅打开一次。
send("keyDown", { cmd = true }, true)
assert(launches == 0)
send("keyDown", { cmd = true }, true)
send("keyUp", { cmd = true }, true)
assert(launches == 1)
send("keyUp", {}, false)
assert(launches == 1)

-- 编辑器中原样放行，包括长按重复。
for _, id in ipairs({ "com.microsoft.VSCode", "dev.zed.Zed" }) do
    front = id
    send("keyDown", { cmd = true }, false)
    send("keyDown", { cmd = true }, false)
    send("keyUp", { cmd = true }, false)
end
assert(launches == 1)

-- 额外修饰键不匹配；Caps Lock 不影响快捷键。
front = "com.apple.Safari"
for _, modifier in ipairs({ "alt", "ctrl", "shift", "fn" }) do
    local flags = { cmd = true, [modifier] = true }
    send("keyDown", flags, false)
    send("keyUp", flags, false)
end
send("keyDown", {}, false)
send("keyUp", {}, false)
send("keyDown", { cmd = true }, false, 15)
send("keyUp", { cmd = true }, false, 15)
assert(launches == 1)
send("keyDown", { cmd = true, capslock = true }, true)
send("keyUp", { cmd = true, capslock = true }, true)
assert(launches == 2)

-- 中途切换应用或先松开 Command，仍配对消费 E 的松键事件。
send("keyDown", { cmd = true }, true)
front = "com.microsoft.VSCode"
send("keyUp", {}, true)
assert(launches == 3)

-- 无前台应用时仍可使用。
front = nil
send("keyDown", { cmd = true }, true)
send("keyUp", {}, true)
assert(launches == 4)
-- Finder 中 Del 成对拦截，仅首次按下生成 ⌘Backspace，长按不重复。
front = "com.apple.finder"
send("keyDown", {}, true, 117)
assert(trashes == 1)
send("keyDown", {}, true, 117)
send("keyUp", {}, true, 117)
send("keyUp", {}, false, 117)
assert(trashes == 1)

-- Fn / Caps Lock 允许；其他修饰键组合不改写。
for _, flags in ipairs({ { fn = true }, { capslock = true }, { fn = true, capslock = true } }) do
    send("keyDown", flags, true, 117)
    send("keyUp", flags, true, 117)
end
assert(trashes == 4)
for _, modifier in ipairs({ "cmd", "alt", "ctrl", "shift" }) do
    local flags = { [modifier] = true }
    send("keyDown", flags, false, 117)
    send("keyUp", flags, false, 117)
end

-- Backspace 不受影响；其他应用和无前台应用时 Del 原样放行。
send("keyDown", {}, false, 51)
send("keyUp", {}, false, 51)
for _, id in ipairs({ "com.apple.Safari", "com.microsoft.VSCode", "dev.zed.Zed" }) do
    front = id
    send("keyDown", {}, false, 117)
    send("keyUp", {}, false, 117)
end
front = nil
send("keyDown", {}, false, 117)
send("keyUp", {}, false, 117)
assert(trashes == 4)

-- 按下后切换应用，仍消费松键，但不再生成删除动作。
front = "com.apple.finder"
send("keyDown", {}, true, 117)
front = "com.apple.Safari"
send("keyUp", {}, true, 117)
assert(trashes == 5 and launches == 4)
print("finder: 全部测试通过（未执行真实文件删除）")
