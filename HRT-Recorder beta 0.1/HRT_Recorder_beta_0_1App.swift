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
    @StateObject private var store = PersistedStore<[DoseEvent]>(
        filename: "dose_events.json",
        defaultValue: []
    )

    var body: some Scene {
        WindowGroup {
            // 根据你的真实构造方法改参数名
            TimelineScreen(vm: DoseTimelineVM(initialEvents: store.value) { updated in
                store.value = updated
            })
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                store.saveSync()
            }
        }
    }
}
