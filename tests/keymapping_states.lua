-- luajit tests/keymapping_states.lua；独立物理状态模型，不操作真实应用。
local setup = require("tests.helpers.keymapping")
local masks = require("tests.helpers.keyflags")
local devices = { "left", "right", "ctrl", "e" }
local codes = { left = 58, right = 61, ctrl = 59, e = 14 }
local deviceMasks = {
    left = masks.deviceLeftAlternate, right = masks.deviceRightAlternate,
    ctrl = masks.deviceLeftControl,
}
local profiles = {
    { name = "native" },
    { name = "key/key", pressFirst = true, releaseFirst = true },
    { name = "flags/flags", pressFirst = false, releaseFirst = false },
    { name = "key/flags", pressFirst = true, releaseFirst = false },
    { name = "flags/key", pressFirst = false, releaseFirst = true },
}

local function flagsFor(held)
    local flags, raw = {}, 0
    if held.left or held.right then flags.alt = true end
    if held.ctrl then flags.ctrl = true end
    for device, mask in pairs(deviceMasks) do
        if held[device] then raw = raw + mask end
    end
    return flags, raw
end

local function emit(test, held, device, down, profile)
    local flags, raw = flagsFor(held)
    local kind = down and "keyDown" or "keyUp"
    if device == "e" then return test.send(kind, codes[device], flags, raw) end
    if device ~= "left" or profile.name == "native" then
        return test.send("flagsChanged", codes[device], flags, raw)
    end
    local keyFirst = profile.releaseFirst
    if down then keyFirst = profile.pressFirst end
    assert(not test.send(keyFirst and kind or "flagsChanged", codes[device], flags, raw))
    return test.send(keyFirst and "flagsChanged" or kind, codes[device], flags, raw)
end

-- 参考模型只看物理按键：没有其他键参与的完整左 Option 按放才能触发。
local function checkModifier(events, profile)
    local test, calls, expected = setup(), 0, 0
    test.bind("alt", function() calls = calls + 1 end, { timeout = 100 })
    local held, eligible = {}, false
    local function apply(device, down)
        if device == "left" then
            if down then eligible = not (held.right or held.ctrl or held.e)
            elseif eligible then expected = expected + 1 end
        elseif held.left then
            eligible = false
        end
        held[device] = down or nil
        local swallowed = emit(test, held, device, down, profile)
        assert(not swallowed, "修饰键监听器不得吞键：" .. profile.name)
        assert(calls == expected, "单按状态与物理模型不符：" .. profile.name)
    end
    for _, event in ipairs(events) do apply(event[1], event[2]) end
    apply("left", true)
    apply("left", false) -- 所有键松开后，必须能开始新的单按。
    assert(#test.errors == 0)
end

-- 普通映射按首次按下的组合捕获，重复及松键都必须与捕获结果配对。
local function checkKeys(events, modifierFirst)
    local test = setup()
    local calls, expected = { plain = 0, chord = 0 }, { plain = 0, chord = 0 }
    local function modifier() test.bind("alt", function() end, { timeout = 100 }) end
    if modifierFirst then modifier() end
    test.bind("e", function() calls.plain = calls.plain + 1 end)
    test.bind("alt+e", function() calls.chord = calls.chord + 1 end)
    if not modifierFirst then modifier() end
    local held, captured = {}, nil
    for _, event in ipairs(events) do
        local device, down = event[1], event[2]
        held[device] = down or nil
        if device == "e" then
            if down then
                captured = not held.ctrl and ((held.left or held.right) and "chord" or "plain") or nil
            elseif captured then
                expected[captured] = expected[captured] + 1
            end
        end
        local swallowed = emit(test, held, device, down, profiles[1])
        assert(swallowed == (device == "e" and captured ~= nil), "按下与松开必须成对拦截")
        if device == "e" and not down then captured = nil end
        if device ~= "e" and held.e then
            local flags, raw = flagsFor(held)
            assert(test.send("keyDown", 14, flags, raw) == (captured ~= nil), "重复不得重新匹配")
        end
        assert(calls.plain == expected.plain and calls.chord == expected.chord, "动作次数不符")
    end
    assert(#test.errors == 0)
end

-- 枚举四个键各按放一次的全部合法顺序，共 8! / 2^4 = 2,520 种。
local phases, events, cases = { left = 0, right = 0, ctrl = 0, e = 0 }, {}, 0
local function enumerate()
    if #events == 8 then
        for _, profile in ipairs(profiles) do
            checkModifier(events, profile)
            cases = cases + 1
        end
        checkKeys(events, true)
        checkKeys(events, false)
        cases = cases + 2
        return
    end
    for _, device in ipairs(devices) do
        local phase = phases[device]
        if phase < 2 then
            phases[device] = phase + 1
            events[#events + 1] = { device, phase == 0 }
            enumerate()
            events[#events] = nil
            phases[device] = phase
        end
    end
end
enumerate()
assert(cases == 17640)
print("keymapping: " .. cases .. " 组有限状态场景通过")
