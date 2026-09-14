//
//  MainTabView.swift
//  Tapst (MemoTap)
//
//  Root tab bar: 할일 (the memo list) and 설정 (settings).
//

import SwiftUI

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    // Default to 할일 so free users don't land on the Pro-gated timetable tab.
    @State private var selection = 1

    var body: some View {
        TabView(selection: $selection) {
            ScheduleView()
                .tabItem { Label("시간표", systemImage: "clock") }
                .tag(0)

            ContentView()
                .tabItem { Label("할일", systemImage: "note.text") }
                .tag(1)

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(2)
        }
        // Keep the Lock Screen Live Activity in sync whenever the app is active,
        // regardless of which tab is showing.
        .task { await TapstLiveActivity.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                TaskStore.shared.reload()
                Task { await TapstLiveActivity.refresh() }
            }
        }
        .fullScreenCover(isPresented: .init(
            get: { !hasSeenOnboarding },
            set: { if $0 == false { hasSeenOnboarding = true } }
        )) {
            OnboardingView()
        }
    }
}

#Preview {
    MainTabView()
}
