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

    init() {
        MemoryLog.bootstrap("MemoryBoxApp init")
        // Welcome chưa chọn option → không mở CloudKit.
        // Đã complete / session dở → bootstrap ngay.
        PersistenceController.bootstrapForAppLaunchIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootCoordinatorView()
                .modifier(PersistenceContextModifier())
        }
    }
}

private struct PersistenceContextModifier: ViewModifier {
    func body(content: Content) -> some View {
        if PersistenceController.isBootstrapped {
            content.environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        } else {
            content
        }
    }
}
