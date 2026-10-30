-- luajit tests/modifier_release.lua；合成快捷键须释放新增修饰键，不释放真实按住的键。
local setup = require("tests.helpers.keymapping")

for _, held in ipairs({ false, true }) do
    local test = setup()
    local types = hs.eventtap.event.types
    test.front = "com.google.Chrome"
    test.bind(held and "cmd+f5" or "f5", "cmd+r", "com.google.Chrome")
    local flags = held and { cmd = true } or {}
    assert(test.send("keyDown", 96, flags))
    assert(test.send("keyUp", 96, flags))
    test.flush()
    assert(#test.errors == 0)
    assert(#test.posted == (held and 2 or 3))
    if not held then
        local release = test.posted[3]
        assert(release:getKeyCode() == 55 and release:getType() == types.keyUp)
        assert(release:getFlags():containExactly({}))
        assert(release:getProperty(hs.eventtap.event.properties.eventSourceUserData) == 0x4B4D4150)
    end
end

-- 多个合成修饰键全部释放，同时恢复输入时仍按住的 Option。
do
    local test = setup()
    test.bind("alt+e", "cmd+shift+r")
    assert(test.send("keyDown", 14, { alt = true }))
    assert(test.send("keyUp", 14, { alt = true }))
    test.flush()
    assert(#test.errors == 0 and #test.posted == 4)
    for i, code in ipairs({ 56, 55 }) do
        local release = test.posted[i + 2]
        assert(release:getKeyCode() == code and release:getType() == hs.eventtap.event.types.keyUp)
        assert(release:getFlags():containExactly({ "alt" }))
    end
end
print("modifier_release: 合成修饰键释放回归测试通过")
