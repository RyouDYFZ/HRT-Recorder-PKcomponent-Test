//
//  InputEventView.swift
//  HRT‑Recorder
//
//    Created by mihari-zhong on 2025‑08‑01.
//
//  SwiftUI sheet for adding a DoseEvent.  The form adapts fields
//  to the selected route (injection, patch apply/remove, gel, oral, sublingual).
//
import Foundation
import SwiftUI
import Combine
/// Input mode when adding a transdermal patch
private enum PatchInputMode: String, CaseIterable, Identifiable {
    case totalDose           // mg in reservoir
    case releaseRate         // µg per day
    var id: Self { self }
    var label: String {
        switch self {
        case .totalDose:   "Total dose (mg)"
        case .releaseRate: "Release rate (µg/d)"
        }
    }
}

// MARK: - Draft model (for UI binding)
private struct DraftDoseEvent {
    var id: UUID? // For editing existing events
    var date = Date()
    var route: DoseEvent.Route = .injection
    var ester: Ester = .EV
    
    // **NEW**: Separate state for raw ester dose and E2 equivalent dose
    var rawEsterDoseText: String = ""
    var e2EquivalentDoseText: String = ""
    
    // for patch apply
    var patchMode: PatchInputMode = .totalDose
    var releaseRateText: String = ""
    
    // Sublingual behavior (θ) UI
    var slTierIndex: Int = 2        // 0: quick, 1: casual, 2: standard, 3: strict
    var useCustomTheta: Bool = false
    var customThetaText: String = ""
}

