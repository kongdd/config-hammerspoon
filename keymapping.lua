-- 快捷键写作 "ctrl+shift+a"；目标可为快捷键或函数，松键时触发。
local aliases = { del = "forwarddelete", backspace = "delete" }
local modifiers = { cmd = true, ctrl = true, alt = true, shift = true }
local taps = {} -- 持有监听器，调用方无需保存返回值。
local heldKeys, inputVersion = {}, 0 -- 共享按键状态，避免吞键导致单按误判。
local synthetic = 0x4B4D4150 -- 标记合成事件，防止循环映射。
local unpack = table.unpack or unpack
local eventAPI = hs.eventtap.event
local types, sourceProperty = eventAPI.types, eventAPI.properties.eventSourceUserData
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

-- 忽略合成事件；首次按下更新版本，重复通知不重复计数。
local function readInput(event)
    if event:getProperty(sourceProperty) == synthetic then return end
    local kind, code = event:getType(), event:getKeyCode()
    if kind == types.keyDown and not heldKeys[code] then
        inputVersion = inputVersion + 1
        heldKeys[code] = true
    elseif kind == types.keyUp then
        heldKeys[code] = nil
    end
    return kind, code, event:getFlags()
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

-- 管理一次按下到松开的状态，普通键拦截，修饰键放行。
local function makeHandler(source, action, options)
    local pending -- nil：未按下；false：未匹配；table：已匹配，等待松键。
    return function(event)
        local kind, code, flags = readInput(event)
        if not kind or (not source.single and code ~= source.code) then return false end
        -- 实体修饰键用 flagsChanged，远程输入也可能使用 keyDown/keyUp。
        local down = kind == types.keyDown or (kind == types.flagsChanged and flags[source.key])
        local allowed = inApp(options)
        local valid = allowed and matches(source, kind, code, flags)
        if source.single and not valid then
            if code == source.code and not down then
                pending = nil
            elseif pending ~= nil or code == source.code then
                pending = false -- 取消后锁定，直到该修饰键真正松开。
            end
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
            action()
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
