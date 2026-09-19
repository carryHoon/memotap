//
//  ContentView.swift
//  Tapst
//
//  Created by MacH on 9/10/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = TaskStore.shared
    @State private var draft = ""
    @State private var showPaywall = false
    @FocusState private var inputFocused: Bool
    // Tap-to-edit an existing memo's text inline.
    @State private var editingID: UUID?
    @State private var editText = ""
    @FocusState private var editFocused: Bool

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Text("메모탭")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.top, 8)

                inputBar

                if store.tasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        // Establish the Lock Screen Live Activity while the app is in the
        // foreground so later Back Tap adds can update it from the background.
        .task { await TapstLiveActivity.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.reload()
                Task { await TapstLiveActivity.refresh() }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .foregroundStyle(.secondary)

            TextField("", text: $draft, prompt: Text("할 일 입력").foregroundColor(.secondary))
                .foregroundStyle(.primary)
                .focused($inputFocused)
                .submitLabel(.done)
                .onSubmit(addDraft)

            Button(action: addDraft) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("아직 할 일이 없어요")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("뒷면을 두 번 탭하거나 위에서 입력해 추가하세요.\n항목을 탭하면 완료됩니다.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var taskList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(store.tasks) { task in
                    HStack(spacing: 16) {
                        // Circle = complete/remove (unchanged behavior).
                        Button {
                            withAnimation(.snappy) { store.remove(task) }
                        } label: {
                            Circle()
                                .strokeBorder(.primary.opacity(0.85), lineWidth: 2.5)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)

                        // Text = tap to edit inline (keyboard).
                        if editingID == task.id {
                            TextField("", text: $editText)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.primary)
                                .focused($editFocused)
                                .submitLabel(.done)
                                .onSubmit { commitEditing() }
                                .onAppear { editFocused = true }
                                .onChange(of: editFocused) { _, focused in
                                    if !focused { commitEditing() }
                                }
                        } else {
                            Text(task.text)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.primary)
                                .onTapGesture { startEditing(task) }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func startEditing(_ task: TapstTask) {
        commitEditing() // save any row already being edited
        editText = task.text
        editingID = task.id
    }

    private func commitEditing() {
        guard let id = editingID,
              let task = store.tasks.first(where: { $0.id == id }) else { return }
        editingID = nil
        store.updateText(task, to: editText)
    }

    private func addDraft() {
        guard !draft.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        // Basic is limited to 5 memos — offer Pro instead of silently failing.
        guard TapstStorage.canAddMore() else {
            inputFocused = false
            showPaywall = true
            return
        }
        let text = draft
        draft = ""
        withAnimation(.snappy) { store.add(text) }
        // Keep the keyboard up so the next memo can be typed with no delay.
        inputFocused = true
    }
}

#Preview {
    ContentView()
}
