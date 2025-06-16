//
//  SchedulerView.swift
//  Mind Reset
//

import SwiftUI
import Combine

// MARK: – Main Scheduler View
struct SchedulerView: View {
    @EnvironmentObject var session: SessionStore
    @State private var selectedTab: SchedulerTab = .day

    /// Accent colour reused in sub-views
    private let accentCyan = Color(red: 0, green: 1, blue: 1)

    // ───── greetings & quotes ─────
    private let greetings = [
        "Welcome back! Let’s make today productive.",
        "Welcome back! Every moment counts.",
        "Welcome back! Focus on your progress.",
        "Welcome back! Today is a new chance to excel.",
        "Welcome back! Keep pushing forward."
    ]

    private let quotes = [
        "Small daily steps lead to big achievements.",
        "Discipline is choosing between what you want now and what you want most.",
        "Focus on consistency, not perfection.",
        "Make progress one day at a time.",
        "You don’t have to be extreme—just consistent.",
        "Productivity grows when you prioritize and persist.",
        "Success is a few simple disciplines practiced every day.",
        "Every little victory counts toward the bigger goal.",
        "A focused mind can conquer any goal.",
        "Every day is a chance to improve."
    ]

    private var dailyGreeting: String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return greetings[(day - 1) % greetings.count]
    }
    private var dailyQuote: String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return quotes[(day - 1) % quotes.count]
    }

    // ───── body ─────
    var body: some View {
        NavigationStack {                                // persistent navigation stack
            ZStack {
                // 1) Background color
                Color.black
                    .ignoresSafeArea()
                    // Tap outside active controls ⟶ dismiss keyboard
                    .onTapGesture {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }

                // 2) Main content
                VStack {
                    greetingBanner
                    segmentedPicker
                    contentArea
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                    Spacer()
                }
            }
            .navigationBarHidden(true)                   // hide default nav bar
        }

    }

    // ───── sub-views ─────
    private var greetingBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dailyGreeting)
                .font(.title)
                .fontWeight(.heavy)
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.8), radius: 4)

            Text(dailyQuote)
                .font(.subheadline)
                .foregroundColor(accentCyan)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.top, 30)
        .padding(.bottom, 20)
    }

    private var segmentedPicker: some View {
        VStack(spacing: 4) {
            Picker("Tabs", selection: $selectedTab) {
                Text("Day").tag(SchedulerTab.day)
                Text("Week").tag(SchedulerTab.week)
                Text("Month").tag(SchedulerTab.month)
            }
            .pickerStyle(SegmentedPickerStyle())
            .tint(.gray)
            .background(Color.gray)
            .cornerRadius(8)
            .padding(.horizontal, 10)

            Rectangle()
                .fill(Color.black)
                .frame(height: 4)
                .padding(.horizontal, 10)
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        switch selectedTab {
        case .day:
            DayView()                                    // no extra NavigationStack
        case .week:
            WeekView(accentColor: accentCyan)
        case .month:
            MonthView(
                accentColor: accentCyan,
                accountCreationDate: session.userModel?.createdAt ?? Date()
            )
        }
    }
}

// MARK: – Tab Enum
enum SchedulerTab: String, CaseIterable {
    case day, week, month
}

// ───────────────────────────────────────────────
// MARK: – Pan-outside-text → dismiss keyboard
// ───────────────────────────────────────────────

private struct DismissKeyboardOnPanView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.backgroundColor = .clear

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.cancelsTouchesInView = false
        pan.delegate = context.coordinator
        v.addGestureRecognizer(pan)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        @objc func handlePan(_ pan: UIPanGestureRecognizer) {
            // only dismiss once when the pan begins
            if pan.state == .began {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        }

        // ignore pans that start inside text inputs
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            if let v = touch.view,
               (v is UITextView || v is UITextField || v.superview is UITextView) {
                return false
            }
            return true
        }
    }
}

// MARK: – Preview
struct SchedulerView_Previews: PreviewProvider {
    static var previews: some View {
        SchedulerView()
            .environmentObject(SessionStore())
    }
}
