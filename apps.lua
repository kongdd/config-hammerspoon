-- 单按左 Option 打开 Apps；组合键放行，保留 Karabiner 原有的 1 秒超时。
local types = hs.eventtap.event.types
local pressedAt

local function excluded()
    local app = hs.application.frontmostApplication()
    return app and app:bundleID() == "com.microsoft.rdc.macos"
end

return hs.eventtap.new({
    types.flagsChanged, types.keyDown, types.keyUp,
    types.leftMouseDown, types.rightMouseDown, types.otherMouseDown, types.scrollWheel,
}, function(event)
    local kind, code = event:getType(), event:getKeyCode()
    local keyboard = kind == types.flagsChanged or kind == types.keyDown or kind == types.keyUp
    if not keyboard or code ~= hs.keycodes.map.alt then
        pressedAt = nil
        return false
    end

    local flags = event:getFlags()
    if flags.cmd or flags.ctrl or flags.shift or flags.fn or excluded() then
        pressedAt = nil
        return false
    end

    -- 实体键通常产生 flagsChanged；远程注入也可能使用 keyDown/keyUp。
    local down = kind == types.keyDown or (kind == types.flagsChanged and flags.alt)
    if down then
        pressedAt = pressedAt or hs.timer.secondsSinceEpoch()
    else
        local start = pressedAt
        pressedAt = nil
        if start and hs.timer.secondsSinceEpoch() - start <= 1 then
            hs.application.launchOrFocus("/System/Applications/Apps.app")
        end
    end
    return false
end):start()
