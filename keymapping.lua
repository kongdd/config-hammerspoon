-- 快捷键写作 "ctrl+shift+a"；目标可为快捷键或函数，松键时触发。
local aliases = { del = "forwarddelete", backspace = "delete" }
local modifiers = { cmd = true, ctrl = true, alt = true, shift = true }
local taps = {} -- 持有监听器，调用方无需保存返回值。
local heldKeys, inputVersion = {}, 0 -- 共享按键状态，避免吞键导致单按误判。
local synthetic = 0x4B4D4150 -- 标记合成事件，防止循环映射。
local unpack = table.unpack or unpack
local eventAPI = hs.eventtap.event
local types, sourceProperty = eventAPI.types, eventAPI.properties.eventSourceUserData
local masks = eventAPI.rawFlagMasks
local modifierKeys = {
    [55] = { name = "cmd", mask = masks.deviceLeftCommand, other = 54 },
    [54] = { name = "cmd", mask = masks.deviceRightCommand, other = 55 },
    [56] = { name = "shift", mask = masks.deviceLeftShift, other = 60 },
    [60] = { name = "shift", mask = masks.deviceRightShift, other = 56 },
    [58] = { name = "alt", mask = masks.deviceLeftAlternate, other = 61 },
    [61] = { name = "alt", mask = masks.deviceRightAlternate, other = 58 },
    [59] = { name = "ctrl", mask = masks.deviceLeftControl, other = 62 },
    [62] = { name = "ctrl", mask = masks.deviceRightControl, other = 59 },
}
local keyEvents = { types.keyDown, types.keyUp }
local modifierEvents = {
    types.flagsChanged, types.keyDown, types.keyUp,
    types.leftMouseDown, types.rightMouseDown, types.otherMouseDown, types.scrollWheel,
}

-- 最后一项是主键；兼容大小写、空格和别名。
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
    return { key = key, code = hs.keycodes.map[key], modifiers = parts, single = modifiers[key] }
end

-- 将函数及参数、目标快捷键统一为可执行动作。
local function makeAction(to, args)
    if type(to) == "function" then
        return function() to(unpack(args or {})) end
    end
    assert(type(to) == "string", "目标必须是快捷键或函数")
    local target = parse(to)
    return function()
        for _, down in ipairs({ true, false }) do
            eventAPI.newKeyEvent(target.modifiers, target.key, down)
                :setProperty(sourceProperty, synthetic):post()
        end
    end
end

local function inApp(options)
    if not options.bundleID and not options.bundleID_excluded then return true end
    local app = hs.application.frontmostApplication()
    local id = app and app:bundleID()
    if options.bundleID and id ~= options.bundleID then return false end
    for _, excluded in ipairs(options.bundleID_excluded or {}) do
        if id == excluded then return false end
    end
    return true
end

-- 兼容 Lua / LuaJIT，不依赖特定位运算语法。
local function hasFlag(raw, mask)
    return math.floor(raw / mask) % 2 == 1
end

-- 实体键按设备级标志区分左右；远程事件可能只有合并后的修饰键标志。
local function modifierState(event, modifier, flags)
    local raw = event:rawFlags()
    local down = hasFlag(raw, modifier.mask)
    local other = hasFlag(raw, modifierKeys[modifier.other].mask)
    if down or other then return down, other end
    if event:getType() == types.flagsChanged and not flags[modifier.name] then return false, false end
    return not not flags[modifier.name] -- 未提供左右标志时，不猜测另一侧的状态。
end

-- 只在真正从松开变为按下时计数，混合通知及多个监听器均幂等。
local function trackKey(code, down)
    if down and not heldKeys[code] then inputVersion = inputVersion + 1 end
    heldKeys[code] = down or nil
end

local function readInput(event)
    if event:getProperty(sourceProperty) == synthetic then return end
    local kind, code, flags = event:getType(), event:getKeyCode(), event:getFlags()
    local keyboard = kind == types.keyDown or kind == types.keyUp or kind == types.flagsChanged
    if not keyboard then return kind, code, flags, false end
    local down = kind == types.keyDown
    local modifier = modifierKeys[code]
    if modifier then
        local physical, other = modifierState(event, modifier, flags)
        if kind == types.flagsChanged then down = physical end
        if other ~= nil then trackKey(modifier.other, other) end
    end
    trackKey(code, down)
    return kind, code, flags, down
end

local function matches(source, kind, code, flags)
    local keyboard = kind == types.flagsChanged or kind == types.keyDown or kind == types.keyUp
    if not keyboard or code ~= source.code then return false end
    flags.capslock = nil -- Caps Lock 不参与匹配；普通映射也忽略 Fn。
    if source.single then
        flags[source.key] = nil
        for held in pairs(heldKeys) do
            if held ~= source.code then return false end
        end
    else
        flags.fn = nil
    end
    return flags:containExactly(source.modifiers)
end

-- 动作异常须保留堆栈并上报，不能逸出原生监听器而吞掉松键事件。
local function perform(action)
    local ok, err = xpcall(action, debug.traceback)
    if not ok then hs.showError(err) end
end

-- 管理一次按下到松开的状态，普通键拦截，修饰键放行。
local function makeHandler(source, action, options)
    local pending -- nil：未按下；false：未匹配；table：已匹配，等待松键。
    return function(event)
        local kind, code, flags, down = readInput(event)
        if not kind or (not source.single and code ~= source.code) then return false end
        local allowed = inApp(options)
        local valid = allowed and matches(source, kind, code, flags)
        if source.single and not valid then
            pending = nil
            if heldKeys[source.code] then pending = false end -- 松开前保持取消状态。
            return false
        end
        if down then
            if pending == nil then
                pending = valid and { time = hs.timer.secondsSinceEpoch(), version = inputVersion } or false
            end
            return not source.single and pending ~= false
        end

        -- 先清空再执行；只对单按检查中途操作及超时，不受普通组合键松键顺序影响。
        local press = pending
        pending = nil
        if press and allowed and (not source.single or (press.version == inputVersion
            and hs.timer.secondsSinceEpoch() - press.time <= (options.timeout or 1))) then
            perform(action)
        end
        return not source.single and not not press
    end
end

-- options：args、bundleID、bundleID_excluded、timeout（单按默认 1 秒）。
return function(from, to, options)
    if type(options) == "string" then options = { bundleID = options } end
    options = options or {}
    local source = parse(from)
    assert(not source.single or #source.modifiers == 0, "修饰键单按不能附带其他修饰键")
    local action = makeAction(to, options.args)
    local events = source.single and modifierEvents or keyEvents
    local tap = hs.eventtap.new(events, makeHandler(source, action, options)):start()
    taps[#taps + 1] = tap
    return tap
end
