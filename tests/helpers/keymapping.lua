-- 多监听器模拟：后注册先处理，吞键后停止传递，合成事件可回灌。
return function()
    local types = {
        keyDown = 1, keyUp = 2, flagsChanged = 3,
        leftMouseDown = 4, rightMouseDown = 5, otherMouseDown = 6, scrollWheel = 7,
    }
    local map = {
        a = 0, b = 11, e = 14, delete = 51, forwarddelete = 117,
        cmd = 55, shift = 56, alt = 58, ctrl = 59,
    }
    local taps = setmetatable({}, { __mode = "v" }) -- 不替生产模块持有监听器，保留 GC 测试意义。
    local queue, now = {}, 0
    local state = { front = "com.apple.finder", posted = {}, errors = {} }
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

    local function event(kind, code, flags, raw)
        local properties = {}
        return {
            getType = function() return types[kind] end,
            getKeyCode = function() return code end,
            getProperty = function(_, property) return properties[property] or 0 end,
            rawFlags = function() return raw or 0 end,
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
                state.posted[#state.posted + 1] = self
                queue[#queue + 1] = self
                return self
            end,
        }
    end

    hs = {
        keycodes = { map = map },
        timer = { secondsSinceEpoch = function() return now end },
        showError = function(message) state.errors[#state.errors + 1] = message end,
        application = { frontmostApplication = function()
            if state.front then return { bundleID = function() return state.front end } end
        end },
        eventtap = {
            event = {
                types = types,
                properties = { eventSourceUserData = 1 },
                rawFlagMasks = require("tests.helpers.keyflags"),
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
    local function dispatch(input)
        now = now + 0.01
        for i = #taps, 1, -1 do
            local tap = taps[i]
            if tap.watched[input:getType()] and tap.callback(input) then return true end
        end
        return false
    end
    function state.advance(seconds) now = now + seconds end
    function state.send(kind, code, flags, raw) return dispatch(event(kind, code, flags, raw)) end
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
