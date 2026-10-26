-- Finder 中将 Del 映射为 Cmd+Backspace（移到废纸篓）。
return hs.eventtap.new({ hs.eventtap.event.types.keyUp }, function(event)
    if event:getKeyCode() ~= hs.keycodes.map.forwarddelete then return false end
    
    local flags = event:getFlags()
    if flags.cmd or flags.ctrl or flags.alt or flags.shift then return false end

    local app = hs.application.frontmostApplication()
    if not app or app:bundleID() ~= "com.apple.finder" then return false end
    hs.eventtap.keyStroke({ "cmd" }, "delete", 0)
    return true
end):start()
