-- require("hs.ipc") -- 临时诊断接口。
powerpoint = require("powerpoint")
minimize = require("minimize")



local keymapping = require("keymapping")

-- ⌥E：在 Finder 中打开主目录。
keymapping("alt+e", hs.execute, { args = { "/usr/bin/open ~" } })

-- Finder 中将 Del 映射为 Cmd+Backspace（移到废纸篓）。
keymapping("del", "cmd+backspace", "com.apple.finder")

-- 单按左 Option 打开 Apps；组合键放行，排除 Windows App。
keymapping("alt", hs.application.launchOrFocus, {
    args = { "/System/Applications/Apps.app" },
    bundleID_excluded = { "com.microsoft.rdc.macos" },
})
