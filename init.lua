-- require("hs.ipc") -- 临时诊断接口。
powerpoint = require("powerpoint")
minimize = require("minimize")
require("chrome")


local keymapping = require("keymapping")

-- !系统设置
-- Option + E：Finder Open Home
hs.hotkey.bind({ "alt" }, "e", function() hs.execute("/usr/bin/open ~") end)

-- Option: open apps，exclude `Windows App`
keymapping("alt", hs.application.launchOrFocus, {
    args = { "/System/Applications/Apps.app" },
    bundleID_excluded = { "com.microsoft.rdc.macos" },
})

-- Option + D：显示桌面，再按一次恢复窗口。
hs.hotkey.bind({ "alt" }, "d", hs.spaces.toggleShowDesktop)

-- Option + Left/Right：窗口占据屏幕左半或右半。
for _, direction in ipairs({ "left", "right" }) do
    hs.hotkey.bind({ "alt" }, direction, function()
        local window = hs.window.focusedWindow()
        if not window then return end
        local frame = window:screen():frame()
        frame.w = frame.w / 2
        if direction == "right" then frame.x = frame.x + frame.w end
        window:setFrame(frame)
    end)
end

-- Shift + Option + Left/Right：将窗口移到相邻屏幕。
for key, method in pairs({ left = "toWest", right = "toEast" }) do
    hs.hotkey.bind({ "shift", "alt" }, key, function()
        local window = hs.window.focusedWindow()
        if not window then return end
        local screen = window:screen()
        local target = screen[method](screen)
        if target then window:moveToScreen(target) end
    end)
end

-- Option + Enter：最大化窗口，保留菜单栏和 Dock。
hs.hotkey.bind({ "alt" }, "return", function()
    local window = hs.window.focusedWindow()
    if window then window:setFrame(window:screen():frame()) end
end)

-- Finder：Del 移到废纸篓，F2 重命名。
keymapping("del", "cmd+backspace", "com.apple.finder")
keymapping("f2", "return", "com.apple.finder")

-- !Windows App 远程窗口的全屏状态。
keymapping("f11", function()
    local window = hs.window.focusedWindow()
    if window then window:setFullScreen(not window:isFullScreen()) end
end, "com.microsoft.rdc.macos")
