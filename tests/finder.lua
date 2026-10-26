-- luajit tests/finder.lua；检查 init.lua 注册，不操作真实应用。
local mappings, calls, desktopToggles = {}, 0, 0
hs = {
    execute = function(command)
        assert(command == "/usr/bin/open ~")
        calls = calls + 1
    end,
    application = { launchOrFocus = function() error("注册时不得打开应用") end },
    spaces = { toggleShowDesktop = function() desktopToggles = desktopToggles + 1 end },
}
package.loaded.powerpoint = {}
package.loaded.minimize = {}
package.loaded["hs.ipc"] = {}
package.loaded.keymapping = function(from, to, options)
    mappings[from] = { action = to, options = options }
end
dofile(os.getenv("HOME") .. "/.hammerspoon/init.lua")
assert(calls == 0 and desktopToggles == 0)
local desktop = mappings["alt+d"]
assert(desktop.action == hs.spaces.toggleShowDesktop and desktop.options == nil)
desktop.action()
desktop.action()
assert(desktopToggles == 2)
local home, trash, apps = mappings["alt+e"], mappings.del, mappings.alt
assert(home.action == hs.execute)
home.action(home.options.args[1])
assert(calls == 1)
assert(trash.action == "cmd+backspace" and trash.options == "com.apple.finder")
assert(apps.action == hs.application.launchOrFocus)
assert(apps.options.args[1] == "/System/Applications/Apps.app")
assert(apps.options.bundleID_excluded[1] == "com.microsoft.rdc.macos")
local refresh = mappings.f5
assert(refresh.action == "cmd+r" and refresh.options == "com.google.Chrome")
local downloads = mappings["cmd+j"]
assert(downloads.action == "cmd+shift+j" and downloads.options == "com.google.Chrome")
-- F11 仅注册到 Windows App；切换全屏，无窗口时安全返回。
local fullscreen, toggles = true, 0
local window = {
    isFullScreen = function() return fullscreen end,
    setFullScreen = function(_, value)
        assert(value == not fullscreen)
        fullscreen, toggles = value, toggles + 1
    end,
}
hs.window = { focusedWindow = function() return window end }
local remote = mappings.f11
assert(remote.options == "com.microsoft.rdc.macos")
remote.action()
assert(not fullscreen and toggles == 1)
remote.action()
assert(fullscreen and toggles == 2)
window = nil
remote.action()
assert(toggles == 2)
print("finder / init: 注册测试通过（未操作真实应用）")
