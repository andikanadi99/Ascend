//
//  RegionalSettingsView.swift
//  Mind Reset
//

import SwiftUI

@available(iOS 16.0, *)
struct RegionalSettingsView: View {

    // ───────── Environment
    @Environment(\.dismiss) private var dismiss

    // ───────── Persisted (current) values
    private let currentWeekStartIndex: Int =
        UserDefaults.standard.integer(forKey: "weekStartIndex")       // 0…6

    private let currentDateStyleRaw: String =
        UserDefaults.standard.string(forKey: "dateFormatStyle") ?? "MM/dd/yyyy"

    // ───────── Local UI state
    @State private var pendingWeekStartIndex: Int
    @State private var pendingDateStyleRaw:   String

    @State private var sheetInitialIndex:     Int = 0                 // remembers value on sheet open
    @State private var showWeekStartPicker    = false
    @State private var showConfirmWeekSave    = false

    // ───────── Constants
    private let daysOfWeek = Calendar.current.weekdaySymbols          // Sun…Sat
    private let dateStyles  = [
        "MM/dd/yyyy",         // US
        "dd/MM/yyyy",         // UK / EU
        "yyyy-MM-dd"          // ISO
    ]

    // ───────── Init
    init() {
        _pendingWeekStartIndex = State(initialValue: currentWeekStartIndex)
        _pendingDateStyleRaw   = State(initialValue: currentDateStyleRaw)
    }

    // ═════════════════════════════════════════════════════════════
    // MARK: – Body
    // ═════════════════════════════════════════════════════════════
    var body: some View {
        Form {

            // ── Week starts on … ───────────────────────────────
            Section("Week begins on") {
                Button {
                    showWeekStartPicker.toggle()
                } label: {
                    HStack {
                        Text(daysOfWeek[pendingWeekStartIndex])        // live preview
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                .sheet(isPresented: $showWeekStartPicker) {
                    VStack(spacing: 16) {
                        Text("Week begins on")
                            .font(.headline)

                        Picker("", selection: $pendingWeekStartIndex) {
                            ForEach(0..<7, id: \.self) { i in
                                Text(daysOfWeek[i]).tag(i)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.wheel)

                        HStack {
                            Button("Cancel") {
                                pendingWeekStartIndex = sheetInitialIndex   // ← roll back
                                showWeekStartPicker = false
                            }
                            .foregroundColor(.red)

                            Spacer()

                            Button("Save") {
                                showWeekStartPicker = false
                                if pendingWeekStartIndex != currentWeekStartIndex {
                                    showConfirmWeekSave = true
                                }
                            }
                            .disabled(pendingWeekStartIndex == currentWeekStartIndex)
                        }
                    }
                    .padding()
                    .presentationDetents([.height(320)])
                    .onAppear { sheetInitialIndex = pendingWeekStartIndex } // remember current value
                }
            }

            // ── Date-format style ───────────────────────────────
            Section("Date format") {
                Picker("Preferred format", selection: $pendingDateStyleRaw) {
                    ForEach(dateStyles, id: \.self) { fmt in
                        Text(sampleDate(for: fmt)).tag(fmt)
                    }
                }
                .pickerStyle(.inline)
            }

            // ── Save & Close ───────────────────────────────────
            Section {
                Button("Done") {
                    persistChanges()
                    dismiss()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Regional Settings")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .confirmationDialog(
            "Changing the week’s first day will shift all CURRENT and FUTURE weeks. Past weeks keep their original layout.",
            isPresented: $showConfirmWeekSave,
            titleVisibility: .visible
        ) {
            Button("Apply change", role: .destructive) {
                applyWeekStartChange()
            }
            Button("Cancel", role: .cancel) {          // ← update this closure
                pendingWeekStartIndex = currentWeekStartIndex   // roll back preview
            }
        }

    }

    // ═════════════════════════════════════════════════════════════
    // MARK: – Helpers
    // ═════════════════════════════════════════════════════════════
    private func persistChanges() {
        // Date-format style
        if pendingDateStyleRaw != currentDateStyleRaw {
            UserDefaults.standard.set(pendingDateStyleRaw, forKey: "dateFormatStyle")
        }
        // Week-start saved separately in applyWeekStartChange()
    }

    /// Called only after user confirmed the warning dialog
    private func applyWeekStartChange() {
        let newIdx = pendingWeekStartIndex          // 0…6

        // 1️⃣ legacy single key (legacy code still reads this)
        UserDefaults.standard.set(newIdx, forKey: "weekStartIndex")

        // 2️⃣ append to history + broadcast
        WeekViewState.appendChange(newIndex: newIdx)
    }

    private func sampleDate(for pattern: String) -> String {
        let df = DateFormatter()
        df.dateFormat = pattern
        return df.string(from: Date())
    }
}
