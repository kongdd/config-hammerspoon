<h1>hammerspoon个人配置</h1>

## Apps

- `apps.lua` 使用 `keymapping`：单按左 Option 打开 Apps（1 秒内松开）；组合键不变，排除 Windows App。
- 使用 Hammerspoon 监听系统事件，支持 RustDesk 远程输入；Karabiner 不再处理此功能。

## 窗口

- `finder.lua`：option + e 在 Finder 中打开主目录 `~`。
- Finder 中单按 Del，松键时映射为 Cmd+Backspace（移到废纸篓）。
- `keymapping.lua`：`keymapping("ctrl+shift+a", "cmd+b", options)`；目标也可为回调。`options` 支持 `bundleID`、`bundleID_excluded` 列表、修饰键单按的 `timeout`（默认 1 秒）；兼容第三参数直接传 `bundleID`，省略则全局生效。
- cmd + m：最小化当前窗口；再按一次恢复并聚焦该窗口（即使焦点已切换）。
- Windows App 中按 F11：切换远程窗口全屏，再按一次恢复。

## PowerPoint

- ctrl + up/down/left/right: 选择多对象，上下左右对齐
- ctrl + e/m               : 垂直/水平 居中对齐
- option + c               : 选中image, crop
