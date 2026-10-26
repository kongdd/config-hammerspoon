-- luajit ~/.hammerspoon/tests/finder_trash.lua；不操作真实文件。
local callback, front, trashes = nil, "com.apple.finder", 0
hs = {
    keycodes = { map = { forwarddelete = 117, delete = 51, e = 14 } },
    application = { frontmostApplication = function()
        if front then return {
            bundleID = function() return front end,
        } end
    end },
    eventtap = {
        keyStroke = function(modifiers, key, delay)
            assert(#modifiers == 1 and modifiers[1] == "cmd")
            assert(key == "delete" and delay == 0)
            trashes = trashes + 1
        end,
        event = { types = { keyDown = 1, keyUp = 2 } },
        new = function(events, fn)
            assert(#events == 2 and events[1] == 1 and events[2] == 2)
            callback = fn
            return { start = function(self) return self end }
        end,
    },
}
local keymapping = require("keymapping")
keymapping("del", "cmd+backspace", "com.apple.finder")
local flagMethods = {}
function flagMethods:containExactly(modifiers)
    local required = {}
    for _, modifier in ipairs(modifiers) do required[modifier] = true end
    for modifier in pairs(self) do
        if not required[modifier] then return false end
    end
    for modifier in pairs(required) do
        if not self[modifier] then return false end
    end
    return true
end

local function sendEvent(kind, flags, expected, code)
    local copy = {}
    for modifier, value in pairs(flags or {}) do copy[modifier] = value end
    assert(callback({
        getType = function() return hs.eventtap.event.types[kind] end,
        getKeyCode = function() return code or 117 end,
        getFlags = function() return setmetatable(copy, { __index = flagMethods }) end,
    }) == expected)
end

local function send(flags, expected, code)
    local before = trashes
    sendEvent("keyDown", flags, expected, code)
    assert(trashes == before, "按下时不得执行目标动作")
    sendEvent("keyUp", flags, expected, code)
end

send({}, true)
send({ fn = true }, true)
send({ capslock = true }, true)
for _, modifier in ipairs({ "cmd", "ctrl", "alt", "shift" }) do
    send({ [modifier] = true }, false)
end
send({}, false, 51) -- Backspace 不改写。
send({ cmd = true }, false, 14) -- 不处理 Command+E。
front = "com.apple.Safari"
send({}, false)
front = nil
send({}, false)
assert(trashes == 3)
-- 通用映射：源组合键、全局范围、别名及输入校验。
keymapping(" Ctrl + Shift + E ", "cmd+backspace")
send({ ctrl = true, shift = true }, true, 14)
send({ ctrl = true }, false, 14)
send({ ctrl = true, shift = true, alt = true }, false, 14)
send({}, false, 14)
assert(trashes == 4)
keymapping("backspace", "cmd+delete")
send({}, true, 51)
assert(trashes == 5)
assert(not pcall(keymapping, "invalid+e", "cmd+delete"))
assert(not pcall(keymapping, "unknown", "cmd+delete"))
assert(not pcall(keymapping, "e", "cmd+unknown"))
-- 回调及排除列表；切换至排除应用或匹配失败时不执行。
local calls = 0
keymapping("e", function() calls = calls + 1 end, {
    bundleID_excluded = { "com.microsoft.rdc.macos", "com.apple.Safari" },
})
front = "com.microsoft.rdc.macos"
send({}, false, 14)
front = "com.apple.Safari"
send({}, false, 14)
front = "com.apple.finder"
send({}, true, 14)
send({ ctrl = true }, false, 14)
front = nil
send({}, true, 14)
assert(calls == 2)
-- 按下和自动重复均被拦截，只在配对松键时触发一次。
local before = calls
sendEvent("keyDown", {}, true, 14)
sendEvent("keyDown", {}, true, 14)
sendEvent("keyUp", {}, false, 51) -- 其他键的松开不得清除捕获状态。
assert(calls == before)
sendEvent("keyUp", {}, true, 14)
assert(calls == before + 1)
sendEvent("keyUp", {}, false, 14) -- 孤立松键不触发。

-- 切换至排除应用后仍吞掉配对松键，但不执行动作。
sendEvent("keyDown", {}, true, 14)
front = "com.apple.Safari"
sendEvent("keyUp", {}, true, 14)
assert(calls == before + 1)

-- 未拦截的按下，不得因应用或修饰键变化而吞掉松键。
sendEvent("keyDown", {}, false, 14)
front = nil
sendEvent("keyUp", {}, false, 14)
sendEvent("keyDown", { ctrl = true }, false, 14)
sendEvent("keyUp", {}, false, 14)
sendEvent("keyDown", {}, true, 14)
sendEvent("keyUp", { ctrl = true }, true, 14)
assert(calls == before + 1)
-- 直接传函数及多个参数，注册和按下均不执行，松键才调用。
local argumentCalls = 0
local function checkArgs(command, enabled)
    assert(command == "/usr/bin/open ~" and enabled == false)
    argumentCalls = argumentCalls + 1
end
keymapping("e", checkArgs, { args = { "/usr/bin/open ~", false } })
assert(argumentCalls == 0)
sendEvent("keyDown", {}, true, 14)
assert(argumentCalls == 0)
sendEvent("keyUp", {}, true, 14)
assert(argumentCalls == 1)

-- 调用方不保存返回值，监听器也不得被垃圾回收。
local weak = setmetatable({ keymapping("e", function() end) }, { __mode = "v" })
collectgarbage("collect")
assert(weak[1], "keymapping 须在内部持有监听器")
print("finder_trash / keymapping: 测试通过（未操作真实文件）")
