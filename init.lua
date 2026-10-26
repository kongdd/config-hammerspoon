-- require("hs.ipc") -- 临时诊断接口。
powerpoint = require("powerpoint")
minimize = require("minimize")


local keymapping = require("keymapping")

-- !系统设置
-- Option + E：Finder Open Home
keymapping("alt+e", hs.execute, { args = { "/usr/bin/open ~" } })

-- Option: open apps，exclude `Windows App`
keymapping("alt", hs.application.launchOrFocus, {
    args = { "/System/Applications/Apps.app" },
    bundleID_excluded = { "com.microsoft.rdc.macos" },
})

-- Option + D：显示桌面，再按一次恢复窗口。
keymapping("alt+d", hs.spaces.toggleShowDesktop)

-- Del: Finder Cmd+Backspace（移到废纸篓）。
keymapping("del", "cmd+backspace", "com.apple.finder")

-- !Chrome shortcuts
keymapping("f5", "cmd+r", "com.google.Chrome")
-- keymapping("cmd+h", "cmd+y", "com.google.Chrome")  -- 可能被系统占用, not work
keymapping("cmd+j", "cmd+shift+j", "com.google.Chrome")

-- !Windows App 远程窗口的全屏状态。
keymapping("f11", function()
    local window = hs.window.focusedWindow()
    if window then window:setFullScreen(not window:isFullScreen()) end
end, "com.microsoft.rdc.macos")
