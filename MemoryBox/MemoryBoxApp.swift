//
//  MemoryBoxApp.swift
//  MemoryBox
//
//  Created by QuanDX1 on 17/7/26.
//

import CoreData
import SwiftUI

@main
struct MemoryBoxApp: App {
    @UIApplicationDelegateAdaptor(MemoryBoxAppDelegate.self) private var appDelegate
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}
