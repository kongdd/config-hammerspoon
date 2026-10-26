-- luajit tests/finder_trash.lua；只验证 Finder Del，不操作真实文件。
local test = require("tests.helpers.keymapping")()
local types = hs.eventtap.event.types
local property = hs.eventtap.event.properties.eventSourceUserData
test.bind("del", "cmd+backspace", "com.apple.finder")

local function send(flags, expected, code)
    local before = #test.posted
    assert(test.send("keyDown", code or 117, flags) == expected)
    assert(#test.posted == before, "按下时不得执行目标动作")
    assert(test.send("keyUp", code or 117, flags) == expected)
    test.flush()
    assert(#test.posted - before == (expected and 2 or 0))
    if not expected then return end
    for offset = 1, 2 do
        local event = test.posted[before + offset]
        assert(event:getType() == (offset == 1 and types.keyDown or types.keyUp))
        assert(event:getKeyCode() == 51 and event:getFlags():containExactly({ "cmd" }))
        assert(event:getProperty(property) == 0x4B4D4150, "合成按键必须携带标记")
    end
end

send({}, true)
send({ fn = true }, true)
send({ capslock = true }, true)
for _, modifier in ipairs({ "cmd", "ctrl", "alt", "shift" }) do
    send({ [modifier] = true }, false)
end
send({}, false, 51) -- Backspace 不改写。
send({ cmd = true }, false, 14) -- 不处理 Command+E。
test.front = "com.apple.Safari"
send({}, false)
test.front = nil
send({}, false)
assert(#test.posted == 6 and #test.errors == 0)
print("finder_trash: Finder Del 测试通过（未操作真实文件）")
