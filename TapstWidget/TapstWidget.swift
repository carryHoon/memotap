//
//  TapstWidget.swift
//  TapstWidget
//
//  Lock Screen / Home Screen widget that acts as a tap entry point:
//  tapping it runs AddTaskIntent (input prompt) without opening the app.
//

import WidgetKit
import SwiftUI
import AppIntents

struct TapstEntry: TimelineEntry {
    let date: Date
    let count: Int
}

struct TapstProvider: TimelineProvider {
    func placeholder(in context: Context) -> TapstEntry {
        TapstEntry(date: Date(), count: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (TapstEntry) -> Void) {
        completion(TapstEntry(date: Date(), count: TapstStorage.load().count))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TapstEntry>) -> Void) {
        let entry = TapstEntry(date: Date(), count: TapstStorage.load().count)
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
}

struct TapstWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: TapstProvider.Entry

    var body: some View {
        // The whole widget is a single tap target that adds a task.
        Button(intent: AddTaskIntent()) {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                }
            case .accessoryRectangular:
                HStack(spacing: 6) {
                    Image(systemName: "checklist")
                    Text(entry.count > 0 ? "할 일 \(entry.count)개 · 탭해서 추가" : "탭해서 할 일 추가")
                        .lineLimit(2)
                }
            default:
                VStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.largeTitle)
                    Text("할 일 추가")
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct TapstWidget: Widget {
    let kind: String = "TapstWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TapstProvider()) { entry in
            TapstWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tapst 빠른 추가")
        .description("탭하면 앱을 열지 않고 할 일을 추가합니다.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}

#Preview(as: .accessoryRectangular) {
    TapstWidget()
} timeline: {
    TapstEntry(date: .now, count: 2)
}
