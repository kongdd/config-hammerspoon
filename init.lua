-- require("hs.ipc") -- 临时诊断接口。
powerpoint = require("powerpoint")
minimize = require("minimize")



local keymapping = require("keymapping")

-- Option + E：Finder Open Home
keymapping("alt+e", hs.execute, { args = { "/usr/bin/open ~" } })

-- Del       : Finder Cmd+Backspace（移到废纸篓）。
keymapping("del", "cmd+backspace", "com.apple.finder")

-- Option    : open apps，exclude `Windows App`
keymapping("alt", hs.application.launchOrFocus, {
    args = { "/System/Applications/Apps.app" },
    bundleID_excluded = { "com.microsoft.rdc.macos" },
})
