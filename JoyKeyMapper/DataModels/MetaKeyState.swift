//
//  MetaKeyState.swift
//  JoyKeyMapper
//
//  Created by magicien on 2020/06/16.
//  Copyright © 2020 DarkHorse. All rights reserved.
//

import InputMethodKit

// 定义特殊键的虚拟键码
private let shiftKey = Int32(kVK_Shift)
private let optionKey = Int32(kVK_Option)
private let controlKey = Int32(kVK_Control)
private let commandKey = Int32(kVK_Command)
private let metaKeys = [kVK_Shift, kVK_Option, kVK_Control, kVK_Command]
private var pushedKeyConfigs = Set<KeyMap>()

// 重置所有特殊键的状态
func resetMetaKeyState() {
    let source = CGEventSource(stateID: .hidSystemState)
    pushedKeyConfigs.removeAll()

    DispatchQueue.main.async {
        // 释放所有特殊键
        metaKeys.forEach {
            let ev = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode($0), keyDown: false)
            ev?.post(tap: .cghidEventTap)
        }
    }
}

// 获取当前特殊键的状态
func getMetaKeyState() -> (shift: Bool, option: Bool, control: Bool, command: Bool) {
    var shift: Bool = false
    var option: Bool = false
    var control: Bool = false
    var command: Bool = false
    
    pushedKeyConfigs.forEach {
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt($0.modifiers))
        shift = shift || modifiers.contains(.shift)
        option = option || modifiers.contains(.option)
        control = control || modifiers.contains(.control)
        command = command || modifiers.contains(.command)
    }

    return (shift, option, control, command)
}

/**
 * 处理特殊键事件
 * 此函数必须在主线程中调用
 */
func metaKeyEvent(config: KeyMap, keyDown: Bool) {
    var shift: Bool
    var option: Bool
    var control: Bool
    var command: Bool
    
    if keyDown {
        // 按下键之前检查特殊键是否已被按下
        (shift, option, control, command) = getMetaKeyState()
        pushedKeyConfigs.insert(config)
    } else {
        pushedKeyConfigs.remove(config)
        // 释放键之后检查特殊键是否仍被按下
        (shift, option, control, command) = getMetaKeyState()
    }
    
    let source = CGEventSource(stateID: .hidSystemState)
    let modifiers = NSEvent.ModifierFlags(rawValue: UInt(config.modifiers))
    
    // 根据需要发送特殊键事件
    if !shift && modifiers.contains(.shift) {
        let ev = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Shift), keyDown: keyDown)
        ev?.post(tap: .cghidEventTap)
    }
    
    if !option && modifiers.contains(.option) {
        let ev = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Option), keyDown: keyDown)
        ev?.post(tap: .cghidEventTap)
    }
    
    if !control && modifiers.contains(.control) {
        let ev = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Control), keyDown: keyDown)
        ev?.post(tap: .cghidEventTap)
    }

    if !command && modifiers.contains(.command) {
        let ev = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: keyDown)
        ev?.post(tap: .cghidEventTap)
    }
}
