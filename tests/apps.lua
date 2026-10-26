-- 无需启动 Hammerspoon：luajit tests/apps.lua
local test = require("tests.helpers.keymapping")()
local launches = 0
hs.application.launchOrFocus = function(path)
    assert(path == "/System/Applications/Apps.app")
    launches = launches + 1
end
test.bind("alt", hs.application.launchOrFocus, {
    args = { "/System/Applications/Apps.app" },
    bundleID_excluded = { "com.microsoft.rdc.macos" },
})
assert(launches == 0, "注册时不得执行动作")

local function send(kind, code, flags)
    assert(not test.send(kind, code or 58, flags), "所有事件必须放行")
end
local function press(flags) send("flagsChanged", 58, flags or { alt = true }) end
local function release(flags) send("flagsChanged", 58, flags) end

press()
release()
assert(launches == 1)

-- Windows App 排除；切换至 Windows App 时也不得触发。
test.front = "com.microsoft.rdc.macos"
press()
release()
assert(launches == 1)
test.front = "com.apple.finder"
press()
test.front = "com.microsoft.rdc.macos"
release()
assert(launches == 1)
test.front = "com.apple.finder"

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
test.advance(1.1)
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
test.front = nil
press()
release()
assert(launches == 5)
-- 其他键先按住，再按 Option；无论谁先松开，都不是单按。
send("keyDown", 14)
press()
release()
send("keyUp", 14)
send("keyDown", 14)
press()
send("keyUp", 14)
release()
assert(launches == 5)
press()
release()
assert(launches == 6)
assert(#test.errors == 0)
print("apps: 全部测试通过")
