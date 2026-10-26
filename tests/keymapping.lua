-- luajit tests/keymapping.lua；不操作真实应用。
local setup = require("tests.helpers.keymapping")

local function stroke(test, code, flags, expected)
    assert(test.send("keyDown", code, flags) == expected)
    assert(test.send("keyUp", code, flags) == expected)
end

-- 通用解析、别名、全局范围及输入校验，不依赖 Finder 配置。
do
    local test = setup()
    test.front = nil
    test.bind(" Ctrl + Shift + E ", "cmd+backspace")
    stroke(test, 14, { ctrl = true, shift = true }, true)
    stroke(test, 14, { ctrl = true }, false)
    stroke(test, 14, { ctrl = true, shift = true, alt = true }, false)
    stroke(test, 14, {}, false)
    test.bind("backspace", "cmd+delete")
    stroke(test, 51, {}, true)
    test.flush()
    assert(#test.posted == 4 and #test.errors == 0)
    assert(not pcall(test.bind, "invalid+e", "cmd+delete"))
    assert(not pcall(test.bind, "unknown", "cmd+delete"))
    assert(not pcall(test.bind, "e", "cmd+unknown"))
end

-- 排除列表、无前台应用、成对吞键、重复及孤立松键。
do
    local test, calls = setup(), 0
    test.bind("e", function() calls = calls + 1 end, {
        bundleID_excluded = { "com.microsoft.rdc.macos", "com.apple.Safari" },
    })
    for _, id in ipairs({ "com.microsoft.rdc.macos", "com.apple.Safari" }) do
        test.front = id
        stroke(test, 14, {}, false)
    end
    test.front = "com.apple.finder"
    stroke(test, 14, {}, true)
    stroke(test, 14, { ctrl = true }, false)
    test.front = nil
    stroke(test, 14, {}, true)
    assert(calls == 2)

    assert(test.send("keyDown", 14))
    assert(test.send("keyDown", 14))
    assert(not test.send("keyUp", 51)) -- 其他键松开不得清除捕获状态。
    assert(calls == 2, "按下及自动重复均不得执行动作")
    assert(test.send("keyUp", 14))
    assert(not test.send("keyUp", 14)) -- 孤立松键不触发。
    assert(calls == 3)

    -- 修饰键、应用均改变时，仍吞掉已捕获的松键，但不在排除应用中执行。
    assert(test.send("keyDown", 14))
    test.front = "com.apple.Safari"
    assert(test.send("keyUp", 14, { ctrl = true }))
    assert(calls == 3)
    assert(not test.send("keyDown", 14))
    test.front = nil
    assert(not test.send("keyUp", 14)) -- 未捕获按下，不能因应用改变而接管松键。
    assert(test.send("keyDown", 14))
    assert(test.send("keyUp", 14, { ctrl = true }))
    assert(calls == 4 and #test.errors == 0)
end

-- 回调参数延迟传入；生产模块必须自行持有监听器，模拟器不能代为持有。
do
    local test, calls = setup(), 0
    test.bind("e", function(command, enabled)
        assert(command == "/usr/bin/open ~" and enabled == false)
        calls = calls + 1
    end, { args = { "/usr/bin/open ~", false } })
    assert(calls == 0, "注册时不得执行动作")
    assert(test.send("keyDown", 14))
    assert(calls == 0, "按下时不得执行动作")
    assert(test.send("keyUp", 14))
    assert(calls == 1 and #test.errors == 0)
    local weak = setmetatable({ test.bind("e", function() end) }, { __mode = "v" })
    collectgarbage("collect")
    assert(weak[1], "keymapping 须在内部持有监听器")
end

-- 自身映射与循环映射：只发送一对目标事件，不触发其他映射。
for _, cycle in ipairs({ false, true }) do
    local test = setup()
    test.bind("a", cycle and "b" or "a")
    if cycle then test.bind("b", "a") end
    assert(test.send("keyDown", 0))
    assert(test.send("keyUp", 0))
    test.flush()
    assert(#test.posted == 2)
end

-- 无论先松主键还是修饰键，组合键都只触发一次。
for _, modifierFirst in ipairs({ true, false }) do
    local test, calls = setup(), 0
    test.bind("alt+e", function() calls = calls + 1 end)
    assert(test.send("keyDown", 14, { alt = true }))
    if modifierFirst then test.send("flagsChanged", 58) end
    assert(test.send("keyUp", 14, modifierFirst and {} or { alt = true }))
    if not modifierFirst then test.send("flagsChanged", 58) end
    assert(calls == 1)
end

-- 普通映射吞掉组合键时，单按监听仍须取消，不受注册顺序影响。
for _, modifierFirst in ipairs({ true, false }) do
    local test, apps, shortcuts = setup(), 0, 0
    local function bindModifier() test.bind("alt", function() apps = apps + 1 end) end
    local function bindShortcut() test.bind("alt+e", function() shortcuts = shortcuts + 1 end) end
    if modifierFirst then bindModifier() else bindShortcut() end
    if modifierFirst then bindShortcut() else bindModifier() end
    test.send("flagsChanged", 58, { alt = true })
    assert(test.send("keyDown", 14, { alt = true }))
    assert(test.send("keyUp", 14, { alt = true }))
    test.send("flagsChanged", 58)
    assert(apps == 0 and shortcuts == 1)

    -- 远程修饰键的 keyDown 与 flagsChanged 重复通知，不得误取消。
    test.send("keyDown", 58)
    test.send("flagsChanged", 58, { alt = true })
    test.send("keyUp", 58)
    test.send("flagsChanged", 58)
    assert(apps == 1)
end

-- 首次按下未匹配时，自动重复不得因修饰键变化而接管按键。
do
    local test, calls = setup(), 0
    test.bind("e", function() calls = calls + 1 end)
    assert(not test.send("keyDown", 14, { ctrl = true }))
    assert(not test.send("keyDown", 14))
    assert(not test.send("keyUp", 14))
    assert(calls == 0)
end
-- 单按取消后，重复按下通知不得重新激活；真正松开后才能开始下一次单按。
for _, kind in ipairs({ "flagsChanged", "keyDown" }) do
    for _, reason in ipairs({ "key", "modifier", "mouse", "application" }) do
        local test, calls = setup(), 0
        local release = kind == "keyDown" and "keyUp" or "flagsChanged"
        test.bind("alt", function() calls = calls + 1 end, {
            bundleID_excluded = { "com.apple.Safari" },
        })
        test.send(kind, 58, { alt = true })
        if reason == "key" then
            test.send("keyDown", 14, { alt = true })
            test.send("keyUp", 14, { alt = true })
        elseif reason == "modifier" then
            test.send("flagsChanged", 55, { alt = true, ctrl = true })
            test.send("flagsChanged", 55, { alt = true })
        elseif reason == "mouse" then
            test.send("leftMouseDown", 0, { alt = true })
        else
            test.front = "com.apple.Safari"
            test.send(kind, 58, { alt = true })
            test.front = "com.apple.finder"
        end
        test.send(kind, 58, { alt = true })
        test.send(release, 58)
        assert(calls == 0, kind .. "/" .. reason .. "：取消后不得重新激活")
        test.send(kind, 58, { alt = true })
        test.send(release, 58)
        assert(calls == 1, "松开后必须恢复正常单按")
    end
end
-- 混合输入不依赖按下、松开通知的先后顺序；四种修饰键均须去重。
local modifiers = {
    { "cmd", 55, 54, "Command" }, { "shift", 56, 60, "Shift" },
    { "alt", 58, 61, "Alternate" }, { "ctrl", 59, 62, "Control" },
}
local masks = require("tests.helpers.keyflags")
for _, modifier in ipairs(modifiers) do
    local name, left, right, suffix = unpack(modifier)
    local leftMask, rightMask = masks["deviceLeft" .. suffix], masks["deviceRight" .. suffix]
    for _, flagsFirst in ipairs({ true, false }) do
        for _, flagsUpFirst in ipairs({ true, false }) do
            local test, calls = setup(), 0
            test.bind(name, function() calls = calls + 1 end)
            local function send(first, a, b, flags, raw)
                test.send(first and a or b, left, flags, raw)
                test.send(first and b or a, left, flags, raw)
            end
            send(flagsFirst, "flagsChanged", "keyDown", { [name] = true }, leftMask)
            send(flagsUpFirst, "flagsChanged", "keyUp", {}, 0)
            assert(calls == 1, "混合通知只能触发一次：" .. name)
        end
    end

    -- 左右交叠后不能遗留锁定；按住右键时的左键也不算单按。
    for _, remote in ipairs({ false, true }) do
        local test, calls = setup(), 0
        test.bind(name, function() calls = calls + 1 end)
        local flags = { [name] = true }
        if remote then
            test.send("flagsChanged", right, flags, rightMask)
            test.send("keyDown", left, flags, leftMask + rightMask)
            test.send("keyUp", left, flags, rightMask)
        else
            test.send("flagsChanged", left, flags, leftMask)
            test.send("flagsChanged", right, flags, leftMask + rightMask)
            test.send("flagsChanged", left, flags, rightMask)
        end
        test.send("flagsChanged", right, {}, 0)
        assert(calls == 0, "左右同时使用不能触发单按：" .. name)
        test.send("flagsChanged", left, flags, leftMask)
        test.send("flagsChanged", left, {}, 0)
        assert(calls == 1, "左右交叠后必须恢复单按：" .. name)
    end
end

-- 回调异常必须上报，但不能逸出监听器、吞掉修饰键松开或污染下一次触发。
for _, source in ipairs({ "alt", "e" }) do
    local test, calls = setup(), 0
    test.bind(source, function()
        calls = calls + 1
        if calls == 1 then error("模拟动作失败") end
    end)
    local single = source == "alt"
    for _ = 1, 2 do
        assert(test.send(single and "flagsChanged" or "keyDown", single and 58 or 14,
            single and { alt = true } or {}, single and masks.deviceLeftAlternate or 0) == not single)
        assert(test.send(single and "flagsChanged" or "keyUp", single and 58 or 14) == not single)
    end
    assert(calls == 2 and #test.errors == 1)
    assert(test.errors[1]:find("模拟动作失败", 1, true), "必须保留错误信息及堆栈")
end
print("keymapping: 边界回归测试通过")
