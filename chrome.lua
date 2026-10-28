local keymapping = require("keymapping")

-- !Chrome shortcuts
keymapping("f5", "cmd+r", "com.google.Chrome")
-- keymapping("cmd+h", "cmd+y", "com.google.Chrome")  -- 可能被系统占用, not work
keymapping("cmd+j", "cmd+shift+j", "com.google.Chrome")

-- Control + V：切换画中画，再按一次恢复。
keymapping("ctrl+v", function()
    local ok, result, err = hs.osascript.applescript([[
        tell application "Google Chrome" to execute active tab of front window javascript "(()=>{
            if(document.pictureInPictureElement){
                document.exitPictureInPicture().catch(e=>alert(e.message));
                return false;
            }
            document.addEventListener('keydown',event=>{
                if(event.code!=='F18')return;
                event.preventDefault();
                event.stopImmediatePropagation();
                const videos=[...document.querySelectorAll('video')].filter(v=>v.readyState>0);
                const video=videos.find(v=>!v.paused)||videos[0];
                if(!video)return alert('未找到已加载的视频');
                navigator.mediaSession.setActionHandler('play',()=>video.play().catch(e=>alert(e.message)));
                navigator.mediaSession.setActionHandler('pause',()=>video.pause());
                video.requestPictureInPicture().catch(e=>alert(e.message));
            },{once:true,capture:true,signal:AbortSignal.timeout(1000)});
            return true;
        })()"
    ]])
    if not ok then
        hs.showError(hs.inspect(err))
    elseif result then
        -- 真实按键满足 Chrome 的用户手势要求。
        hs.eventtap.keyStroke({}, "f18", 0)
    end
end, "com.google.Chrome")

-- Control + Option + G：复制选中文本并用 Google 搜索。
keymapping("ctrl+g", function()
    local count = hs.pasteboard.changeCount()
    hs.eventtap.keyStroke({ "cmd" }, "c")
    hs.timer.doAfter(0.05, function()
        if hs.pasteboard.changeCount() == count then return end
        local text = hs.pasteboard.getContents()
        if text and text ~= "" then
            hs.urlevent.openURLWithBundle(
                "https://www.google.com/search?q=" .. hs.http.encodeForQuery(text), "com.google.Chrome")
        end
    end)
end, "com.google.Chrome")
