//
//  ResultChartView.swift
//  HRTRecorder
//
//    Created by mihari-zhong on 2025/8/1.
//

import Foundation
import SwiftUI
import Charts

struct ResultChartView: View {
    let sim: SimulationResult
    
    @State private var visibleDomainLength: Double = 48
    @Environment(\.horizontalSizeClass) var sizeClass


    /// (Date, conc) tuples to simplify the Chart body and help the compiler type‑check faster
    private var datedPoints: [(date: Date, conc: Double)] {
        // Break the work into 2 simpler steps so the compiler can type‑check faster
        let paired: [(Double, Double)] = Array(zip(sim.timeH, sim.concPGmL))
        return paired.map { (hour: Double, conc: Double) -> (date: Date, conc: Double) in
            let date = Date(timeIntervalSince1970: hour * 3600)
            return (date, conc)
        }
    }
    
    private var yAxisDomain: ClosedRange<Double> {
        let maxConcentration = sim.concPGmL.max() ?? 0
        let topBoundary = max(maxConcentration, 50) * 1.1
        return 0.0...topBoundary    // use Double literal to avoid type‑inference cost
    }
    
    // A separate sub‑view for the chart itself to keep `body` small and compiler‑friendly
    @ViewBuilder
    private var concentrationChart: some View {
        // Anchor the X‑axis grid to midnight of the first event’s day
        let axisStart = Calendar.current.startOfDay(for: datedPoints.first?.date ?? Date())
        let axisEnd   = datedPoints.last?.date ?? Date()

        Chart {
            ForEach(datedPoints, id: \.date) { pt in
                LineMark(
                    x: .value(NSLocalizedString("chart.axis.time", comment: "X-axis label"), pt.date),
                    y: .value(NSLocalizedString("chart.axis.conc", comment: "Y-axis label"), pt.conc)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.pink)
            }
        }
        .chartXAxis {
            // Major grid: one per calendar day at 00:00
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                AxisTick(length: 5)
                AxisValueLabel(anchor: .bottom) {
                    if let date = value.as(Date.self) {
                        Text(date, format: dayLabelFormat)
                            .font(.caption)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                            .allowsTightening(true)
                    }
                }
                AxisValueLabel(anchor: .top) {
                    Text("00")                                   // fixed label at midnight
                }
            }
            // Minor grid: every 6 h
            AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                AxisTick()
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [2, 2]))
                AxisValueLabel(anchor: .top) {
                    if let date = value.as(Date.self) {
                        let h = Calendar.current.component(.hour, from: date)
                        Text(String(format: "%02d", locale: Locale.current, h))          // “06” “12” “18”
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        // --- Y-Axis Configuration ---
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 6)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let conc = value.as(Int.self) {
                        Text("\(conc)")
                    }
                }
            }
        }
        .chartXVisibleDomain(length: visibleDomainLength * 3600)   // hours -> seconds
        .chartScrollableAxes(.horizontal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("chart.title")
                .font(.headline)
                .padding(.horizontal)

            concentrationChart
        }
        .animation(.easeInOut, value: sim.concPGmL)
        .onAppear {
            self.visibleDomainLength = (sizeClass == .compact) ? 24 : 48
        }
    }
    
    // MARK: - Date Formatters
    private var dayLabelFormat: Date.FormatStyle {
        if sizeClass == .compact {
            return .dateTime.month(.defaultDigits).day()
        } else {
            return .dateTime.month(.abbreviated).day()
        }
    }
}
