-- luajit tests/keymapping.lua；模拟事件回灌与多个监听器，不操作真实应用。
local function setup()
    local types = {
        keyDown = 1, keyUp = 2, flagsChanged = 3,
        leftMouseDown = 4, rightMouseDown = 5, otherMouseDown = 6, scrollWheel = 7,
    }
    local map = { a = 0, b = 11, e = 14, alt = 58 }
    local taps, queue, posted, now = {}, {}, {}, 0
    local state = { front = "com.apple.finder", posted = posted }
    local methods = {}
    function methods:containExactly(modifiers)
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

    local function event(kind, code, flags)
        local properties = {}
        return {
            getType = function() return types[kind] end,
            getKeyCode = function() return code end,
            getProperty = function(_, property) return properties[property] or 0 end,
            getFlags = function()
                local copy = {}
                for key, value in pairs(flags or {}) do copy[key] = value end
                return setmetatable(copy, { __index = methods })
            end,
            setProperty = function(self, property, value)
                properties[property] = value
                return self
            end,
            post = function(self)
                posted[#posted + 1] = self
                queue[#queue + 1] = self
                return self
            end,
        }
    end

    hs = {
        keycodes = { map = map },
        timer = { secondsSinceEpoch = function() return now end },
        application = { frontmostApplication = function()
            if state.front then return { bundleID = function() return state.front end } end
        end },
        eventtap = {
            event = {
                types = types,
                properties = { eventSourceUserData = 1 },
                newKeyEvent = function(modifiers, key, down)
                    local flags = {}
                    for _, modifier in ipairs(modifiers) do flags[modifier] = true end
                    return event(down and "keyDown" or "keyUp", map[key], flags)
                end,
            },
            new = function(events, callback)
                local watched = {}
                for _, kind in ipairs(events) do watched[kind] = true end
                local tap = { watched = watched, callback = callback }
                function tap:start() return self end
                taps[#taps + 1] = tap
                return tap
            end,
        },
    }
    -- 与 Hammerspoon 一致：后创建的监听器先处理，吞掉后不再向后传递。
    local function dispatch(input)
        now = now + 0.01
        for i = #taps, 1, -1 do
            local tap = taps[i]
            if tap.watched[input:getType()] and tap.callback(input) then return true end
        end
        return false
    end
    function state.send(kind, code, flags) return dispatch(event(kind, code, flags)) end
    function state.flush()
        local count = 0
        while #queue > 0 do
            count = count + 1
            assert(count <= 20, "合成按键不得无限回灌")
            assert(not dispatch(table.remove(queue, 1)), "合成按键必须放行至应用")
        end
    end
    package.loaded.keymapping = nil
    state.bind = require("keymapping")
    return state
end

-- 自身映射与循环映射：只发送一对目标事件，不触发其他映射。
for _, cycle in ipairs({ false, true }) do
    local test = setup()
    test.bind("a", cycle and "b" or "a")
    if cycle then test.bind("b", "a") end
    assert(test.send("keyDown", 0))
    assert(test.send("keyUp", 0))
    test.flush()
    assert(#test.posted == 2)
end

-- 无论先松主键还是修饰键，组合键都只触发一次。
for _, modifierFirst in ipairs({ true, false }) do
    local test, calls = setup(), 0
    test.bind("alt+e", function() calls = calls + 1 end)
    assert(test.send("keyDown", 14, { alt = true }))
    if modifierFirst then test.send("flagsChanged", 58) end
    assert(test.send("keyUp", 14, modifierFirst and {} or { alt = true }))
    if not modifierFirst then test.send("flagsChanged", 58) end
    assert(calls == 1)
end

-- 应用排除仍生效，即使松键时的修饰键已经改变。
do
    local test, calls = setup(), 0
    test.bind("alt+e", function() calls = calls + 1 end, {
        bundleID_excluded = { "com.apple.Safari" },
    })
    assert(test.send("keyDown", 14, { alt = true }))
    test.front = "com.apple.Safari"
    assert(test.send("keyUp", 14))
    assert(calls == 0)
end

-- 普通映射吞掉组合键时，单按监听仍须取消，不受注册顺序影响。
for _, modifierFirst in ipairs({ true, false }) do
    local test, apps, shortcuts = setup(), 0, 0
    local function bindModifier() test.bind("alt", function() apps = apps + 1 end) end
    local function bindShortcut() test.bind("alt+e", function() shortcuts = shortcuts + 1 end) end
    if modifierFirst then bindModifier() else bindShortcut() end
    if modifierFirst then bindShortcut() else bindModifier() end
    test.send("flagsChanged", 58, { alt = true })
    assert(test.send("keyDown", 14, { alt = true }))
    assert(test.send("keyUp", 14, { alt = true }))
    test.send("flagsChanged", 58)
    assert(apps == 0 and shortcuts == 1)

    -- 远程修饰键的 keyDown 与 flagsChanged 重复通知，不得误取消。
    test.send("keyDown", 58)
    test.send("flagsChanged", 58, { alt = true })
    test.send("keyUp", 58)
    test.send("flagsChanged", 58)
    assert(apps == 1)
end

-- 首次按下未匹配时，自动重复不得因修饰键变化而接管按键。
do
    local test, calls = setup(), 0
    test.bind("e", function() calls = calls + 1 end)
    assert(not test.send("keyDown", 14, { ctrl = true }))
    assert(not test.send("keyDown", 14))
    assert(not test.send("keyUp", 14))
    assert(calls == 0)
end
-- 单按取消后，重复按下通知不得重新激活；真正松开后才能开始下一次单按。
for _, kind in ipairs({ "flagsChanged", "keyDown" }) do
    for _, reason in ipairs({ "key", "modifier", "mouse", "application" }) do
        local test, calls = setup(), 0
        local release = kind == "keyDown" and "keyUp" or "flagsChanged"
        test.bind("alt", function() calls = calls + 1 end, {
            bundleID_excluded = { "com.apple.Safari" },
        })
        test.send(kind, 58, { alt = true })
        if reason == "key" then
            test.send("keyDown", 14, { alt = true })
            test.send("keyUp", 14, { alt = true })
        elseif reason == "modifier" then
            test.send("flagsChanged", 55, { alt = true, ctrl = true })
            test.send("flagsChanged", 55, { alt = true })
        elseif reason == "mouse" then
            test.send("leftMouseDown", 0, { alt = true })
        else
            test.front = "com.apple.Safari"
            test.send(kind, 58, { alt = true })
            test.front = "com.apple.finder"
        end
        test.send(kind, 58, { alt = true })
        test.send(release, 58)
        assert(calls == 0, kind .. "/" .. reason .. "：取消后不得重新激活")
        test.send(kind, 58, { alt = true })
        test.send(release, 58)
        assert(calls == 1, "松开后必须恢复正常单按")
    end
end
print("keymapping: 边界回归测试通过")
