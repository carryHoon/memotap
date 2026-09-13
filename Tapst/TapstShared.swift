//
//  TapstShared.swift
//  Tapst
//
//  Shared between the app and the widget extension.
//  IMPORTANT: this file MUST be a member of BOTH targets
//  (Tapst and TapstWidgetExtension). Select it in Xcode and check both
//  in File Inspector ▸ Target Membership.
//

import Foundation
import AppIntents
import ActivityKit
import SwiftUI
import CoreText

// MARK: - Bundled Korean fonts (OFL, commercial-use OK)

/// Registers the bundled Pro fonts in the current process (app or widget).
enum TapstFonts {
    /// (fileName, Font.custom PostScript name, picker label)
    static let all: [(file: String, psName: String, label: String)] = [
        ("NanumMyeongjo-Regular", "NanumMyeongjo", "명조"),
        ("Jua-Regular", "Jua-Regular", "둥근"),
        ("NanumPenScript-Regular", "NanumPen-Regular", "손글씨"),
        ("DoHyeon-Regular", "DoHyeon-Regular", "진한고딕")
    ]

    private static var registered = false

    static func registerIfNeeded() {
        guard !registered else { return }
        registered = true
        for font in all {
            if let url = Bundle.main.url(forResource: font.file, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}

// MARK: - Design kit (shared with the widget)

/// MemoTap's own palette + font mapping (generic controls, MemoTap styling).
enum TapstDesignKit {
    /// Theme colors offered to Pro. "graphite" is the free default (dark glass).
    static let colors: [(id: String, color: Color)] = [
        ("graphite", Color(white: 0.14)),
        ("blue",     Color(red: 0.30, green: 0.55, blue: 0.98)),
        ("indigo",   Color(red: 0.35, green: 0.36, blue: 0.86)),
        ("purple",   Color(red: 0.55, green: 0.35, blue: 0.85)),
        ("pink",     Color(red: 0.94, green: 0.40, blue: 0.62)),
        ("red",      Color(red: 0.88, green: 0.36, blue: 0.36)),
        ("orange",   Color(red: 0.95, green: 0.55, blue: 0.25)),
        ("brown",    Color(red: 0.60, green: 0.45, blue: 0.33)),
        ("green",    Color(red: 0.30, green: 0.70, blue: 0.45)),
        ("teal",     Color(red: 0.25, green: 0.63, blue: 0.66)),
        ("mint",     Color(red: 0.35, green: 0.78, blue: 0.66)),
        ("slate",    Color(red: 0.40, green: 0.45, blue: 0.55))
    ]

    static func color(_ id: String) -> Color {
        colors.first { $0.id == id }?.color ?? colors[0].color
    }

    /// Text colors offered to Pro (white/black + the accent palette).
    static let textColors: [(id: String, color: Color)] =
        [("white", .white), ("black", Color(white: 0.1))] + colors.filter { $0.id != "graphite" }

    static func textColor(_ id: String) -> Color {
        textColors.first { $0.id == id }?.color ?? .white
    }

    /// Resolves the memo font. "default" uses the system font (full weight
    /// range); the others are bundled Korean fonts (Pro).
    static func memoFont(_ raw: String, size: CGFloat, bold: Bool) -> Font {
        switch raw {
        case "myeongjo": return .custom("NanumMyeongjo", size: size).weight(bold ? .bold : .regular)
        case "jua":      return .custom("Jua-Regular", size: size)
        case "pen":      return .custom("NanumPen-Regular", size: size)
        case "dohyeon":  return .custom("DoHyeon-Regular", size: size)
        default:         return .system(size: size, weight: bold ? .black : .semibold)
        }
    }
}

// MARK: - Model

/// A single Tapst task entered by the user.
struct TapstTask: Identifiable, Codable, Hashable {
    let id: UUID
    var text: String
    let createdAt: Date

    init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

// MARK: - Live Activity attributes

/// Attributes for the Lock Screen checklist Live Activity.
struct TapstActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var tasks: [TapstTask]
        // Appearance travels with the content so any change forces a re-render.
        var themeColorID: String = "graphite"
        var textColorID: String = "white"
        var fontDesignRaw: String = "default"
        var fontBold: Bool = false
        var textScale: Double = 1.0
        var limit: Int = 5
        var hideDynamicIsland: Bool = false
    }
}

extension TapstActivityAttributes.ContentState {
    /// Builds state from the current tasks + saved appearance settings.
    static func current(tasks: [TapstTask]) -> Self {
        .init(
            tasks: tasks,
            themeColorID: TapstStorage.themeColorID,
            textColorID: TapstStorage.textColorID,
            fontDesignRaw: TapstStorage.fontDesignRaw,
            fontBold: TapstStorage.fontBold,
            textScale: TapstStorage.textScale,
            limit: TapstStorage.lockScreenLimit,
            hideDynamicIsland: TapstStorage.hideDynamicIsland
        )
    }
}

// MARK: - Shared storage

/// Reads/writes the task list to storage shared between the app and the widget.
enum TapstStorage {
    /// Must match the App Group added to BOTH targets in Signing & Capabilities.
    static let appGroupID = "group.com.carryHoon.Tapst"
    private static let key = "tapst.tasks"

    // Single instance — computed property caused different UserDefaults objects
    // to be created on each access, which could miss in-progress writes.
    static let defaults: UserDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

    static func load() -> [TapstTask] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TapstTask].self, from: data) else {
            return []
        }
        return decoded
    }

    static func save(_ tasks: [TapstTask]) {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        defaults.set(data, forKey: key)
    }

    /// Basic can keep up to 3 memos; Pro is unlimited.
    static var maxMemos: Int { isPro ? Int.max : 3 }
    static func canAddMore() -> Bool { load().count < maxMemos }

    @discardableResult
    static func add(_ text: String) -> [TapstTask] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var tasks = load()
        guard !trimmed.isEmpty, tasks.count < maxMemos else { return tasks }
        tasks.append(TapstTask(text: trimmed))
        save(tasks)
        return tasks
    }

    @discardableResult
    static func remove(id: String) -> [TapstTask] {
        var tasks = load()
        tasks.removeAll { $0.id.uuidString == id }
        save(tasks)
        return tasks
    }

    /// MemoTap Pro entitlement, shared with the widget.
    static var isPro: Bool {
        get { defaults.bool(forKey: "tapst.isPro") }
        set { defaults.set(newValue, forKey: "tapst.isPro") }
    }

    /// Rows drawn on the Lock Screen card before the "+N" badge.
    static var lockScreenLimit: Int { isPro ? 6 : 3 }

    // MARK: Appearance (Basic: text size / Pro: color + font)

    /// Lock Screen card text/check scale. Available to everyone (Basic).
    static var textScale: Double {
        get {
            let v = defaults.double(forKey: "tapst.textScale")
            return v == 0 ? 1.0 : v
        }
        set { defaults.set(min(1.25, max(0.85, newValue)), forKey: "tapst.textScale") }
    }

    /// Theme (card) color id (Pro). Defaults to the free "graphite".
    static var themeColorID: String {
        get { defaults.string(forKey: "tapst.themeColor") ?? "graphite" }
        set { defaults.set(newValue, forKey: "tapst.themeColor") }
    }

    /// Text color id (Pro). Defaults to "white".
    static var textColorID: String {
        get { defaults.string(forKey: "tapst.textColor") ?? "white" }
        set { defaults.set(newValue, forKey: "tapst.textColor") }
    }

    /// Font design raw value: default/rounded/serif/mono (Pro).
    static var fontDesignRaw: String {
        get { defaults.string(forKey: "tapst.fontDesign") ?? "default" }
        set { defaults.set(newValue, forKey: "tapst.fontDesign") }
    }

    /// Bold vs semibold memo text (Pro).
    static var fontBold: Bool {
        get { defaults.object(forKey: "tapst.fontBold") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "tapst.fontBold") }
    }

    // MARK: Convenience (Basic — free)

    /// Hides custom content in the Dynamic Island compact/minimal presentation.
    static var hideDynamicIsland: Bool {
        get { defaults.object(forKey: "tapst.hideDynamicIsland") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "tapst.hideDynamicIsland") }
    }

    /// Ends the Live Activity automatically when the task list becomes empty.
    static var hideWhenEmpty: Bool {
        get { defaults.object(forKey: "tapst.hideWhenEmpty") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "tapst.hideWhenEmpty") }
    }
}

