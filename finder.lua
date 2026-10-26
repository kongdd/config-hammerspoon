-- ⌥E：在 Finder 中打开主目录。
return hs.hotkey.bind({ "alt" }, "e", function()
    hs.execute("/usr/bin/open ~")
end)
