//
//  MemoryBoxApp.swift
//  MemoryBox
//
//  Created by QuanDX1 on 17/7/26.
//

import SwiftUI

@main
struct MemoryBoxApp: App {
    @UIApplicationDelegateAdaptor(MemoryBoxAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
