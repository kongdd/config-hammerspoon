<h1>hammerspoon个人配置</h1>

## Apps

- 单按左 Option：打开 Apps（1 秒内松开）；组合键不变，排除 Windows App。
- 使用 Hammerspoon 监听系统事件，支持 RustDesk 远程输入；Karabiner 不再处理此功能。

## 窗口

- `finder.lua`：option + e 在 Finder 中打开主目录 `~`。
- `finder_trash.lua`：Finder 中单按 Del，松键时调用“移到废纸篓”菜单；不合成修饰键，不检查输入框或焦点。
- cmd + m：最小化当前窗口；再按一次恢复并聚焦该窗口（即使焦点已切换）。

## PowerPoint

- ctrl + up/down/left/right: 选择多对象，上下左右对齐
- ctrl + e/m               : 垂直/水平 居中对齐
- option + c               : 选中image, crop
