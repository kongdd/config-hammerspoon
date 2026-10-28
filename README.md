<h1>hammerspoon个人配置</h1>

## Apps

- `apps.lua` 使用 `keymapping`：单按左 Option 打开 Apps（1 秒内松开）；组合键不变，排除 Windows App。
- 使用 Hammerspoon 监听系统事件，支持 RustDesk 远程输入；Karabiner 不再处理此功能。

## 窗口

- `finder.lua`：option + e 在 Finder 中打开主目录 `~`。
- Finder 中单按 Del，松键时映射为 Cmd+Backspace（移到废纸篓）。
- `keymapping.lua`：`keymapping("ctrl+shift+a", "cmd+b", options)`；目标也可为回调。`options` 支持 `bundleID`、`bundleID_excluded` 列表、修饰键单按的 `timeout`（默认 1 秒）；兼容第三参数直接传 `bundleID`，省略则全局生效。
- cmd + m：最小化当前窗口；再按一次恢复并聚焦该窗口（即使焦点已切换）。
- Chrome 中按 F5：映射为 Cmd+R，刷新页面。
- Chrome 中按 Cmd+J：映射为 Cmd+Shift+J，打开下载内容。
- Chrome 中按 Ctrl+V：切换画中画，再按一次恢复；优先选择正在播放的视频。
- Chrome 中选中文本后按 Control+Option+G：用 Google 搜索（会覆盖剪贴板）。
- Windows App 中按 F11：切换远程窗口全屏，再按一次恢复。
- option + d：显示系统桌面，再按一次恢复之前的窗口。
- option + left/right：将当前窗口放置于屏幕左半/右半。
- option + enter：最大化当前窗口，保留菜单栏和 Dock。
- shift + option + left/right：将当前窗口移到左侧/右侧屏幕。

## PowerPoint

- ctrl + up/down/left/right: 选择多对象，上下左右对齐
- ctrl + e/m               : 垂直/水平 居中对齐
- option + c               : 选中image, crop
