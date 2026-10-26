-- 在 Hammerspoon 中运行：dofile(hs.configdir .. "/tests/powerpoint-ui.lua")
-- 新建临时演示文稿测试六种对齐及裁剪，结束后关闭，不修改已有文件。
local app = hs.application.get("com.microsoft.Powerpoint")
assert(app and powerpoint and powerpoint.keyTap:isEnabled(), "请先启用 PPT 快捷键")
assert(not next(hs.eventtap.checkKeyboardModifiers()), "请先松开所有修饰键")
local original = hs.application.frontmostApplication()
local ok, name, createError = hs.osascript.applescript([[
    tell application "Microsoft PowerPoint"
        set p to make new presentation
        set s to make new slide at end of p with properties {layout:slide layout blank}
        make new shape at end of s with properties {name:"HS-test-A", auto shape type:autoshape rectangle, left position:100, top:100, width:80, height:40}
        make new shape at end of s with properties {name:"HS-test-B", auto shape type:autoshape rectangle, left position:300, top:240, width:120, height:60}
        return name of p
    end tell
]])
assert(ok, hs.inspect(createError))
local scope = 'tell application "Microsoft PowerPoint"\ntell last slide of presentation "' .. name .. '"\n'
local ending = "\nend tell\nend tell"
local cases = {
    { "left", 1 }, { "right", 1, 3 }, { "up", 2 }, { "down", 2, 4 },
    { "e", 1, 3, 0.5 }, { "m", 2, 4, 0.5 },
}
powerpointUITest = { results = {}, document = name, done = false }
local state = powerpointUITest
local clipboard, selectMenuItem
local methods = hs.getObjectMetatable("hs.application")
local appleScript = hs.osascript.applescript
hs.osascript.applescript = function(script, ...)
    local ok, result, err = appleScript(script, ...)
    if state.started and script:find("align selectedShapes", 1, true) then
        state.latencyMs = math.floor((hs.timer.absoluteTime() - state.started) / 1e6)
    end
    return ok, result, err
end
local function finish(err)
    state.error, state.done = err, true
    if selectMenuItem then methods.selectMenuItem = selectMenuItem end
    hs.osascript.applescript = appleScript
    if clipboard then hs.pasteboard.writeAllData(clipboard) end
    hs.osascript.applescript('tell application "Microsoft PowerPoint" to close presentation "' .. name .. '" saving no')
    if original then original:activate() end
end
local function stroke(modifier, key)
    state.started = hs.timer.absoluteTime()
    local event = hs.eventtap.event
    event.newKeyEvent({}, modifier, true):post()
    event.newKeyEvent({ modifier }, key, true):post()
    event.newKeyEvent({ modifier }, key, false):post()
    event.newKeyEvent({}, modifier, false):post()
end
local function crop()
    local image = hs.image.imageFromPath(hs.configdir .. "/images/powerpoint-test.png")
    if not image then finish("缺少裁剪测试图片"); return end
    clipboard = hs.pasteboard.readAllData()
    hs.pasteboard.writeObjects(image)
    stroke("cmd", "v")
    state.timer = hs.timer.doAfter(0.6, function()
        selectMenuItem = methods.selectMenuItem
        methods.selectMenuItem = function(self, path, ...)
            local result = selectMenuItem(self, path, ...)
            if type(path) == "table" and path[1] == "格式" and path[2] == "裁剪" then
                state.cropClicked = result
                state.latencyMs = math.floor((hs.timer.absoluteTime() - state.started) / 1e6)
            end
            return result
        end
        stroke("alt", "c")
        state.timer = hs.timer.doAfter(0.6, function()
            state.results[#state.results + 1] = {
                key = "alt+c", passed = state.cropClicked == true, latencyMs = state.latencyMs,
            }
            finish()
        end)
    end)
end
local function run(index)
    local case = cases[index]
    if not case then crop(); return end
    local success, _, err = hs.osascript.applescript(scope .. [[
        set left position of shape "HS-test-A" to 100
        set top of shape "HS-test-A" to 100
        set left position of shape "HS-test-B" to 300
        set top of shape "HS-test-B" to 240
        select every shape
    ]] .. ending)
    if not success then finish(hs.inspect(err)); return end
    app:activate()
    state.timer = hs.timer.doAfter(0.4, function()
        if hs.application.frontmostApplication():pid() ~= app:pid() then
            finish("PPT 未在前台"); return
        end
        local selected, selection = hs.osascript.applescript([[
            tell application "Microsoft PowerPoint"
                return {selection type of selection of active window, count of shapes of shape range of selection of active window}
            end tell
        ]])
        state.selection = { ok = selected, value = selection }
        state.menu = app:findMenuItem({ "排列", "对齐或分散", "左对齐" })
        local focus = hs.axuielement.systemWideElement():attributeValue("AXFocusedUIElement")
        state.focus = focus and focus:attributeValue("AXRole")
        -- 显式发送修饰键及其松开事件，不能只给方向键加 Ctrl 标志。
        stroke("ctrl", case[1])
        state.timer = hs.timer.doAfter(0.6, function()
            local success, positions, err = hs.osascript.applescript(scope .. [[
                return {{left position, top, width, height} of shape "HS-test-A", {left position, top, width, height} of shape "HS-test-B"}
            ]] .. ending)
            if not success then finish(hs.inspect(err)); return end
            local function edge(shape)
                return shape[case[2]] + (case[3] and shape[case[3]] * (case[4] or 1) or 0)
            end
            local passed = math.abs(edge(positions[1]) - edge(positions[2])) < 0.1
            state.results[#state.results + 1] = {
                key = case[1], passed = passed, positions = positions, latencyMs = state.latencyMs,
            }
            if hs.eventtap.checkKeyboardModifiers().ctrl then
                finish("Ctrl 状态异常"); return
            end
            run(index + 1)
        end)
    end)
end
run(1)
