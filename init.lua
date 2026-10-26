-- require("hs.ipc") -- 临时诊断接口。
powerpoint = require("powerpoint")
minimize = require("minimize")


local keymapping = require("keymapping")

-- Option + E：Finder Open Home
keymapping("alt+e", hs.execute, { args = { "/usr/bin/open ~" } })

-- Del: Finder Cmd+Backspace（移到废纸篓）。
keymapping("del", "cmd+backspace", "com.apple.finder")

-- F11：切换 Windows App 远程窗口的全屏状态。
keymapping("f11", function()
    local window = hs.window.focusedWindow()
    if window then window:setFullScreen(not window:isFullScreen()) end
end, "com.microsoft.rdc.macos")

-- Option: open apps，exclude `Windows App`
keymapping("alt", hs.application.launchOrFocus, {
    args = { "/System/Applications/Apps.app" },
    bundleID_excluded = { "com.microsoft.rdc.macos" },
})
