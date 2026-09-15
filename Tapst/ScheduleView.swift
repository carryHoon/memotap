//
//  ScheduleView.swift
//  Tapst (MemoTap)
//
//  시간표 (timetable) tab — Pro only. A weekly plan: pick a weekday at the top,
//  add what to do and at what time for that day. Weekdays toggled "매주 표시" show
//  their schedule on the Lock Screen automatically on that day. Input/editing is
//  in-app only (no Back Tap).
//

import SwiftUI

struct ScheduleView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = ScheduleStore.shared
    @State private var pro = ProStore.shared
    @State private var draft = ""
    @State private var draftTime = Calendar.current.date(
        bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var showPaywall = false
    @FocusState private var inputFocused: Bool

    @State private var selectedWeekday = Calendar.current.component(.weekday, from: Date())
    @State private var enabledWeekdays: Set<Int> = Set(TapstStorage.scheduleWeekdays)

    // Tap-to-edit existing rows: text inline, time via a picker sheet.
    @State private var editingID: UUID?
    @State private var editText = ""
    @FocusState private var editFocused: Bool
    @State private var timeEditItem: TapstScheduleItem?

    // Localized weekday symbols from the system calendar (index 0 == Sunday),
    // so English shows "S M T W T F S" and Korean shows "일 월 화 수 목 금 토".
    private let weekdayLabels = Calendar.current.veryShortStandaloneWeekdaySymbols
    // Full localized weekday names for headings ("Sunday" / "일요일").
    private let weekdayFullNames = Calendar.current.standaloneWeekdaySymbols

    private var dayItems: [TapstScheduleItem] { store.items(weekday: selectedWeekday) }
    private var atCapacity: Bool { dayItems.count >= TapstStorage.maxScheduleItems }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            if pro.isPro { content } else { lockedState }
        }
        .task { await TapstLiveActivity.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.reload()
                enabledWeekdays = Set(TapstStorage.scheduleWeekdays)
                Task { await TapstLiveActivity.refresh() }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(item: $timeEditItem) { item in
            TimeEditSheet(hour: item.hour, minute: item.minute) { h, m in
                store.updateTime(item, hour: h, minute: m)
            }
        }
    }

    // MARK: Pro content

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("시간표")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.top, 8)

            weekdaySelector
            weeklyToggle
            inputBar

            if dayItems.isEmpty {
                emptyState
            } else {
                scheduleList
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private var weekdaySelector: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { wd in
                let isSel = wd == selectedWeekday
                Button {
                    commitTextEdit()
                    selectedWeekday = wd
                } label: {
                    VStack(spacing: 4) {
                        Text(weekdayLabels[wd - 1])
                            .font(.system(size: 17, weight: isSel ? .bold : .regular, design: .rounded))
                            .foregroundStyle(isSel ? Color.primary : Color.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background {
                                if isSel {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.primary, lineWidth: 2)
                                }
                            }
                        // Dot marks weekdays enabled for the Lock Screen (매주 표시).
                        Circle()
                            .fill(enabledWeekdays.contains(wd) ? Color.accentColor : Color.clear)
                            .frame(width: 5, height: 5)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var weeklyToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: weeklyBinding) {
                Label("이 요일 매주 반복", systemImage: "repeat")
                    .font(.subheadline)
            }
            Text(weeklyBinding.wrappedValue
                 ? "매주 이 요일마다 잠금화면에 자동으로 표시돼요."
                 : "이번 다가오는 이 요일에 한 번만 표시돼요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
    }

    private var weeklyBinding: Binding<Bool> {
        Binding(
            get: { enabledWeekdays.contains(selectedWeekday) },
            set: { on in
                if on { enabledWeekdays.insert(selectedWeekday) }
                else { enabledWeekdays.remove(selectedWeekday) }
                TapstStorage.scheduleWeekdays = Array(enabledWeekdays)
                Task { await TapstLiveActivity.refresh() }
            }
        )
    }

    private var inputBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(.secondary)
                TextField("", text: $draft, prompt: Text("할 일 입력").foregroundColor(.secondary))
                    .foregroundStyle(.primary)
                    .focused($inputFocused)
                    .submitLabel(.done)
                    .onSubmit(addDraft)
            }

            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                DatePicker("", selection: $draftTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Spacer()
                Button(action: addDraft) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || atCapacity)
                .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty || atCapacity ? 0.4 : 1)
            }

            if atCapacity {
                Text("잠금화면 가독성을 위해 요일당 최대 \(TapstStorage.maxScheduleItems)개까지 추가할 수 있어요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("\(weekdayFullNames[selectedWeekday - 1]) 시간표가 비어 있어요")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("할 일과 수행할 시간을 입력해\n하루를 시간순으로 정리해보세요.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var scheduleList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(dayItems) { item in
                    HStack(spacing: 0) {
                        // Time = tap to edit via the picker sheet.
                        Button { timeEditItem = item } label: {
                            Text(timeLabel(item))
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                                .frame(width: 62, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        Rectangle()
                            .fill(.secondary.opacity(0.35))
                            .frame(width: 1, height: 26)
                            .padding(.trailing, 14)

                        // Text = tap to edit inline (keyboard).
                        if editingID == item.id {
                            TextField("", text: $editText)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.primary)
                                .focused($editFocused)
                                .submitLabel(.done)
                                .onSubmit { commitTextEdit() }
                                .onAppear { editFocused = true }
                                .onChange(of: editFocused) { _, focused in
                                    if !focused { commitTextEdit() }
                                }
                        } else {
                            Text(item.text)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.primary)
                                .onTapGesture { startTextEdit(item) }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                    // Long-press anywhere on the card to delete.
                    .contentShape(RoundedRectangle(cornerRadius: 20))
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation(.snappy) { store.remove(item) }
                        } label: { Label("삭제", systemImage: "trash") }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Locked (non-Pro)

    private var lockedState: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("시간표는 메모탭 Pro 전용이에요")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("요일별 일정을 시간순으로 잠금화면에\n자동으로 띄우는 기능이에요.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button { showPaywall = true } label: {
                Text("Pro 시작하기")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .padding(40)
    }

    // MARK: Actions

    private func addDraft() {
        guard !draft.trimmingCharacters(in: .whitespaces).isEmpty, !atCapacity else { return }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: draftTime)
        let text = draft
        draft = ""
        withAnimation(.snappy) {
            store.add(text: text, hour: comps.hour ?? 0, minute: comps.minute ?? 0, weekday: selectedWeekday)
        }
    }

    private func startTextEdit(_ item: TapstScheduleItem) {
        commitTextEdit() // save any row already being edited
        editText = item.text
        editingID = item.id
    }

    private func commitTextEdit() {
        guard let id = editingID,
              let item = store.items.first(where: { $0.id == id }) else { return }
        editingID = nil
        store.updateText(item, to: editText)
    }

    private func timeLabel(_ item: TapstScheduleItem) -> String {
        tapstTimeString(hour: item.hour, minute: item.minute)
    }
}

// MARK: - Time edit sheet

/// A small wheel picker to change an existing timetable item's time.
private struct TimeEditSheet: View {
    let onSave: (Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var time: Date

    init(hour: Int, minute: Int, onSave: @escaping (Int, Int) -> Void) {
        self.onSave = onSave
        _time = State(initialValue: Calendar.current.date(
            bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date())
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("시간", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("시간 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
                        onSave(c.hour ?? 0, c.minute ?? 0)
                        dismiss()
                    }
                }
            }
            .presentationDetents([.height(320)])
        }
    }
}

#Preview {
    ScheduleView()
}
