-- 无需启动 PPT 的回归测试：luajit ~/.hammerspoon/tests/powerpoint.lua
-- 仅验证控制逻辑，不代替实际 PowerPoint 界面测试。
local checks, clicks, handlingKey = 0, {}, false
local lastKey
local consumedKeys = {}
local selected, permission, menuError = true, true, false
local shapeSelection, scriptOK = true, true
local windowID, focus, current, modifiers = 1, nil, nil, {}
local alignNames = {
    ["align lefts"] = "左对齐", ["align centers"] = "居中", ["align rights"] = "右对齐",
    ["align tops"] = "顶部对齐", ["align middles"] = "垂直居中", ["align bottoms"] = "底部对齐",
}
local function check(value)
    checks = checks + 1
    assert(value, "检查失败：" .. checks)
end
local function node(attributes)
    return { attributeValue = function(_, key) return attributes[key] end }
end
local function canvas() return node({ AXRole = "AXLayoutArea" }) end
local app = {
    bundleID = function() return "com.microsoft.Powerpoint" end,
    focusedWindow = function()
        if windowID then return { id = function() return windowID end } end
    end,
    findMenuItem = function(_, path)
        assert(not handlingKey, "禁止在按键回调内查询菜单")
        assert(path[1] == "格式" and path[2] == "裁剪", "对齐不得查询菜单")
        if menuError then error("AX menu unavailable") end
        return { enabled = selected }
    end,
    selectMenuItem = function(_, path)
        assert(not handlingKey, "禁止在按键回调内点击菜单")
        assert(path[1] == "格式" and path[2] == "裁剪", "对齐不得通过菜单执行")
        clicks[#clicks + 1] = path[#path]
        return true
    end,
}
current, focus = app, canvas()
local types = { keyDown = 10, keyUp = 11, flagsChanged = 12 }
hs = {
    application = { frontmostApplication = function() return current end },
    accessibilityState = function() return permission end,
    osascript = { applescript = function(script)
        assert(not handlingKey, "禁止在按键回调内运行 AppleScript")
        if not scriptOK or not shapeSelection then return scriptOK, false end
        local command = script:match("align type (align %w+)")
        if command then
            if not selected then return true, false end
            clicks[#clicks + 1] = assert(alignNames[command])
        end
        return true, true
    end },
    axuielement = { systemWideElement = function()
        return node({ AXFocusedUIElement = focus })
    end },
    keycodes = { map = {} },
    eventtap = {
        event = { types = types },
        checkKeyboardModifiers = function()
            assert(not handlingKey, "回调内应读取事件标志，不能依赖可能滞后的系统轮询状态")
            return modifiers or {}
        end,
    },
    timer = { doAfter = function(delay, callback)
        return { callback = callback, delay = delay,
            stop = function(self) self.stopped = true end,
            fire = function(self) if not self.stopped then self.callback() end end }
    end },
}
for code, key in ipairs({ "h", "v", "left", "right", "up", "down", "e", "m", "a", "c" }) do
    hs.keycodes.map[code], hs.keycodes.map[key] = key, code
end
local m
function hs.eventtap.new(events, callback)
    check(events[1] == types.keyDown and events[2] == types.keyUp and events[3] == types.flagsChanged)
    return { callback = callback, start = function(self) self.running = true; return self end }
end
m = dofile(os.getenv("HOME") .. "/.hammerspoon/powerpoint.lua")
local function press(key, flags, expected)
    lastKey = key
    handlingKey = true
    local consumed = m.keyTap.callback({
        getType = function() return types.keyDown end,
        getKeyCode = function() return hs.keycodes.map[key] end,
        getFlags = function() return flags or { ctrl = true } end,
    })
    handlingKey = false
    consumedKeys[hs.keycodes.map[key]] = consumed
    if expected ~= nil then check(consumed == expected) end
    return true
end
-- 普通键松开是 keyUp；修饰键变化只能用 flagsChanged 模拟。
local function release(kind, key, eventFlags)
    handlingKey = true
    local consumed = m.keyTap.callback({
        getType = function() return kind or types.keyUp end,
        getKeyCode = function() return hs.keycodes.map[key or lastKey] end,
        getFlags = function() return eventFlags or modifiers end,
    })
    handlingKey = false
    if kind == types.flagsChanged then
        check(consumed == false) -- 修饰键按下、松开均不得拦截。
    else
        local code = hs.keycodes.map[key or lastKey]
        check(consumed == (consumedKeys[code] == true)) -- 普通键按下、松开须配对。
        consumedKeys[code] = nil
    end
    return consumed
end
local function fire()
    local timer = m.timer
    if timer then timer:fire() end
end
check(m.keyTap.running)
check(press("left", nil, true))
check(#clicks == 0)
modifiers = { ctrl = true }; check(release() and not m.timer)
modifiers = {}; check(not release(types.flagsChanged) and m.timer ~= nil)
check(m.timer.delay == 0.03)
fire(); check(#clicks == 1 and clicks[1] == "左对齐" and m.timer == nil)
-- 新快捷键取消旧定时器，须等最新按键松开。
check(press("left")); release()
local queued = m.timer
check(press("e")); check(queued.stopped and m.timer == nil)
queued:fire(); check(#clicks == 1)
release(); fire(); check(#clicks == 2 and clicks[2] == "居中" and m.timer == nil)
check(press("c", { alt = true })); release(); check(m.timer.delay == 0.15)
fire(); check(clicks[3] == "裁剪")
check(press("c", { alt = true, ctrl = true })); release(); fire(); check(#clicks == 3)
for _, case in ipairs({
    { "right", "右对齐" }, { "up", "顶部对齐" }, { "down", "底部对齐" }, { "m", "垂直居中" },
}) do
    local before = #clicks
    check(press(case[1])); release(); check(#clicks == before)
    fire(); check(#clicks == before + 1 and clicks[#clicks] == case[2])
end
for _, key in ipairs({ "h", "v", "a" }) do
    local before = #clicks
    check(press(key)); release(); fire(); check(#clicks == before)
end
local base = #clicks
selected = false
check(press("left")); release(); fire(); check(#clicks == base)
selected = true
for _, role in ipairs({ "AXTextField", "AXTextArea", "AXComboBox", "AXSearchField", "AXEditableText" }) do
    focus = node({ AXRole = role }); check(press("m", nil, false)); release(); fire()
    check(#clicks == base)
end
for _, attribute in ipairs({ "AXEditable", "AXSelectedTextRange", "AXInsertionPointLineNumber" }) do
    focus = node({ AXRole = "AXGroup", [attribute] = attribute == "AXEditable" and true or 0 })
    check(press("e", nil, false)); release(); fire(); check(#clicks == base)
end
focus = node({ AXRole = "AXStaticText", AXParent = node({ AXRole = "AXTextArea" }) })
check(press("left")); release(); fire(); check(#clicks == base)
-- PPT 的真实行为：焦点为空，或画布带空文本选区；两者均需原生选择类型确认。
for _, missingFocus in ipairs({ true, false }) do
    focus = not missingFocus and node({
        AXRole = "AXLayoutArea", AXSelectedTextRange = { location = 0, length = 0 },
    }) or nil
    check(press("left")); release(); fire()
    check(#clicks == base + 1 and clicks[#clicks] == "左对齐")
    base = #clicks
    shapeSelection = false; check(press("left")); release(); fire(); check(#clicks == base)
    shapeSelection = true
    scriptOK = false; check(press("left")); release(); fire(); check(#clicks == base)
    scriptOK = true
end
base = #clicks
focus = node({}); check(press("left")); release(); fire(); check(#clicks == base)
focus = canvas()
permission = false; check(press("left")); release(); fire(); check(#clicks == base)
permission = true
menuError = true; check(press("c", { alt = true })); release(); fire(); check(#clicks == base)
menuError = false
windowID = nil; check(press("left")); release(); fire(); check(#clicks == base)
windowID = 1
for _, modifier in ipairs({ "cmd", "alt", "shift" }) do
    check(press("left", { ctrl = true, [modifier] = true })); release(); fire()
    check(#clicks == base)
end
-- 延时期间切换窗口、取消选择、进入文字编辑或丢失选择，均不得执行菜单。
for _, change in ipairs({
    function() windowID = 2 end,
    function() selected = false end,
    function() focus = node({ AXRole = "AXTextArea" }) end,
    function() shapeSelection = false end,
}) do
    local before = #clicks
    check(press("left")); release(); change(); fire()
    check(#clicks == before)
    windowID, selected, focus, shapeSelection = 1, true, canvas(), true
end
check(press("left")); current = nil; release(); fire()
check(#clicks == base)
current = app
-- Ctrl 先松开时，必须继续等方向键松开，不能吞掉后续 keyUp。
check(press("left"))
modifiers = {}; check(not release(types.flagsChanged) and not m.timer)
release(); fire(); check(#clicks == base + 1)
base = #clicks
-- 新修饰键按下须取消排队，松开后重新等待。
check(press("left")); release()
local queued = m.timer
modifiers = { ctrl = true }; release(types.flagsChanged)
check(queued.stopped and not m.timer)
queued:fire(); check(#clicks == base)
modifiers = {}; release(types.flagsChanged); fire(); check(#clicks == base + 1)
base = #clicks
-- 即使物理状态先更新、flagsChanged 尚未处理，也不能打开菜单。
check(press("left")); release()
modifiers = { ctrl = true }; fire(); check(#clicks == base)
modifiers = {}; release(types.flagsChanged); fire(); check(#clicks == base + 1)
base = #clicks
-- 实体键松开：事件已无 Ctrl 标志，系统轮询值却要等回调返回后才更新。
check(press("left"))
modifiers = { ctrl = true }; release(); check(not m.timer)
release(types.flagsChanged, nil, {}); check(m.timer ~= nil)
modifiers = {}; fire(); check(#clicks == base + 1 and m.status == "已执行")
print("PASS: " .. checks .. " checks (mocked Hammerspoon; real PPT UI not tested)")
