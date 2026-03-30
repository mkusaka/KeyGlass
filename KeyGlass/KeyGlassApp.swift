//
//  KeyGlassApp.swift
//  KeyGlass
//
//  Created by Masatomo Kusaka on 2026/03/31.
//

import SwiftUI

@main
struct KeyGlassApp: App {
    @NSApplicationDelegateAdaptor(KeyGlassAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
