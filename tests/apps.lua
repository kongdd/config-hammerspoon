-- 无需启动 Hammerspoon：luajit ~/.hammerspoon/tests/apps.lua
local callback, now, launches, front = nil, 0, 0, "com.apple.finder"
local types = {
    flagsChanged = 1, keyDown = 2, keyUp = 3,
    leftMouseDown = 4, rightMouseDown = 5, otherMouseDown = 6, scrollWheel = 7,
}
hs = {
    keycodes = { map = { alt = 58 } },
    timer = { secondsSinceEpoch = function() return now end },
    application = {
        frontmostApplication = function()
            if front then return { bundleID = function() return front end } end
        end,
        launchOrFocus = function(path)
            assert(path == "/System/Applications/Apps.app")
            launches = launches + 1
        end,
    },
    eventtap = {
        event = { types = types },
        new = function(events, fn)
            assert(#events == 7)
            callback = fn
            return { start = function(self) return self end }
        end,
    },
}
dofile(os.getenv("HOME") .. "/.hammerspoon/apps.lua")
local function send(kind, code, flags)
    now = now + 0.05
    assert(callback({
        getType = function() return types[kind] end,
        getKeyCode = function() return code or 58 end,
        getFlags = function() return flags or {} end,
    }) == false, "所有事件必须放行")
end
local function press(flags) send("flagsChanged", 58, flags or { alt = true }) end
local function release(flags) send("flagsChanged", 58, flags) end

press()
release()
assert(launches == 1)

-- Windows App 排除；切换至 Windows App 时也不得触发。
front = "com.microsoft.rdc.macos"
press()
release()
assert(launches == 1)
front = "com.apple.finder"
press()
front = "com.microsoft.rdc.macos"
release()
assert(launches == 1)
front = "com.apple.finder"

-- Option+C 等组合键，以及其他修饰键先后按下，均不触发。
press()
send("keyDown", 8, { alt = true })
send("keyUp", 8, { alt = true })
release()
assert(launches == 1)
for _, modifier in ipairs({ "cmd", "ctrl", "shift", "fn" }) do
    local flags = { alt = true, [modifier] = true }
    press(flags)
    release()
    press()
    send("flagsChanged", 55, flags)
    send("flagsChanged", 55, { alt = true })
    release()
    assert(launches == 1)
end

-- 鼠标点击或滚动取消单按。
for _, kind in ipairs({ "leftMouseDown", "rightMouseDown", "otherMouseDown", "scrollWheel" }) do
    press()
    send(kind, 0, { alt = true })
    release()
    assert(launches == 1)
end

-- 长按、孤立松键、右 Option 均不触发。
press()
now = now + 1.1
release()
release()
send("flagsChanged", 61, { alt = true })
send("flagsChanged", 61)
assert(launches == 1)

-- Caps Lock 不影响单按。
press({ alt = true, capslock = true })
release({ capslock = true })
assert(launches == 2)

-- 兼容远程注入的 keyDown/keyUp，不依赖 keyDown 中的 Option 标志。
send("keyDown", 58)
send("keyUp", 58)
assert(launches == 3)

-- 重复事件不会多次启动；远程组合键仍不触发。
send("keyDown", 58, { alt = true })
press()
release()
send("keyUp", 58)
assert(launches == 4)
send("keyDown", 58, { alt = true })
send("keyDown", 8, { alt = true })
send("keyUp", 8, { alt = true })
send("keyUp", 58)
assert(launches == 4)

-- 无前台应用时仍可使用。
front = nil
press()
release()
assert(launches == 5)
print("apps: 全部测试通过")
