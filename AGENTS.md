- 遵循Linux极简主义，不要过度设计，一次做好一件事
- 重新加载 Hammerspoon：通过菜单栏点击 `Reload Config`。AppleScript：
  ```sh
  osascript -e 'tell application "System Events" to tell process "Hammerspoon"' \
    -e 'click menu bar item 1 of menu bar 2' \
    -e 'click menu item "Reload Config" of menu 1 of menu bar item 1 of menu bar 2' \
    -e 'end tell'
  ```
