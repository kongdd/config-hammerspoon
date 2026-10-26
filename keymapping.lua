-- 快捷键写作 "ctrl+shift+a"；目标可为快捷键或回调，松键时触发。
local aliases = { del = "forwarddelete", backspace = "delete" }
local modifiers = { cmd = true, ctrl = true, alt = true, shift = true }
local taps = {} -- 持有监听器，调用方无需保存返回值。
local unpack = table.unpack or unpack

-- 最后一项是主键，其余为修饰键；兼容大小写、空格和按键别名。
local function parse(shortcut)
    local parts = {}
    for part in shortcut:lower():gsub("%s+", ""):gmatch("[^+]+") do
        parts[#parts + 1] = part
    end
    local key = table.remove(parts)
    key = aliases[key] or key
    assert(key and hs.keycodes.map[key], "未知按键：" .. shortcut)
    for _, modifier in ipairs(parts) do
        assert(modifiers[modifier], "未知修饰键：" .. modifier)
    end
    return parts, key
end

-- options：args（回调参数）、bundleID、bundleID_excluded、timeout（单按默认 1 秒）。
return function(from, to, options)
    if type(options) == "string" then options = { bundleID = options } end
    options = options or {}
    local args = options.args or {}
    local fromModifiers, key = parse(from)
    local keyCode, singleModifier = hs.keycodes.map[key], modifiers[key]
    assert(not singleModifier or #fromModifiers == 0, "修饰键单按不能附带其他修饰键")

    -- 统一为回调，后续无需区分按键映射与自定义动作。
    local action = to
    if type(to) == "string" then
        local toModifiers, toKey = parse(to)
        action = function() hs.eventtap.keyStroke(toModifiers, toKey, 0) end
    end
    assert(type(action) == "function", "目标必须是快捷键或回调")

    local types = hs.eventtap.event.types
    -- 普通映射拦截按下和松开；单按修饰键还需监听中途操作，避免组合键误触发。
    local events = { types.keyDown, types.keyUp }
    if singleModifier then
        events = {
            types.flagsChanged, types.keyDown, types.keyUp,
            types.leftMouseDown, types.rightMouseDown, types.otherMouseDown, types.scrollWheel,
        }
    end
    local pressedAt, captured = nil, false
    local tap = hs.eventtap.new(events, function(event)
        local kind = event:getType()
        if not singleModifier and event:getKeyCode() ~= keyCode then return false end
        local keyboard = kind == types.flagsChanged or kind == types.keyDown or kind == types.keyUp
        local flags = event:getFlags()
        -- 实体修饰键产生 flagsChanged；远程注入也可能使用 keyDown/keyUp。
        local down = kind == types.keyDown or (kind == types.flagsChanged and flags[key])
        -- 忽略 Caps Lock；单按时去掉自身标志，普通映射则忽略 Fn。
        flags.capslock = nil
        if singleModifier then flags[key] = nil else flags.fn = nil end
        local valid = keyboard and event:getKeyCode() == keyCode
            and flags:containExactly(fromModifiers)
        -- 指定应用与排除列表同时生效，按当前前台应用判断。
        if valid and (options.bundleID or options.bundleID_excluded) then
            local app = hs.application.frontmostApplication()
            local id = app and app:bundleID()
            valid = not options.bundleID or id == options.bundleID
            for _, excluded in ipairs(options.bundleID_excluded or {}) do
                if id == excluded then valid = false end
            end
        end
        if not singleModifier then
            if down then
                captured = captured or valid
                return captured -- 吞掉按下及自动重复，松键时才执行动作。
            end
            local swallow = captured
            captured = false
            if swallow and valid then action(unpack(args)) end
            return swallow -- 即使修饰键或前台应用已变，也要吞掉配对的松键。
        end
        if not valid then
            pressedAt = nil -- 组合键、鼠标操作或排除应用均取消单按。
        elseif down then
            pressedAt = pressedAt or hs.timer.secondsSinceEpoch() -- 重复按下不重置计时。
        else
            -- 仅在超时前完整单按才触发；先清空状态，避免重复松键再次执行。
            local start = pressedAt
            pressedAt = nil
            if start and hs.timer.secondsSinceEpoch() - start <= (options.timeout or 1) then
                action(unpack(args))
            end
        end
        return false -- 修饰键事件始终放行。
    end):start()
    taps[#taps + 1] = tap
    return tap
end
