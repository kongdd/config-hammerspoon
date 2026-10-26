-- luajit ~/.hammerspoon/tests/finder_trash.lua；不操作真实文件。
local callback, front, trashes = nil, "com.apple.finder", 0
hs = {
    keycodes = { map = { forwarddelete = 117 } },
    application = { frontmostApplication = function()
        if front then return {
            bundleID = function() return front end,
            selectMenuItem = function(_, path)
                assert(path[1] == "文件" and path[2] == "移到废纸篓")
                trashes = trashes + 1
            end,
        } end
    end },
    eventtap = {
        event = { types = { keyUp = 2 } },
        new = function(events, fn)
            assert(#events == 1 and events[1] == 2)
            callback = fn
            return { start = function(self) return self end }
        end,
    },
}
dofile(os.getenv("HOME") .. "/.hammerspoon/finder_trash.lua")
local function send(flags, expected, code)
    assert(callback({
        getKeyCode = function() return code or 117 end,
        getFlags = function() return flags or {} end,
    }) == expected)
end

send({}, true)
send({ fn = true }, true)
send({ capslock = true }, true)
for _, modifier in ipairs({ "cmd", "ctrl", "alt", "shift" }) do
    send({ [modifier] = true }, false)
end
send({}, false, 51) -- Backspace 不改写。
send({ cmd = true }, false, 14) -- 不处理 Command+E。
front = "com.apple.Safari"
send({}, false)
front = nil
send({}, false)
assert(trashes == 3)
print("finder_trash: 测试通过（未操作真实文件）")
