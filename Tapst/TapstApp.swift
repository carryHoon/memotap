//
//  TapstApp.swift
//  Tapst
//
//  Created by MacH on 9/10/26.
//

import SwiftUI

@main
struct TapstApp: App {
    init() { TapstFonts.registerIfNeeded() }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
