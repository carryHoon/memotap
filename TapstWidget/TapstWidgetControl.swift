//
//  TapstWidgetControl.swift
//  TapstWidget
//
//  A control for Control Center / the Lock Screen. Tapping it runs
//  AddTaskIntent (input prompt) without opening the app.
//

import AppIntents
import SwiftUI
import WidgetKit

struct TapstWidgetControl: ControlWidget {
    static let kind: String = "com.carryHoon.Tapst.AddControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: AddTaskIntent()) {
                Label("할 일 추가", systemImage: "plus.circle")
            }
        }
        .displayName("Tapst 추가")
        .description("앱을 열지 않고 할 일을 추가합니다.")
    }
}