// MARK: - Live Activity manager

/// Starts, updates, or ends the Lock Screen checklist Live Activity so it always
/// mirrors the current task list.
enum TapstLiveActivity {
    /// Async so callers can `await` the ActivityKit work. Background App Intents
    /// must await this — otherwise the process can be suspended before the
    /// Lock Screen update lands.
    /// Keeps the Lock Screen card in sync. The card stays alive even with zero
    /// tasks so that background adds (Back Tap) always have an activity to
    /// update — starting a fresh one only works from the foreground.
    static func refresh() async {
        let tasks = TapstStorage.load()
        let activities = Activity<TapstActivityAttributes>.activities
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled

        // '할 일이 없으면 숨기기' — end the Live Activity immediately when empty.
        if tasks.isEmpty && TapstStorage.hideWhenEmpty {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        let content = ActivityContent(
            state: TapstActivityAttributes.ContentState.current(tasks: tasks),
            staleDate: nil
        )

        if let existing = activities.first {
            await existing.update(content)
        } else {
            guard enabled else { return }
            do {
                let _ = try Activity.request(
                    attributes: TapstActivityAttributes(),
                    content: content
                )
            } catch {
                print("TAPST_LA: request failed: \(error)")
            }
        }
    }
}

// MARK: - Intents

/// Captures a task without opening the app. Bound to Back Tap, the Lock Screen
/// widget, and the Control Center / Lock Screen control.
struct AddTaskIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Add memo"
    static var description = IntentDescription("Adds a memo and shows it on the Lock Screen.")

    /// LiveActivityIntent + background run: this is what lets it START the Live
    /// Activity from the Lock Screen without opening the app. The `text` is
    /// supplied by the Shortcut's "Ask for Input" action (that's the keyboard),
    /// exactly like 툭.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Task")
    var text: String

    init() {}
    init(text: String) { self.text = text }

    func perform() async throws -> some IntentResult {
        print("TAPST_LA: AddTaskIntent text=\"\(text)\"")
        TapstStorage.add(text)
        await TapstLiveActivity.refresh()
        return .result()
    }
}

/// Marks a task complete (removes it) when the user taps its circle on the
/// Lock Screen Live Activity.
struct CompleteTaskIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Tapst Task"

    /// Runs in the background so tapping the circle just makes the row vanish.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}
    init(taskID: String) { self.taskID = taskID }

    func perform() async throws -> some IntentResult {
        print("TAPST_LA: complete tap id=\(taskID)")
        TapstStorage.remove(id: taskID)
        await TapstLiveActivity.refresh()
        return .result()
    }
}
