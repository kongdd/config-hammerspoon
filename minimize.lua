-- ⌘M：最小化当前窗口；再次按下时恢复上次最小化的窗口。
local minimizedID

return hs.hotkey.bind({ "cmd" }, "m", function()
    local window = minimizedID and hs.window.get(minimizedID)
    minimizedID = nil
    if window and window:isMinimized() then
        window:unminimize()
        window:focus()
        return
    end

    window = hs.window.focusedWindow()
    if not window then return end
    -- 最小化状态可能异步更新，必须提前记录，不能立即检查 isMinimized()。
    minimizedID = window:id()
    window:minimize()
end)
