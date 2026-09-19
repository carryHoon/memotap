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

    /// Completion-mark shapes for the Lock Screen card (hollow SF Symbols so any
    /// shape keeps the original outlined look). Free for everyone (Basic).
    static let markShapes: [(id: String, symbol: String, label: String)] = [
        ("circle",  "circle",     "동그라미"),
        ("square",  "square",     "네모"),
        ("star",    "star",       "별"),
        ("diamond", "diamond",    "마름모"),
        ("heart",   "suit.heart", "하트")
    ]

    /// SF Symbol name for a mark shape id (falls back to the circle).
    static func markSymbol(_ id: String) -> String {
        markShapes.first { $0.id == id }?.symbol ?? "circle"
    }
}

// MARK: - Timetable time formatting (shared with the widget)

/// Zero-padded 24-hour "HH:mm" used for the timetable's fixed time column in both
/// the app and the Lock Screen card, so the time/text split looks consistent.
func tapstTimeString(hour: Int, minute: Int) -> String {
    String(format: "%02d:%02d", hour, minute)
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

/// A single timetable entry: what to do and at what time of day (Pro feature).
/// Completely independent from `TapstTask` — a different workflow/store.
struct TapstScheduleItem: Identifiable, Codable, Hashable {
    let id: UUID
    var text: String
    var hour: Int    // 0...23
    var minute: Int  // 0...59
    var weekday: Int // 1=Sun ... 7=Sat (matches Calendar.component(.weekday))
    let createdAt: Date // used to resolve a non-recurring item's single occurrence

    init(id: UUID = UUID(), text: String, hour: Int, minute: Int, weekday: Int, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.hour = hour
        self.minute = minute
        self.weekday = weekday
        self.createdAt = createdAt
    }

    // Tolerant decode: items saved before these fields existed default gracefully
    // instead of dropping the whole saved list.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        hour = try c.decode(Int.self, forKey: .hour)
        minute = try c.decode(Int.self, forKey: .minute)
        weekday = try c.decodeIfPresent(Int.self, forKey: .weekday) ?? 2
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    /// Minutes since midnight — used for chronological sorting.
    var minutesOfDay: Int { hour * 60 + minute }
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
        // Completion-mark size (independent of text) and shape. Free (Basic).
        var markScale: Double = 1.0
        var markShapeRaw: String = "circle"
        var limit: Int = 5
        var hideDynamicIsland: Bool = false
        // Which card the Lock Screen shows: "tasks" (default, free) or "schedule"
        // (Pro timetable). Additive with defaults so existing behavior is unchanged.
        var mode: String = "tasks"
        // Full timetable (all weekdays) + which weekdays are enabled for the Lock
        // Screen. The widget filters by *today's* weekday so it flips at midnight.
        var schedule: [TapstScheduleItem] = []
        var scheduleWeekdays: [Int] = []
        // Transient: task ids currently showing the "completed" checkmark just
        // before they're removed, so tapping a row gives a visible "done" beat.
        var completingIDs: [String] = []
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
            markScale: TapstStorage.markScale,
            markShapeRaw: TapstStorage.markShapeRaw,
            limit: TapstStorage.lockScreenLimit,
            hideDynamicIsland: TapstStorage.hideDynamicIsland,
            mode: TapstStorage.lockScreenCardMode,
            schedule: TapstStorage.loadSchedule(),
            scheduleWeekdays: TapstStorage.scheduleWeekdays
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

    /// Edits an existing memo's text (in-app tap-to-edit). Empty text is ignored.
    @discardableResult
    static func updateText(id: String, text: String) -> [TapstTask] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var tasks = load()
        guard !trimmed.isEmpty, let i = tasks.firstIndex(where: { $0.id.uuidString == id }) else { return tasks }
        tasks[i].text = trimmed
        save(tasks)
        return tasks
    }

    // MARK: Timetable (schedule) — independent store, Pro-only

    private static let scheduleKey = "tapst.schedule"

    /// Max timetable rows PER WEEKDAY kept legible on the Lock Screen. Announced
    /// to users as the cap.
    static let maxScheduleItems = 5

    private static let scheduleWeekdaysKey = "tapst.scheduleWeekdays"

    static func loadSchedule() -> [TapstScheduleItem] {
        guard let data = defaults.data(forKey: scheduleKey),
              let decoded = try? JSONDecoder().decode([TapstScheduleItem].self, from: data) else {
            return []
        }
        return decoded
    }

    static func saveSchedule(_ items: [TapstScheduleItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: scheduleKey)
    }

    static func scheduleItems(weekday: Int) -> [TapstScheduleItem] {
        loadSchedule().filter { $0.weekday == weekday }.sorted { $0.minutesOfDay < $1.minutesOfDay }
    }

    static func canAddSchedule(weekday: Int) -> Bool {
        loadSchedule().filter { $0.weekday == weekday }.count < maxScheduleItems
    }

    @discardableResult
    static func addSchedule(text: String, hour: Int, minute: Int, weekday: Int) -> [TapstScheduleItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var items = loadSchedule()
        let dayCount = items.filter { $0.weekday == weekday }.count
        guard !trimmed.isEmpty, dayCount < maxScheduleItems else { return items }
        items.append(TapstScheduleItem(text: trimmed, hour: hour, minute: minute, weekday: weekday))
        saveSchedule(items)
        return items
    }

    /// Weekdays (1=Sun...7=Sat) enabled to show their timetable on the Lock Screen.
    static var scheduleWeekdays: [Int] {
        get { (defaults.array(forKey: scheduleWeekdaysKey) as? [Int]) ?? [] }
        set { defaults.set(newValue.sorted(), forKey: scheduleWeekdaysKey) }
    }

    /// The calendar day a non-recurring item is meant for: the first occurrence of
    /// its weekday on or after it was created.
    static func scheduledOccurrence(for item: TapstScheduleItem) -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: item.createdAt)
        let cur = cal.component(.weekday, from: start)
        let delta = (item.weekday - cur + 7) % 7
        return cal.date(byAdding: .day, value: delta, to: start) ?? start
    }

    /// Rows shown on the Lock Screen *today*, from an explicit list (used by the
    /// widget with ContentState). Recurring weekdays (toggle ON) always show; a
    /// non-recurring (toggle OFF) item shows only on its own single occurrence day.
    static func lockScreenScheduleItems(from all: [TapstScheduleItem],
                                        enabled: [Int],
                                        now: Date = Date()) -> [TapstScheduleItem] {
        let cal = Calendar.current
        let today = cal.component(.weekday, from: now)
        let recurringToday = enabled.contains(today)
        return all
            .filter { item in
                guard item.weekday == today else { return false }
                if recurringToday { return true }
                return cal.isDate(scheduledOccurrence(for: item), inSameDayAs: now)
            }
            .sorted { $0.minutesOfDay < $1.minutesOfDay }
    }

    /// Storage-backed convenience (app side).
    static func lockScreenScheduleItems(now: Date = Date()) -> [TapstScheduleItem] {
        lockScreenScheduleItems(from: loadSchedule(), enabled: scheduleWeekdays, now: now)
    }

    /// Removes non-recurring (toggle OFF) items whose single occurrence day has
    /// passed. Called from the app; recurring items are never purged.
    @discardableResult
    static func purgeExpiredSchedule(now: Date = Date()) -> [TapstScheduleItem] {
        let cal = Calendar.current
        let enabled = Set(scheduleWeekdays)
        var items = loadSchedule()
        let before = items.count
        items.removeAll { item in
            guard !enabled.contains(item.weekday) else { return false } // recurring stays
            return cal.startOfDay(for: now) > scheduledOccurrence(for: item)
        }
        if items.count != before { saveSchedule(items) }
        return items
    }

    @discardableResult
    static func removeSchedule(id: String) -> [TapstScheduleItem] {
        var items = loadSchedule()
        items.removeAll { $0.id.uuidString == id }
        saveSchedule(items)
        return items
    }

    /// Edits an existing timetable item's text and/or time (in-app tap-to-edit).
    @discardableResult
    static func updateSchedule(id: String, text: String? = nil, hour: Int? = nil, minute: Int? = nil) -> [TapstScheduleItem] {
        var items = loadSchedule()
        guard let i = items.firstIndex(where: { $0.id.uuidString == id }) else { return items }
        if let text {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { items[i].text = trimmed }
        }
        if let hour { items[i].hour = hour }
        if let minute { items[i].minute = minute }
        saveSchedule(items)
        return items
    }

    /// MemoTap Pro entitlement, shared with the widget.
    static var isPro: Bool {
        get { defaults.bool(forKey: "tapst.isPro") }
        set { defaults.set(newValue, forKey: "tapst.isPro") }
    }

    /// Rows drawn on the Lock Screen card before the "+N" badge.
    static var lockScreenLimit: Int { isPro ? 6 : 3 }

    // MARK: Appearance (Basic: text size / Pro: color + font)

    /// Lock Screen card text scale (text only). Available to everyone (Basic).
    static var textScale: Double {
        get {
            let v = defaults.double(forKey: "tapst.textScale")
            return v == 0 ? 1.0 : v
        }
        set { defaults.set(min(1.25, max(0.85, newValue)), forKey: "tapst.textScale") }
    }

    /// Lock Screen completion-mark scale, independent of text size. Free (Basic).
    static var markScale: Double {
        get {
            let v = defaults.double(forKey: "tapst.markScale")
            return v == 0 ? 1.0 : v
        }
        set { defaults.set(min(1.5, max(0.5, newValue)), forKey: "tapst.markScale") }
    }

    /// Lock Screen completion-mark shape id (see TapstDesignKit.markShapes). Free.
    static var markShapeRaw: String {
        get { defaults.string(forKey: "tapst.markShape") ?? "circle" }
        set { defaults.set(newValue, forKey: "tapst.markShape") }
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

    /// Which card the Lock Screen shows: "tasks" (default, free) or "schedule"
    /// (Pro timetable). Falls back to "tasks" if the user isn't Pro.
    static var lockScreenCardMode: String {
        get {
            let raw = defaults.string(forKey: "tapst.cardMode") ?? "tasks"
            return (raw == "schedule" && isPro) ? "schedule" : "tasks"
        }
        set { defaults.set(newValue, forKey: "tapst.cardMode") }
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

        // The active card decides what "empty" means (tasks vs today's timetable).
        let isEmpty = TapstStorage.lockScreenCardMode == "schedule"
            ? TapstStorage.lockScreenScheduleItems().isEmpty
            : tasks.isEmpty

        // '할 일이 없으면 숨기기' — end the Live Activity immediately when empty.
        if isEmpty && TapstStorage.hideWhenEmpty {
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

    /// Fast path for background adds (Back Tap / shortcut / control): updates the
    /// existing card only. It never attempts `Activity.request`, which stalls or
    /// fails from the background — that stall is what makes the system's shortcut
    /// "running" (⏹) indicator linger. Returns almost instantly so the indicator
    /// just flashes and the user can trigger the next capture right away.
    /// The foreground app keeps a card alive (see `refresh()`), so one normally
    /// exists; if it doesn't, the memo is still saved and appears on next launch.
    static func updateExisting() async {
        guard let activity = Activity<TapstActivityAttributes>.activities.first else { return }
        let content = ActivityContent(
            state: TapstActivityAttributes.ContentState.current(tasks: TapstStorage.load()),
            staleDate: nil
        )
        await activity.update(content)
    }

    /// Flashes a checkmark on a single task's mark (without removing it yet) to
    /// give a "done" beat before `CompleteTaskIntent` deletes it.
    static func showCompleting(id: String) async {
        guard let activity = Activity<TapstActivityAttributes>.activities.first else { return }
        var state = TapstActivityAttributes.ContentState.current(tasks: TapstStorage.load())
        state.completingIDs = [id]
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }
}

// MARK: - Intents

/// Captures a task without opening the app. Bound to Back Tap, the Lock Screen
/// widget, and the Control Center / Lock Screen control.
struct AddTaskIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "memotap"
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
        // Fast update-only path keeps the shortcut run indicator brief.
        await TapstLiveActivity.updateExisting()
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
        // 1) Flash a checkmark in the mark, 2) brief beat, 3) remove + refresh.
        await TapstLiveActivity.showCompleting(id: taskID)
        try? await Task.sleep(for: .milliseconds(450))
        TapstStorage.remove(id: taskID)
        await TapstLiveActivity.refresh()
        return .result()
    }
}
