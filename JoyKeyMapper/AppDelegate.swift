//
//  AppDelegate.swift
//  JoyKeyMapper
//
//  Created by magicien on 2019/07/14.
//  Copyright © 2019 DarkHorse. All rights reserved.
//

import AppKit
import ServiceManagement
import UserNotifications
import JoyConSwift

let helperAppID: CFString = "JoyKeyMapperLauncher" as CFString

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    @IBOutlet weak var menu: NSMenu?
    @IBOutlet weak var controllersMenu: NSMenuItem?
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var windowController: NSWindowController?
    
    let manager: JoyConManager = JoyConManager()
    var dataManager: DataManager?
    var controllers: [GameController] = []
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 初始化窗口
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        self.windowController = storyboard.instantiateController(withIdentifier: "JoyKeyMapperWindowController") as? NSWindowController
        
        // 设置菜单
        let icon = NSImage(named: "menu_icon")
        icon?.size = NSSize(width: 24, height: 24)
        self.statusItem.button?.image = icon
        self.statusItem.menu = self.menu

        // 设置控制器处理程序
        self.manager.connectHandler = { [weak self] controller in
            self?.connectController(controller)
        }
        self.manager.disconnectHandler = { [weak self] controller in
            self?.disconnectController(controller)
        }
        
        // 初始化数据管理器
        self.dataManager = DataManager() { [weak self] manager in
            guard let strongSelf = self else { return }
            guard let dataManager = manager else { return }

            // 加载已保存的控制器数据
            dataManager.controllers.forEach { data in
                let gameController = GameController(data: data, dataManager: dataManager)
                strongSelf.controllers.append(gameController)
            }
            _ = strongSelf.manager.runAsync()
            
            // 添加应用程序切换观察者
            NSWorkspace.shared.notificationCenter.addObserver(strongSelf, selector: #selector(strongSelf.didActivateApp), name: NSWorkspace.didActivateApplicationNotification, object: nil)
            
            NotificationCenter.default.post(name: .controllerAdded, object: nil)
        }
        
        // 更新控制器菜单
        self.updateControllersMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(controllerIconChanged), name: .controllerIconChanged, object: nil)
        
        // 设置通知中心
        let center = UNUserNotificationCenter.current()
        center.delegate = self
    }
    
    // MARK: - 菜单相关方法
    
    // 打开关于窗口
    @IBAction func openAbout(_ sender: Any) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(NSApplication.shared)
    }
    
    // 打开设置窗口
    @IBAction func openSettings(_ sender: Any) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.windowController?.showWindow(self)
        self.windowController?.window?.orderFrontRegardless()
        self.windowController?.window?.delegate = self
    }
    
    // 退出应用程序
    @IBAction func quit(_ sender: Any) {
        NSApplication.shared.terminate(self)
    }

    // 更新控制器菜单
    func updateControllersMenu() {
        self.controllersMenu?.submenu?.removeAllItems()

        self.controllers.forEach { controller in
            guard controller.controller?.isConnected ?? false else { return }
            let item = NSMenuItem()

            item.title = ""
            item.image = controller.icon
            item.image?.size = NSSize(width: 32, height: 32)
            
            item.submenu = NSMenu()
            
            // 启用按键映射菜单项
            let enabled = NSMenuItem()
            enabled.title = NSLocalizedString("Enable key mappings", comment: "Enable key mappings")
            enabled.action = Selector(("toggleEnableKeyMappings"))
            enabled.state = controller.isEnabled ? .on : .off
            enabled.target = controller
            item.submenu?.addItem(enabled)

            // 断开连接菜单项
            let disconnect = NSMenuItem()
            disconnect.title = NSLocalizedString("Disconnect", comment: "Disconnect")
            disconnect.action = Selector(("disconnect"))
            disconnect.target = controller
            item.submenu?.addItem(disconnect)
            
            // 分隔线
            item.submenu?.addItem(NSMenuItem.separator())

            // 电池信息
            let battery = NSMenuItem()
            if controller.controller?.battery ?? .unknown != .unknown {
                var chargeString = ""
                if controller.controller?.isCharging ?? false {
                    let charging = NSLocalizedString("charging", comment: "charging")
                    chargeString = " (\(charging))"
                }
                let batteryString = NSLocalizedString("Battery", comment: "Battery")
                battery.title = "\(batteryString): \(controller.localizedBatteryString)\(chargeString)"
            }
            battery.isEnabled = false
            item.submenu?.addItem(battery)
            
            self.controllersMenu?.submenu?.addItem(item)
        }
        
        // 如果没有连接的控制器，显示提示信息
        if let itemCount = self.controllersMenu?.submenu?.items.count, itemCount <= 0 {
            let item = NSMenuItem()
            let noControllers = NSLocalizedString("No controllers connected", comment: "No controllers connected")
            item.title = "(\(noControllers))"
            item.isEnabled = false
            self.controllersMenu?.submenu?.addItem(item)
        }
    }
    
    // MARK: - 辅助应用程序设置
    
    // 设置登录项
    func setLoginItem(enabled: Bool) {
        let succeeded = SMLoginItemSetEnabled(helperAppID, enabled)
        if (!succeeded) {
            // 处理设置失败的情况
        }
    }
    
    // MARK: - NSWindowDelegate
    
    // 窗口关闭时保存数据
    func windowWillClose(_ notification: Notification) {
        _ = self.dataManager?.save()
    }
    
    // MARK: - 通知处理
    
    // 控制器图标变更通知处理
    @objc func controllerIconChanged(_ notification: NSNotification) {
        self.updateControllersMenu()
    }
    
    // MARK: - UNUserNotificationCenterDelegate

    // 处理通知展示
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }
    
    // 处理通知响应
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    // MARK: - 控制器事件处理

    // 应用程序终止时断开所有控制器
    func applicationWillTerminate(_ aNotification: Notification) {
        self.controllers.forEach { controller in
            controller.controller?.setHCIState(state: .disconnect)
        }
    }
    
    // 连接控制器
    func connectController(_ controller: JoyConSwift.Controller) {
        if let gameController = self.controllers.first(where: {
            $0.data.serialID == controller.serialID
        }) {
            gameController.controller = controller
            gameController.startTimer()
            NotificationCenter.default.post(name: .controllerConnected, object: gameController)

            AppNotifications.notifyControllerConnected(gameController)
        } else {
            self.addController(controller)
        }
        self.updateControllersMenu()
    }

    // 断开控制器连接（菜单操作）
    @objc func disconnectController(sender: Any) {
        guard let item = sender as? NSMenuItem else { return }
        guard let gameController = item.representedObject as? GameController else { return }
        
        gameController.disconnect()
        self.updateControllersMenu()
    }
    
    // 断开控制器连接
    func disconnectController(_ controller: JoyConSwift.Controller) {
        if let gameController = self.controllers.first(where: {
            $0.data.serialID == controller.serialID
        }) {
            gameController.controller = nil
            gameController.updateControllerIcon()
            NotificationCenter.default.post(name: .controllerDisconnected, object: gameController)
            
            AppNotifications.notifyControllerDisconnected(gameController)
        }
        self.updateControllersMenu()
    }

    // 添加新控制器
    func addController(_ controller: JoyConSwift.Controller) {
        guard let dataManager = self.dataManager else { return }
        let controllerData = dataManager.getControllerData(controller: controller)
        let gameController = GameController(data: controllerData, dataManager: self.dataManager!)
        gameController.controller = controller
        gameController.startTimer()
        self.controllers.append(gameController)
        
        NotificationCenter.default.post(name: .controllerAdded, object: gameController)
        
        AppNotifications.notifyControllerConnected(gameController)
    }
    
    // 移除控制器
    func removeController(_ controller: JoyConSwift.Controller) {
        guard let gameController = self.controllers.first(where: {
            $0.data.serialID == controller.serialID
        }) else { return }
        self.removeController(gameController: gameController)
    }
    
    // 移除游戏控制器
    func removeController(gameController controller: GameController) {
        controller.controller?.setHCIState(state: .disconnect)

        self.dataManager?.delete(controller.data)
        self.controllers.removeAll(where: { $0 === controller })
        NotificationCenter.default.post(name: .controllerRemoved, object: controller)
    }

    // MARK: - Core Data 保存和撤销支持

    // 保存操作
    @IBAction func saveAction(_ sender: AnyObject?) {
        _ = self.dataManager?.save()
    }

    // 获取撤销管理器
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        return self.dataManager?.undoManager
    }

    // 关闭最后一个窗口时不退出应用
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // 应用程序退出前的处理
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let isSucceeded = self.dataManager?.save() ?? false
        
        if !isSucceeded {
            // 如果保存失败，询问用户是否仍要退出
            let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
            let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info");
            let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
            let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
            let alert = NSAlert()
            alert.messageText = question
            alert.informativeText = info
            alert.addButton(withTitle: quitButton)
            alert.addButton(withTitle: cancelButton)
            
            let answer = alert.runModal()
            if answer == .alertSecondButtonReturn {
                return .terminateCancel
            }
        }
        
        return .terminateNow
    }
    
    // MARK: - 上下文切换处理
    
    // 处理应用程序激活事件
    @objc func didActivateApp(notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            let bundleID = app.bundleIdentifier else { return }
        
        resetMetaKeyState()
        
        self.controllers.forEach { controller in
            controller.switchApp(bundleID: bundleID)
        }
    }
}