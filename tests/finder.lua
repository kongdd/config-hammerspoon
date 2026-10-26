-- luajit tests/finder.lua；检查 init.lua 注册，不操作真实应用。
local mappings, calls = {}, 0
hs = {
    execute = function(command)
        assert(command == "/usr/bin/open ~")
        calls = calls + 1
    end,
    application = { launchOrFocus = function() error("注册时不得打开应用") end },
}
package.loaded.powerpoint = {}
package.loaded.minimize = {}
package.loaded["hs.ipc"] = {}
package.loaded.keymapping = function(from, to, options)
    mappings[from] = { action = to, options = options }
end
dofile(os.getenv("HOME") .. "/.hammerspoon/init.lua")
assert(calls == 0)
local home, trash, apps = mappings["alt+e"], mappings.del, mappings.alt
assert(home.action == hs.execute)
home.action(home.options.args[1])
assert(calls == 1)
assert(trash.action == "cmd+backspace" and trash.options == "com.apple.finder")
assert(apps.action == hs.application.launchOrFocus)
assert(apps.options.args[1] == "/System/Applications/Apps.app")
assert(apps.options.bundleID_excluded[1] == "com.microsoft.rdc.macos")
print("finder / init: 注册测试通过（未操作真实应用）")
