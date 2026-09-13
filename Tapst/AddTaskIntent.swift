//
//  AddTaskIntent.swift
//  Tapst
//
//  Exposes AddTaskIntent (defined in TapstShared.swift) to the Shortcuts app
//  so the user can assign it to Back Tap.
//

import AppIntents

/// App Shortcut provider. Must live in the main app target.
struct TapstShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "\(.applicationName)에 추가",
                "Add to \(.applicationName)"
            ],
            shortTitle: "할 일 추가",
            systemImageName: "plus.circle"
        )
    }
}
