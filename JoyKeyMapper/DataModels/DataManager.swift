//
//  DataManager.swift
//  JoyKeyMapper
//
//  Created by magicien on 2019/07/14.
//  Copyright © 2019 DarkHorse. All rights reserved.
//

import CoreData
import JoyConSwift

// 定义摇杆类型
enum StickType: String {
    case Mouse = "Mouse"
    case MouseWheel = "Mouse Wheel"
    case Key = "Key"
    case None = "None"
}

// 定义摇杆方向
enum StickDirection: String {
    case Left = "Left"
    case Right = "Right"
    case Up = "Up"
    case Down = "Down"
}

class DataManager: NSObject {
    let container: NSPersistentContainer

    // 获取撤销管理器
    var undoManager: UndoManager? {
        return self.container.viewContext.undoManager
    }
    
    // 获取所有控制器数据
    var controllers: [ControllerData] {
        let context = self.container.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "ControllerData")
        
        do {
            let result = try context.fetch(request) as! [ControllerData]
            return result
        } catch {
            fatalError("Failed to fetch ControllerData: \(error)")
        }
    }
    
    // 初始化数据管理器
    init(completion: @escaping (DataManager?) -> Void) {
        self.container = NSPersistentContainer(name: "JoyKeyMapper")
        super.init()
        
        self.container.loadPersistentStores { [weak self] (storeDescription, error) in
            if let error = error {
                // 处理错误
                fatalError("Unresolved error \(error)")
            }
            self?.container.viewContext.automaticallyMergesChangesFromParent = true
            self?.container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            
            completion(self)
        }
    }
    
    // 保存数据
    func save() -> Bool {
        let context = self.container.viewContext
         
        if !context.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing before saving")
            return false
        }
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Customize this code block to include application-specific recovery steps.
                let nserror = error as NSError
                NSApplication.shared.presentError(nserror)

                return false
            }
        }
        
        return true
    }
    
    // MARK: - Import/Export data
    
    func createContext(for url: URL) -> NSManagedObjectContext? {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.container.managedObjectModel)
        do {
            // TODO: Set options
            try coordinator.addPersistentStore(ofType: NSBinaryStoreType, configurationName: nil, at: url, options: nil)
        } catch {
            let nserror = error as NSError
            NSApplication.shared.presentError(nserror)

            return nil
        }

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        
        return context
    }
    
    func saveData(object: NSManagedObject, to url: URL) -> Bool {
        guard let context = self.createContext(for: url) else { return false }
        
        context.insert(object)
        if !context.commitEditing() {
            return false
        }
        
        do {
            try context.save()
        } catch {
            // Customize this code block to include application-specific recovery steps.
            let nserror = error as NSError
            NSApplication.shared.presentError(nserror)

            return false
        }
        
        return true
    }
    
    func loadData<T: NSManagedObject>(from url: URL) -> [T]? {
        guard let context = self.createContext(for: url) else { return nil }
        guard let entityName = T.entity().name else { return nil }
        
        let request = NSFetchRequest<T>(entityName: entityName)
        do {
            return try context.fetch(request)
        } catch {
            let nserror = error as NSError
            NSApplication.shared.presentError(nserror)
        }

        return nil
    }

    // MARK: - 创建各种数据对象的方法

    // 创建控制器数据
    func createControllerData(type: JoyCon.ControllerType) -> ControllerData {
        let controller = ControllerData(context: self.container.viewContext)
        controller.appConfigs = []
        controller.defaultConfig = self.createKeyConfig(type: type)
        
        return controller
    }
    
    func getControllerData(controller: JoyConSwift.Controller) -> ControllerData {
        let serialID = controller.serialID
        let context = self.container.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "ControllerData")
        request.predicate = NSPredicate(format: "serialID == %@", serialID)

        do {
            let result = try context.fetch(request) as! [ControllerData]
            if result.count > 0 {
                return result[0]
            }
        } catch {
            fatalError("Failed to fetch ControllerData: \(error)")
        }

        let controller = self.createControllerData(type: controller.type)
        controller.serialID = serialID
        
        return controller
    }
    
    // 创建应用程序配置
    func createAppConfig(type: JoyCon.ControllerType) -> AppConfig {
        let appConfig = AppConfig(context: self.container.viewContext)
        appConfig.app = self.createAppData()
        appConfig.config = self.createKeyConfig(type: type)

        return appConfig
    }

    // 创建应用程序数据
    func createAppData() -> AppData {
        let appData = AppData(context: self.container.viewContext)
        return appData
    }

    // 创建按键配置
    func createKeyConfig(type: JoyCon.ControllerType) -> KeyConfig {
        let keyConfig = KeyConfig(context: self.container.viewContext)
        
        if type == .JoyConL || type == .ProController {
            keyConfig.leftStick = self.createStickConfig()
        }
        if type == .JoyConR || type == .ProController {
            keyConfig.rightStick = self.createStickConfig()
        }
        
        keyConfig.keyMaps = []
        
        return keyConfig
    }

    // 创建按键映射
    func createKeyMap() -> KeyMap {
        let keyMap = KeyMap(context: self.container.viewContext)
        return keyMap
    }
    
    // 创建摇杆配置
    func createStickConfig() -> StickConfig {
        let stickConfig = StickConfig(context: self.container.viewContext)

        stickConfig.speed = 10.0
        stickConfig.type = StickType.None.rawValue

        let left = self.createKeyMap()
        left.button = StickDirection.Left.rawValue
        stickConfig.addToKeyMaps(left)

        let right = self.createKeyMap()
        right.button = StickDirection.Right.rawValue
        stickConfig.addToKeyMaps(right)

        let up = self.createKeyMap()
        up.button = StickDirection.Up.rawValue
        stickConfig.addToKeyMaps(up)

        let down = self.createKeyMap()
        down.button = StickDirection.Down.rawValue
        stickConfig.addToKeyMaps(down)
        
        return stickConfig
    }
    
    // MARK: - 通用方法
    
    // 删除托管对象
    func delete(_ object: NSManagedObject) {
        self.container.viewContext.delete(object)
    }
}
