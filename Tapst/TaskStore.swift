//
//  TaskStore.swift
//  Tapst
//
//  App-side observable wrapper over the shared TapstStorage, used by the UI.
//

import Foundation

@Observable
final class TaskStore {
    static let shared = TaskStore()

    private(set) var tasks: [TapstTask] = []

    private init() {
        reload()
    }

    /// Re-reads tasks from shared storage (e.g. after a background intent ran).
    func reload() {
        tasks = TapstStorage.load()
    }

    func add(_ text: String) {
        TapstStorage.add(text)
        reload()
        Task { await TapstLiveActivity.refresh() }
    }

    func remove(_ task: TapstTask) {
        TapstStorage.remove(id: task.id.uuidString)
        reload()
        Task { await TapstLiveActivity.refresh() }
    }

    func updateText(_ task: TapstTask, to text: String) {
        TapstStorage.updateText(id: task.id.uuidString, text: text)
        reload()
        Task { await TapstLiveActivity.refresh() }
    }
}
