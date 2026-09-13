//
//  TapstWidgetBundle.swift
//  TapstWidget
//
//  Created by MacH on 9/10/26.
//

import WidgetKit
import SwiftUI

@main
struct TapstWidgetBundle: WidgetBundle {
    init() { TapstFonts.registerIfNeeded() }

    var body: some Widget {
        TapstWidget()
        TapstWidgetControl()
        TapstWidgetLiveActivity()
    }
}
