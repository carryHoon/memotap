//
//  ScheduleStore.swift
//  Tapst (MemoTap)
//
//  App-side observable wrapper over the shared timetable storage. Independent
//  from TaskStore — the timetable is a separate Pro workflow.
//

import Foundation

@Observable
final class ScheduleStore {
    static let shared = ScheduleStore()

    private(set) var items: [TapstScheduleItem] = []

    private init() { reload() }

    /// Re-reads the timetable from shared storage, kept in chronological order.
    /// Also drops expired one-time (non-recurring) items whose day has passed.
    func reload() {
        TapstStorage.purgeExpiredSchedule()
        items = TapstStorage.loadSchedule().sorted { $0.minutesOfDay < $1.minutesOfDay }
    }

    func add(text: String, hour: Int, minute: Int, weekday: Int) {
        TapstStorage.addSchedule(text: text, hour: hour, minute: minute, weekday: weekday)
        reload()
        Task { await TapstLiveActivity.refresh() }
    }

    func items(weekday: Int) -> [TapstScheduleItem] {
        items.filter { $0.weekday == weekday }
    }

    func remove(_ item: TapstScheduleItem) {
        TapstStorage.removeSchedule(id: item.id.uuidString)
        reload()
        Task { await TapstLiveActivity.refresh() }
    }

    func updateText(_ item: TapstScheduleItem, to text: String) {
        TapstStorage.updateSchedule(id: item.id.uuidString, text: text)
        reload() // keeps chronological order
        Task { await TapstLiveActivity.refresh() }
    }

    func updateTime(_ item: TapstScheduleItem, hour: Int, minute: Int) {
        TapstStorage.updateSchedule(id: item.id.uuidString, hour: hour, minute: minute)
        reload() // re-sorts by the new time
        Task { await TapstLiveActivity.refresh() }
    }
}
