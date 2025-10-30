//
//  ConcentrationMonitorView.swift
//  HRT-Recorder beta 0.1
//
//  Created by OpenAI ChatGPT on 2024/3/18.
//

import SwiftUI
import Combine

struct ConcentrationMonitorView: View {
    @ObservedObject var vm: DoseTimelineVM
    @State private var now: Date = Date()
    @State private var timerActive: Bool = true
    private let timer = Timer.publish(every: 1.0, tolerance: 0.3, on: .main, in: .common).autoconnect()

    private var currentConcentrationText: String {
        guard let value = vm.concentration(at: now) else {
            return NSLocalizedString("monitor.noData", comment: "No concentration data available")
        }
        return String(format: NSLocalizedString("monitor.value", comment: "Current concentration"), locale: Locale.current, value)
    }

    private var timeRangeDescription: String {
        guard let result = vm.result, let first = result.timeH.first, let last = result.timeH.last else {
            return NSLocalizedString("monitor.prompt", comment: "Prompt to add dosing events")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMddjmm")
        let start = Date(timeIntervalSince1970: first * 3600)
        let end = Date(timeIntervalSince1970: last * 3600)
        return String(format: NSLocalizedString("monitor.range", comment: "Simulation range"), formatter.string(from: start), formatter.string(from: end))
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("monitor.title")
                .font(.title2.weight(.semibold))

            Text(currentConcentrationText)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.pink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(now, style: .time)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(timeRangeDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Toggle("monitor.pause", isOn: $timerActive)
                .toggleStyle(SwitchToggleStyle(tint: .pink))
                .padding(.top, 12)

            Spacer()
        }
        .padding()
        .frame(minWidth: 280, minHeight: 360)
        .background(Color(uiColor: .systemBackground))
        .onReceive(timer) { date in
            guard timerActive else { return }
            now = date
        }
    }

}

#Preview("monitor.preview") {
    ConcentrationMonitorView(vm: DoseTimelineVM())
}
