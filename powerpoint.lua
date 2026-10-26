-- PowerPoint：Ctrl + 方向键对齐；Ctrl+E 水平居中；Ctrl+M 垂直居中；Option+C 裁剪。
local M = {}
local types = hs.eventtap.event.types
local align = {
    up = "顶部对齐", down = "底部对齐", left = "左对齐", right = "右对齐",
    e = "居中", m = "垂直居中",
}
local commands = {
    ["顶部对齐"] = "align tops", ["底部对齐"] = "align bottoms",
    ["左对齐"] = "align lefts", ["右对齐"] = "align rights",
    ["居中"] = "align centers", ["垂直居中"] = "align middles",
}
local pending -- 对齐等普通键松开；裁剪还需等修饰键松开
local swallowed = {} -- 配对拦截普通键；修饰键事件始终放行

-- 原生选择检查与对齐合并调用，避免遍历 AX 菜单和等待菜单动画。
-- command 为空时只检查选择类型（供裁剪使用）；单个对象相对幻灯片对齐。
local function shapeAction(command)
    local action = command and ([=[
        set selectedShapes to shape range of selection of active window
        align selectedShapes align type %s relative to slide ((count shapes of selectedShapes) is 1)
    ]=]):format(command) or ""
    local ok, applied = hs.osascript.applescript(([[
        with timeout of 1 second
            tell application "Microsoft PowerPoint"
                if (selection type of selection of active window) is not selection type shapes then return false
                %s
                return true
            end tell
        end timeout
    ]]):format(action))
    return ok and applied == true
end

-- 只检查当前焦点，不回溯父节点；执行前再用 PPT 原生选择类型确认。
local function objectFocus()
    local focus = hs.axuielement.systemWideElement():attributeValue("AXFocusedUIElement")
    if not focus then return true end -- PPT 有时不提供 AX 焦点。
    local role = focus:attributeValue("AXRole")
    if role == "AXLayoutArea" then return true end -- 画布也可能暴露空文本选区。
    return (role == "AXScrollArea" or role == "AXWindow" or role == "AXApplication")
        and focus:attributeValue("AXEditable") ~= true
        and focus:attributeValue("AXSelectedTextRange") == nil
        and focus:attributeValue("AXInsertionPointLineNumber") == nil
end

-- 执行前确认窗口与焦点；裁剪额外检查菜单状态及原生选择类型。
local function target(path)
    local ok, result = pcall(function()
        local app = hs.application.frontmostApplication()
        if not app or app:bundleID() ~= "com.microsoft.Powerpoint" then return end
        if not hs.accessibilityState() then return end
        local window = app:focusedWindow()
        if not window or not window:id() or not objectFocus() then return end
        if not commands[path[3]] then
            local item = app:findMenuItem(path)
            if not item or not item.enabled or not shapeAction() then return end
        end
        return { app = app, windowID = window:id() }
    end)
    if ok then return result end
end

local function modifiersDown(flags, allowCtrl)
    flags = flags or hs.eventtap.checkKeyboardModifiers(true)
    return flags.alt or flags.cmd or flags.shift or (flags.ctrl and not allowCtrl)
end

local function queue(flags)
    if M.timer then M.timer:stop(); M.timer = nil end
    if not pending or not pending.released then return end
    local command = commands[pending.path[3]]
    if modifiersDown(flags, command) then return end
    -- 回调内以事件标志为准：实体键松开时，系统轮询状态可能尚未更新。
    -- 原生对齐允许继续按住 Ctrl；裁剪菜单会独占事件循环，须等全部松键。
    M.status = "已排队"
    M.timer = hs.timer.doAfter(command and 0.03 or 0.15, function()
        M.timer = nil
        if modifiersDown(nil, command) then M.status = "修饰键仍按下"; return end
        local action = pending
        pending = nil
        if not action or not action.released then return end
        local now = target(action.path)
        -- 查询期间可能又按下其他修饰键；只有原生对齐允许保留 Ctrl。
        if now and now.windowID == action.windowID and not modifiersDown(nil, command) then
            local applied
            if command then
                applied = shapeAction(command)
            else
                applied = now.app:selectMenuItem(action.path)
            end
            M.status = applied and "已执行" or "执行失败"
        else
            M.status = "目标不可用或窗口已切换"
        end
    end)
end

M.keyTap = hs.eventtap.new({ types.keyDown, types.keyUp, types.flagsChanged }, function(event)
    local kind, code = event:getType(), event:getKeyCode()
    if kind ~= types.keyDown then
        local consumed = kind == types.keyUp and swallowed[code] == true
        if kind == types.keyUp then
            swallowed[code] = nil
            if pending and code == pending.keyCode then pending.released = true end
        end
        -- Ctrl / Option 松开产生 flagsChanged，不是 keyUp；修饰键事件绝不拦截。
        queue(event:getFlags())
        return consumed
    end
    if swallowed[code] then return true end -- 自动重复不重复排队

    local flags, key = event:getFlags(), hs.keycodes.map[event:getKeyCode()]
    if flags.cmd or flags.shift or (flags.ctrl and flags.alt) then return false end
    local path
    if flags.ctrl and align[key] then
        path = { "排列", "对齐或分散", align[key] }
    elseif flags.alt and key == "c" then
        path = { "格式", "裁剪" }
    else
        return false
    end
    -- 按键回调中不查菜单、不运行 AppleScript，避免阻塞原始松键事件。
    local app = hs.application.frontmostApplication()
    if not app or app:bundleID() ~= "com.microsoft.Powerpoint" then return false end
    local window = app:focusedWindow()
    if not window or not window:id() then return false end
    local ok, objects = pcall(objectFocus)
    if not ok or not objects then return false end
    swallowed[code] = true
    pending = { path = path, windowID = window:id(), keyCode = code }
    M.status = "等待松键"
    queue(flags)
    -- 仅拦截普通键，避免 PPT 原生 Ctrl+M 新建幻灯片、方向键移动对象。
    return true
end):start()

return M
