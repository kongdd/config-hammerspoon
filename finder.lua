-- ⌘E 打开 Finder（排除 VS Code / Zed）；Finder 中 Del 移到废纸篓。
local types = hs.eventtap.event.types
local swallowed = {}
local editors = { ["com.microsoft.VSCode"] = true, ["dev.zed.Zed"] = true }

return hs.eventtap.new({ types.keyDown, types.keyUp }, function(event)
    local code = event:getKeyCode()
    if code ~= hs.keycodes.map.e and code ~= hs.keycodes.map.forwarddelete then return false end
    if event:getType() == types.keyUp then
        local action = swallowed[code]
        swallowed[code] = nil
        if action == "open" then hs.application.launchOrFocus("Finder") end
        return action ~= nil
    end
    if swallowed[code] then return true end -- 自动重复不重复执行。

    local flags = event:getFlags()
    if flags.alt or flags.ctrl or flags.shift then return false end
    local app = hs.application.frontmostApplication()
    local id = app and app:bundleID()
    if code == hs.keycodes.map.e then
        if not flags.cmd or flags.fn or editors[id] then return false end
        swallowed[code] = "open"
        return true
    end
    if flags.cmd or id ~= "com.apple.finder" then return false end

    swallowed[code] = "trash"
    -- 直接替换为 ⌘Backspace，不阻塞回调；允许 Fn / Caps Lock，不限制键盘。
    return true, {
        hs.eventtap.event.newKeyEvent({ "cmd" }, "delete", true),
        hs.eventtap.event.newKeyEvent({ "cmd" }, "delete", false),
    }
end):start()
