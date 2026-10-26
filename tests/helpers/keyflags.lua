-- macOS 设备级修饰键掩码，与 hs.eventtap.event.rawFlagMasks 对应。
return {
    deviceLeftCommand = 0x08, deviceRightCommand = 0x10,
    deviceLeftShift = 0x02, deviceRightShift = 0x04,
    deviceLeftAlternate = 0x20, deviceRightAlternate = 0x40,
    deviceLeftControl = 0x01, deviceRightControl = 0x2000,
}
