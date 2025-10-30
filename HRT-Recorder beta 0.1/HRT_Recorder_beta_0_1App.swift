//
//  HRT_Recorder_beta_0_1App.swift
//  HRT-Recorder beta 0.1
//
//  Created by wzzzz Shao on 2025/9/28.
//

import SwiftUI

@main
struct HRTRecorderBetaApp: App {
    @Environment(\.scenePhase) private var phase
    @StateObject private var store: PersistedStore<[DoseEvent]>
    @StateObject private var timelineVM: DoseTimelineVM
    
    init() {
        let persistedStore = PersistedStore<[DoseEvent]>(
            filename: "dose_events.json",
            defaultValue: []
        )
        _store = StateObject(wrappedValue: persistedStore)
        _timelineVM = StateObject(wrappedValue: DoseTimelineVM(initialEvents: persistedStore.value) { updated in
            persistedStore.value = updated
        })
    }
    
    var body: some Scene {
        WindowGroup {
            TimelineScreen(vm: timelineVM)
        }
        .onChange(of: phase) { newPhase in
            if newPhase == .inactive || newPhase == .background {
                store.saveSync()
            }
        }
        WindowGroup("window.concentrationMonitor", id: "concentrationMonitor") {
            ConcentrationMonitorView(vm: timelineVM)
        }
#if os(macOS)
        .defaultSize(width: 320, height: 420)
#endif
        .onChange(of: phase) { newPhase in
            if newPhase == .inactive || newPhase == .background {
                store.saveSync()
            }
        }
    }
}