// MARK: - View
struct InputEventView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DraftDoseEvent
    
    var onSave: (DoseEvent) -> Void
    
    // **NEW**: Initializer for both creating a new event and editing an existing one.
    init(eventToEdit: DoseEvent? = nil, onSave: @escaping (DoseEvent) -> Void) {
        self.onSave = onSave
        if let event = eventToEdit {
            let esterInfo = EsterInfo.by(ester: event.ester)
            let rawDose = event.doseMG / esterInfo.toE2Factor
            
            _draft = State(initialValue: DraftDoseEvent(
                id: event.id,
                date: event.date,
                route: event.route,
                ester: event.ester,
                rawEsterDoseText: String(format: "%.2f", rawDose),
                e2EquivalentDoseText: String(format: "%.2f", event.doseMG)
            ))
        } else {
            _draft = State(initialValue: DraftDoseEvent())
        }
    }
    
    // ... (availableEsters logic updated for sublingual)
    private var availableEsters: [Ester] {
        switch draft.route {
        case .injection: return [.EB, .EV, .EC, .EN]
        case .patchApply, .patchRemove, .gel: return [.E2]
        case .oral: return [.E2, .EV]
        case .sublingual: return [.E2, .EV]
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // ... (DatePicker and Route Picker remain the same)
                Section {
                    DatePicker("Time", selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
                    Picker("Route", selection: $draft.route) {
                        Text("Injection").tag(DoseEvent.Route.injection)
                        Text("Apply Patch").tag(DoseEvent.Route.patchApply)
                        Text("Remove Patch").tag(DoseEvent.Route.patchRemove)
                        Text("Gel").tag(DoseEvent.Route.gel)
                        Text("Oral").tag(DoseEvent.Route.oral)
                        Text("Sublingual").tag(DoseEvent.Route.sublingual)
                    }
                    #if swift(>=5.9)
                    .onChange(of: draft.route) { oldValue, newValue in
                        if let firstValidEster = availableEsters.first {
                            draft.ester = firstValidEster
                        }
                        // Clear doses on route change
                        draft.rawEsterDoseText = ""
                        draft.e2EquivalentDoseText = ""
                        draft.patchMode = .totalDose
                        draft.releaseRateText = ""
                        // reset sublingual UI
                        draft.slTierIndex = 2
                        draft.useCustomTheta = false
                        draft.customThetaText = ""
                    }
                    #else
                    .onChange(of: draft.route) { _ in
                        if let firstValidEster = availableEsters.first {
                            draft.ester = firstValidEster
                        }
                        // Clear doses on route change
                        draft.rawEsterDoseText = ""
                        draft.e2EquivalentDoseText = ""
                        draft.patchMode = .totalDose
                        draft.releaseRateText = ""
                        // reset sublingual UI
                        draft.slTierIndex = 2
                        draft.useCustomTheta = false
                        draft.customThetaText = ""
                    }
                    #endif
                }
                
                if draft.route != .patchRemove {
                    Section("Drug Details") {
                        if availableEsters.count > 1 {
                            Picker("Drug / Ester", selection: $draft.ester) {
                                ForEach(availableEsters) { Text($0.fullName).tag($0) }
                            }
                            #if swift(>=5.9)
                            .onChange(of: draft.ester) { _, _ in
                                // Recalculate when ester changes
                                convertToE2Equivalent()
                            }
                            #else
                            .onChange(of: draft.ester) { _ in
                                // Recalculate when ester changes
                                convertToE2Equivalent()
                            }
                            #endif
                        }
                        
                        // **NEW**: Two-way binding text fields for dose conversion.
                        if draft.ester != .E2 {
                             TextField("Dose (\(draft.ester.abbreviation))", text: $draft.rawEsterDoseText)
                                .keyboardType(.decimalPad)
                                #if swift(>=5.9)
                                .onChange(of: draft.rawEsterDoseText) { _, _ in convertToE2Equivalent() }
                                #else
                                .onChange(of: draft.rawEsterDoseText) { _ in convertToE2Equivalent() }
                                #endif
                        }
                        
                        TextField("E2 Equivalent Dose (mg)", text: $draft.e2EquivalentDoseText)
                            .keyboardType(.decimalPad)
                            #if swift(>=5.9)
                            .onChange(of: draft.e2EquivalentDoseText) { _, _ in convertToRawEster() }
                            #else
                            .onChange(of: draft.e2EquivalentDoseText) { _ in convertToRawEster() }
                            #endif
                    }
                }
                
                // MARK: Patch‑specific input
                if draft.route == .patchApply {
                    Section("Patch Input Mode") {
                        Picker("Mode", selection: $draft.patchMode) {
                            ForEach(PatchInputMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if draft.patchMode == .totalDose {
                            TextField("Patch total dose (mg)", text: $draft.e2EquivalentDoseText)
                                .keyboardType(.decimalPad)
                        } else {
                            TextField("Release rate (µg/day)", text: $draft.releaseRateText)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
                
                // MARK: Sublingual behavior (θ)
                if draft.route == .sublingual {
                    Section("Sublingual Behavior") {
                        // Tier picker (segmented)
                        Picker("Tier", selection: $draft.slTierIndex) {
                            Text("Quick").tag(0)
                            Text("Casual").tag(1)
                            Text("Standard").tag(2)
                            Text("Strict").tag(3)
                        }
                        .pickerStyle(.segmented)
                        
                        // Show suggested hold time and θ for current tier
                        let tier = [SublingualTier.quick, .casual, .standard, .strict][min(max(draft.slTierIndex, 0), 3)]
                        let hold = SublingualTheta.holdMinutes[tier] ?? 0
                        let theta = SublingualTheta.recommended[tier] ?? 0.11
                        Text(String(format: "Suggested: ~%.0f min, θ≈%.2f", hold, theta))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        
                        // Optional: custom theta override
                        Toggle("Custom θ", isOn: $draft.useCustomTheta)
                        if draft.useCustomTheta {
                            TextField("Custom θ (0–1)", text: $draft.customThetaText)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
            }
            .navigationTitle(draft.id == nil ? "Add Dose" : "Edit Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }
    
    // MARK: - Conversion Logic
    private func convertToE2Equivalent() {
        guard let rawDose = Double(draft.rawEsterDoseText) else { return }
        let factor = EsterInfo.by(ester: draft.ester).toE2Factor
        draft.e2EquivalentDoseText = String(format: "%.2f", rawDose * factor)
    }
    
    private func convertToRawEster() {
        guard draft.ester != .E2, let e2Dose = Double(draft.e2EquivalentDoseText) else { return }
        let factor = EsterInfo.by(ester: draft.ester).toE2Factor
        draft.rawEsterDoseText = String(format: "%.2f", e2Dose / factor)
    }
    
    private func save() {
        var dose = Double(draft.e2EquivalentDoseText) ?? 0
        var extras: [DoseEvent.ExtraKey: Double] = [:]
        
        // zero‑order patch: rate stored separately
        if draft.route == .patchApply && draft.patchMode == .releaseRate {
            dose = 0
            if let rateUG = Double(draft.releaseRateText) {
                extras[.releaseRateUGPerDay] = rateUG
            }
        }
        
        // sublingual behavior: either tier code or explicit theta
        if draft.route == .sublingual {
            if draft.useCustomTheta, let th = Double(draft.customThetaText) {
                let clamped = max(0.0, min(1.0, th))
                extras[.sublingualTheta] = clamped
            } else {
                let code = Double(min(max(draft.slTierIndex, 0), 3))
                extras[.sublingualTier] = code
            }
        }
        
        let event = DoseEvent(
            id: draft.id ?? UUID(), // Use existing ID or create a new one
            route: draft.route,
            // store absolute UTC hours (since 1970) – avoids 2001/01/01 offset
            timeH: draft.date.timeIntervalSince1970 / 3600.0,
            doseMG: dose,
            ester: draft.ester,
            extras: extras
        )
        onSave(event)
        dismiss()
    }
}
