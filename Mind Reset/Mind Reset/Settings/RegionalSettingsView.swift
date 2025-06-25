//
//  RegionalSettingsView.swift
//  Mind Reset
//

import SwiftUI

@available(iOS 16.0, *)
struct RegionalSettingsView: View {

    // ───────── Environment
    @Environment(\.dismiss) private var dismiss

    // ───────── Persisted values
    /// Legacy key for “Week begins on”
    private let currentWeekStartIndex: Int =
        UserDefaults.standard.integer(forKey: "weekStartIndex")   // 0…6

    /// Reactive, app-wide date format preference
    
    @AppStorage("dateFormatStyle") private var dateFormatStyle: String = {
        // If they’ve never set one, fall back to locale default:
        let saved = UserDefaults.standard.string(forKey: "dateFormatStyle")
        return saved ?? defaultDatePattern()
    }()

    // ───────── Local UI state
    @State private var pendingWeekStartIndex: Int
    @State private var sheetInitialIndex = 0
    @State private var showWeekStartPicker = false
    @State private var showConfirmWeekSave = false

    // ───────── Constants
    private let daysOfWeek = Calendar.current.weekdaySymbols    // ["Sunday",…,"Saturday"]
    private let dateStyles  = [
        "MM/dd/yyyy",         // U.S. numeric
        "dd/MM/yyyy",         // U.K. / EU numeric
        "yyyy-MM-dd",         // ISO-8601 numeric
        "MMMM d, yyyy"        // Verbose: “June 25, 2025”
    ]

    // ───────── Init
    init() {
        _pendingWeekStartIndex = State(
            initialValue: UserDefaults.standard.integer(forKey: "weekStartIndex")
        )
    }

    // ═════════════════════════════════════════════════════════════
    // MARK: – Body
    // ═════════════════════════════════════════════════════════════
    var body: some View {
        Form {
            // ── Week begins on … ───────────────────────────────
            Section("Week begins on") {
                Button {
                    showWeekStartPicker.toggle()
                } label: {
                    HStack {
                        Text(daysOfWeek[pendingWeekStartIndex])
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
                                // Roll back to original if cancelled
                                pendingWeekStartIndex = sheetInitialIndex
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
                    .onAppear {
                        // Remember starting value for cancel rollback
                        sheetInitialIndex = pendingWeekStartIndex
                    }
                }
            }

            // ── Date-format style ───────────────────────────────
            Section("Date format") {
                Picker("Preferred format", selection: $dateFormatStyle) {
                    ForEach(dateStyles, id: \.self) { fmt in
                        Text(sampleDate(for: fmt)).tag(fmt)
                    }
                }
                .pickerStyle(.inline)
            }

            // ── Done ────────────────────────────────────────────
            Section {
                Button("Done") {
                    // dateFormatStyle is auto-saved via @AppStorage
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
            Button("Cancel", role: .cancel) {
                // Roll back if user aborts
                pendingWeekStartIndex = currentWeekStartIndex
            }
        }
    }

    // ═════════════════════════════════════════════════════════════
    // MARK: – Helpers
    // ═════════════════════════════════════════════════════════════
    private func applyWeekStartChange() {
        let newIdx = pendingWeekStartIndex  // 0…6

        // 1️⃣ Legacy single‐value key for backward compatibility
        UserDefaults.standard.set(newIdx, forKey: "weekStartIndex")

        // 2️⃣ Append to history & notify WeekViewState
        WeekViewState.appendChange(newIndex: newIdx)
    }
    
    private static func defaultDatePattern() -> String {
        let region = Locale.current.regionCode ?? "US"
        // U.S. users get MM/dd/yyyy; everyone else dd/MM/yyyy
        return (region == "US") ? "MM/dd/yyyy" : "dd/MM/yyyy"
    }

    private func sampleDate(for pattern: String) -> String {
        let df = DateFormatter()
        df.dateFormat = pattern
        return df.string(from: Date())
    }
}
